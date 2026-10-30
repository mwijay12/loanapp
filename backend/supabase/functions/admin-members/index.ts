// Creates and manages staff logins.
//
// Why this lives on the server: making an auth user requires the service_role
// key, and the browser bundle is public - anyone can read it. So the key stays
// in the function's environment and the browser only ever sends its own JWT.
//
// The caller is authorised by reading their own profile row with the service
// client and requiring the Super Admin role. A client cannot talk its way past
// that: the role check happens here, not in the app.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const ALLOWED_ROLES = [
  "Super Admin",
  "Branch Manager",
  "Loan Officer",
  "Storekeeper",
  "Counter Cashier",
  "Auditor",
];

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function clean(value: unknown, max = 120): string {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

// The password rule is the database's rule, restated before we call it so the
// admin gets a sentence instead of a 422 from GoTrue.
function passwordProblem(password: string): string | null {
  if (password.length < 8) return "Password must be at least 8 characters.";
  if (!/[A-Za-z]/.test(password)) return "Password must contain a letter.";
  if (!/[0-9]/.test(password)) return "Password must contain a number.";
  return null;
}

function emailProblem(email: string): string | null {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    return "That email address is not complete.";
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 1. Who is asking?
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Not signed in." }, 401);

  const { data: caller, error: callerError } = await admin.auth.getUser(token);
  if (callerError || !caller?.user) {
    return json({ error: "Your session has expired. Sign in again." }, 401);
  }

  const { data: callerProfile } = await admin
    .from("profiles")
    .select("id, role")
    .eq("auth_user_id", caller.user.id)
    .maybeSingle();

  if (!callerProfile || callerProfile.role !== "Super Admin") {
    return json({ error: "Only a Super Admin can manage members." }, 403);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "The request body was not valid JSON." }, 400);
  }

  const action = clean(payload.action, 40);

  // ---------------------------------------------------------------- create
  if (action === "create") {
    const email = clean(payload.email, 200).toLowerCase();
    const password = clean(payload.password, 200);
    const fullName = clean(payload.full_name, 120);
    const role = clean(payload.role, 40);
    const branchName = clean(payload.branch_name, 120);
    const phone = clean(payload.phone, 40);

    if (!fullName) return json({ error: "A name is required." }, 400);
    const eErr = emailProblem(email);
    if (eErr) return json({ error: eErr }, 400);
    const pErr = passwordProblem(password);
    if (pErr) return json({ error: pErr }, 400);
    if (!ALLOWED_ROLES.includes(role)) {
      return json({ error: `"${role}" is not a role this app knows.` }, 400);
    }

    const { data: taken } = await admin
      .from("profiles")
      .select("id")
      .ilike("email", email)
      .maybeSingle();
    if (taken) return json({ error: "That email already has an account." }, 409);

    // 2. The login itself. email_confirm:true means the member can sign in
    //    immediately - no inbox step, which is what a shop counter needs.
    const { data: created, error: createError } = await admin.auth.admin
      .createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName, role },
      });

    if (createError || !created?.user) {
      const message = createError?.message ?? "Could not create the login.";
      const status = /already|registered|exists/i.test(message) ? 409 : 400;
      return json({ error: message }, status);
    }

    const authUserId = created.user.id;

    // 3. The profile row is what the whole app reads roles from. If it fails,
    //    roll the login back so we never leave an account with no role.
    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .insert({
        auth_user_id: authUserId,
        email,
        full_name: fullName,
        role,
        branch_name: branchName || null,
        phone: phone || null,
      })
      .select("id, auth_user_id, email, full_name, role, branch_name, phone")
      .single();

    if (profileError || !profile) {
      await admin.auth.admin.deleteUser(authUserId);
      return json(
        { error: `Login rolled back: ${profileError?.message ?? "no profile"}` },
        500,
      );
    }

    // 4. The staff directory row, so the roster and the staff cards agree with
    //    the logins. Not fatal: the account works even if this misses.
    const { error: staffError } = await admin.from("staff").insert({
      name: fullName,
      role,
      status: "Active",
      note: branchName ? `${branchName} · ${email}` : email,
    });

    return json({
      ok: true,
      member: profile,
      staff_row: staffError ? { warning: staffError.message } : { ok: true },
    });
  }

  // -------------------------------------------------------- reset password
  if (action === "reset_password") {
    const profileId = clean(payload.profile_id, 60);
    const password = clean(payload.password, 200);
    if (!profileId) return json({ error: "Which member?" }, 400);
    const pErr = passwordProblem(password);
    if (pErr) return json({ error: pErr }, 400);

    const { data: target } = await admin
      .from("profiles")
      .select("auth_user_id")
      .eq("id", profileId)
      .maybeSingle();
    if (!target?.auth_user_id) {
      return json({ error: "That member has no login attached." }, 404);
    }

    const { error } = await admin.auth.admin.updateUserById(
      target.auth_user_id,
      { password },
    );
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  }

  // ------------------------------------------------------------- set role
  if (action === "set_role") {
    const profileId = clean(payload.profile_id, 60);
    const role = clean(payload.role, 40);
    if (!ALLOWED_ROLES.includes(role)) {
      return json({ error: `"${role}" is not a role this app knows.` }, 400);
    }
    if (profileId === callerProfile.id && role !== "Super Admin") {
      return json(
        { error: "You cannot remove your own Super Admin role." },
        400,
      );
    }
    const { error } = await admin
      .from("profiles")
      .update({ role, updated_at: new Date().toISOString() })
      .eq("id", profileId);
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  }

  // ------------------------------------------------------------- set state
  if (action === "set_active") {
    const profileId = clean(payload.profile_id, 60);
    const active = payload.active === true;
    if (profileId === callerProfile.id && !active) {
      return json({ error: "You cannot suspend your own account." }, 400);
    }
    const { data: target } = await admin
      .from("profiles")
      .select("auth_user_id")
      .eq("id", profileId)
      .maybeSingle();
    if (!target?.auth_user_id) {
      return json({ error: "That member has no login attached." }, 404);
    }
    // A ban in GoTrue blocks the token refresh, so the member is signed out at
    // their next check instead of keeping a live session.
    const { error } = await admin.auth.admin.updateUserById(
      target.auth_user_id,
      { ban_duration: active ? "none" : "876000h" },
    );
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true, active });
  }

  return json({ error: `Unknown action "${action}".` }, 400);
});
