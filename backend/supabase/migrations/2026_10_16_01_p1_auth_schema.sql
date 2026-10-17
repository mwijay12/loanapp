-- ============================================================
-- LIMS P1 — MIGRATION 01: Auth schema, helper functions, triggers
-- ============================================================
-- Run AFTER 2026_10_16_00_p1_preflight_inspect.sql
-- Run as: postgres (Supabase SQL Editor default role)
--
-- WHY THIS DIFFERS FROM THE ORIGINAL DRAFT
-- The original draft used plain `CREATE TABLE IF NOT EXISTS`. If the live
-- database already has a `profiles` / `products` / `heartbeat_pings` table
-- (the app reads profiles.password_hash, which schema.sql never created,
-- so drift is certain), then `IF NOT EXISTS` silently does nothing and every
-- later policy/trigger fails with "column does not exist". This version is
-- therefore idempotent AND drift-tolerant:
--   * CREATE TABLE IF NOT EXISTS  → fresh databases
--   * ALTER TABLE ADD COLUMN IF NOT EXISTS → pre-existing drifted tables
--   * guarded constraint adds → no error if already present
--   * legacy plaintext credential column is dropped
-- This file is safe to re-run.
-- ============================================================


-- ============================================================
-- 0. EXTENSIONS
-- ============================================================
-- pgcrypto supplies crypt() / gen_salt() for the supervisor PIN hash.
-- Supabase normally installs extensions into the `extensions` schema, not
-- `public`. The functions below therefore carry `search_path = public, extensions`.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
    BEGIN
      CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
    EXCEPTION WHEN OTHERS THEN
      -- Fall back to the session default schema if `extensions` is unavailable.
      CREATE EXTENSION pgcrypto;
    END;
  END IF;
END $$;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ============================================================
-- 1. PROFILES — one row per auth.users row
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL DEFAULT 'New User',
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'Pending'
    CHECK (role IN (
      'Super Admin', 'Branch Manager', 'Loan Officer',
      'Storekeeper', 'Counter Cashier', 'Auditor', 'Pending'
    )),
  branch_id UUID,
  needs_password_reset BOOLEAN NOT NULL DEFAULT true,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Drift tolerance: make sure every expected column exists.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS branch_id UUID;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS needs_password_reset BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Retire the legacy plaintext credential column. Leaving it in place would
-- (a) keep an unused credential surface and (b) break the signup trigger,
-- which has no value to supply for it when it is NOT NULL.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles'
      AND column_name = 'password_hash'
  ) THEN
    ALTER TABLE public.profiles DROP COLUMN password_hash;
    RAISE NOTICE 'Dropped legacy public.profiles.password_hash (plaintext credential column).';
  END IF;
END $$;

-- Normalise legacy role values into the canonical set before any CHECK is added.
-- Anything unrecognised becomes 'Pending' (no access) rather than a guessed role:
-- silently promoting an unknown row to a working role is a privilege grant.
UPDATE public.profiles
SET role = CASE
  WHEN lower(role) IN ('admin', 'superadmin', 'super_admin', 'owner') THEN 'Super Admin'
  WHEN lower(role) IN ('manager', 'branch_manager', 'branch manager') THEN 'Branch Manager'
  WHEN lower(role) IN ('loan_officer', 'loan officer', 'officer')     THEN 'Loan Officer'
  WHEN lower(role) IN ('storekeeper', 'inventory officer', 'inventory_officer', 'store') THEN 'Storekeeper'
  WHEN lower(role) IN ('cashier', 'counter cashier', 'counter_cashier') THEN 'Counter Cashier'
  WHEN lower(role) IN ('auditor', 'audit')                           THEN 'Auditor'
  ELSE 'Pending'
END
WHERE role IS NULL
   OR role NOT IN ('Super Admin', 'Branch Manager', 'Loan Officer',
                   'Storekeeper', 'Counter Cashier', 'Auditor', 'Pending');

UPDATE public.profiles SET full_name = 'New User' WHERE full_name IS NULL OR btrim(full_name) = '';
UPDATE public.profiles SET is_active = true          WHERE is_active IS NULL;
UPDATE public.profiles SET needs_password_reset = true WHERE needs_password_reset IS NULL;
UPDATE public.profiles SET created_at = now()        WHERE created_at IS NULL;
UPDATE public.profiles SET updated_at = now()        WHERE updated_at IS NULL;

-- Add the role CHECK only if the table pre-existed without one.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_role_check'
      AND connamespace = 'public'::regnamespace
  ) THEN
    BEGIN
      ALTER TABLE public.profiles
        ADD CONSTRAINT profiles_role_check
        CHECK (role IN ('Super Admin', 'Branch Manager', 'Loan Officer',
                        'Storekeeper', 'Counter Cashier', 'Auditor', 'Pending'));
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Could not add profiles_role_check: %', SQLERRM;
    END;
  END IF;
END $$;

-- Case-insensitive uniqueness on email. auth.users.email is already unique,
-- but profiles.email is what the invitation matcher reads, so guard it too.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'profiles'
      AND indexname = 'profiles_email_lower_uq'
  ) THEN
    BEGIN
      CREATE UNIQUE INDEX profiles_email_lower_uq ON public.profiles (lower(email));
    EXCEPTION WHEN unique_violation THEN
      RAISE WARNING 'profiles has duplicate emails — profiles_email_lower_uq NOT created. De-duplicate, then re-run.';
    END;
  END IF;
END $$;

-- FK to auth.users, added conditionally for pre-existing tables.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_id_fkey'
      AND connamespace = 'public'::regnamespace
  ) THEN
    BEGIN
      ALTER TABLE public.profiles
        ADD CONSTRAINT profiles_id_fkey
        FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Could not add profiles_id_fkey (orphan profile rows?): %', SQLERRM;
    END;
  END IF;
END $$;

-- FK to branches, conditional (branches must exist — it does, from schema.sql).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'branches'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_branch_id_fkey'
      AND connamespace = 'public'::regnamespace
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_branch_id_fkey
      FOREIGN KEY (branch_id) REFERENCES public.branches(id)
      ON DELETE SET NULL;
  END IF;
END $$;

COMMENT ON TABLE public.profiles IS
  'User profiles linked to Supabase Auth. role + branch_id determine RLS scope.';


-- ============================================================
-- 2. ROLE_PERMISSIONS — the single source of truth for RBAC
-- ============================================================
CREATE TABLE IF NOT EXISTS public.role_permissions (
  role TEXT NOT NULL,
  permission TEXT NOT NULL,
  branch_scoped BOOLEAN NOT NULL DEFAULT true,
  PRIMARY KEY (role, permission)
);

COMMENT ON TABLE public.role_permissions IS
  'Permission matrix. Checked by has_permission() in RLS policies and by the client UI.';


-- ============================================================
-- 3. STAFF_INVITATIONS — admin invites, user self-activates
-- ============================================================
CREATE TABLE IF NOT EXISTS public.staff_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'Counter Cashier'
    CHECK (role IN (
      'Branch Manager', 'Loan Officer',
      'Storekeeper', 'Counter Cashier', 'Auditor'
    )),
  branch_id UUID,
  invited_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'used', 'expired', 'revoked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '7 days'),
  used_at TIMESTAMPTZ,
  used_by UUID REFERENCES auth.users(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS staff_invitations_pending_email_uq
  ON public.staff_invitations (lower(email))
  WHERE status = 'pending';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'branches'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'staff_invitations_branch_id_fkey'
      AND connamespace = 'public'::regnamespace
  ) THEN
    ALTER TABLE public.staff_invitations
      ADD CONSTRAINT staff_invitations_branch_id_fkey
      FOREIGN KEY (branch_id) REFERENCES public.branches(id)
      ON DELETE SET NULL;
  END IF;
END $$;

COMMENT ON TABLE public.staff_invitations IS
  'Admin creates an invitation → the user signs up with the matching email → handle_new_user() assigns the role.';


-- ============================================================
-- 4. BRANCH_SETTINGS — supervisor PIN hash, branch targets
-- ============================================================
CREATE TABLE IF NOT EXISTS public.branch_settings (
  branch_id UUID PRIMARY KEY,
  supervisor_pin_hash TEXT NOT NULL,
  daily_target_tzs BIGINT DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'branches'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'branch_settings_branch_id_fkey'
      AND connamespace = 'public'::regnamespace
  ) THEN
    ALTER TABLE public.branch_settings
      ADD CONSTRAINT branch_settings_branch_id_fkey
      FOREIGN KEY (branch_id) REFERENCES public.branches(id)
      ON DELETE CASCADE;
  END IF;
END $$;


-- ============================================================
-- 5. HEARTBEAT_PINGS — keep-alive table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.heartbeat_pings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source TEXT NOT NULL DEFAULT 'app',
  payload JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Drift tolerance. The Flutter client previously inserted a `metadata` key,
-- while this table defines `payload` — one of the two had to give. `payload`
-- wins; the old column is preserved if it somehow exists so no write breaks.
ALTER TABLE public.heartbeat_pings ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'app';
ALTER TABLE public.heartbeat_pings ADD COLUMN IF NOT EXISTS payload JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.heartbeat_pings ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_heartbeat_pings_created_at
  ON public.heartbeat_pings (created_at DESC);

COMMENT ON TABLE public.heartbeat_pings IS
  'Keep-alive pings. Anon INSERT is allowed so the heartbeat works without a session.';


-- ============================================================
-- 6. PRODUCTS — drift fix, minimum needed for the heartbeat probe
-- ============================================================
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  model TEXT,
  imei TEXT UNIQUE,
  imei2 TEXT,
  category TEXT DEFAULT 'phone',
  cost_price BIGINT DEFAULT 0,
  selling_price BIGINT DEFAULT 0,
  status TEXT DEFAULT 'available'
    CHECK (status IN ('available', 'sold', 'transferred', 'damaged', 'reserved')),
  branch_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS model TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS imei TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS imei2 TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'phone';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS cost_price BIGINT DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS selling_price BIGINT DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'available';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS branch_id UUID;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'branches'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'products_branch_id_fkey'
      AND connamespace = 'public'::regnamespace
  ) THEN
    ALTER TABLE public.products
      ADD CONSTRAINT products_branch_id_fkey
      FOREIGN KEY (branch_id) REFERENCES public.branches(id)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_products_branch ON public.products (branch_id);
CREATE INDEX IF NOT EXISTS idx_products_status ON public.products (status);


-- ============================================================
-- 7. ACTIVITIES — activity / audit feed
-- ============================================================
CREATE TABLE IF NOT EXISTS public.activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  action TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  details JSONB DEFAULT '{}'::jsonb,
  branch_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS action TEXT;
ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS entity_type TEXT;
ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS entity_id UUID;
ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS details JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS branch_id UUID;
ALTER TABLE public.activities ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_activities_created_at
  ON public.activities (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activities_branch
  ON public.activities (branch_id);


-- ============================================================
-- 8. HELPER FUNCTIONS (SECURITY DEFINER)
-- ============================================================
-- These run as the function owner (postgres), which owns the tables and
-- therefore bypasses RLS — that is what stops the policy recursion that
-- would otherwise occur when a policy on `profiles` needs to read `profiles`.
--
-- search_path is pinned on every SECURITY DEFINER function. Without it, a
-- caller could shadow `profiles` with their own schema and hijack the lookup.

CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT role FROM public.profiles
  WHERE id = auth.uid() AND is_active = true;
$$;

CREATE OR REPLACE FUNCTION public.get_user_branch_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT branch_id FROM public.profiles
  WHERE id = auth.uid() AND is_active = true;
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND is_active = true AND role = 'Super Admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_auditor()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND is_active = true
      AND role IN ('Super Admin', 'Auditor')
  );
$$;

CREATE OR REPLACE FUNCTION public.has_permission(perm TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.role_permissions rp
    JOIN public.profiles p ON p.role = rp.role
    WHERE p.id = auth.uid()
      AND p.is_active = true
      AND rp.permission = perm
  );
$$;

-- Hash a PIN with bcrypt. Exists so the seed file never has to guess which
-- schema pgcrypto was installed into.
CREATE OR REPLACE FUNCTION public.hash_pin(p_pin TEXT)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT crypt(p_pin, gen_salt('bf', 10));
$$;

-- Server-side supervisor PIN verification. Replaces the client-side
-- `!= '8821'` comparison that shipped in sell_loan_screen.dart, where any
-- user could read the expected value from the APK.
CREATE OR REPLACE FUNCTION public.verify_supervisor_pin(p_pin TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.branch_settings bs
    WHERE bs.branch_id = public.get_user_branch_id()
      AND bs.supervisor_pin_hash IS NOT NULL
      AND bs.supervisor_pin_hash = crypt(p_pin, bs.supervisor_pin_hash)
  );
$$;

-- Sets or rotates the branch supervisor PIN. Callable only by a Super Admin,
-- so the hash never has to be written from the client.
CREATE OR REPLACE FUNCTION public.set_supervisor_pin(p_branch_id UUID, p_pin TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Only a Super Admin may change the supervisor PIN.';
  END IF;
  IF p_pin IS NULL OR length(btrim(p_pin)) < 4 THEN
    RAISE EXCEPTION 'PIN must be at least 4 characters.';
  END IF;

  INSERT INTO public.branch_settings (branch_id, supervisor_pin_hash, updated_at)
  VALUES (p_branch_id, crypt(btrim(p_pin), gen_salt('bf', 10)), now())
  ON CONFLICT (branch_id) DO UPDATE
    SET supervisor_pin_hash = EXCLUDED.supervisor_pin_hash,
        updated_at = now();

  RETURN true;
END $$;

-- Does a usable invitation exist for this email?
-- Needed because the signup screen must validate BEFORE creating an auth user.
-- Returns a single boolean, never the invitation row: the original draft gave
-- `anon` a SELECT policy on staff_invitations with no email predicate, which
-- let anyone holding the public anon key list every pending invite
-- (full name, email, role, branch).
CREATE OR REPLACE FUNCTION public.has_pending_invitation(p_email TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.staff_invitations
    WHERE lower(email) = lower(btrim(p_email))
      AND status = 'pending'
      AND expires_at > now()
  );
$$;

-- Keep-alive probe. Replaces the anon SELECT policy the original draft put on
-- `products`, which exposed cost_price and selling_price to anyone with the
-- public anon key. RLS is row-level, not column-level, so a "safe subset"
-- policy on that table was never possible — this returns a single number.
CREATE OR REPLACE FUNCTION public.heartbeat_probe()
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT jsonb_build_object(
    'ok', true,
    'available_products', (
      SELECT count(*) FROM public.products WHERE status = 'available'
    ),
    'at', now()
  );
$$;


-- ============================================================
-- 9. AUTH TRIGGER — create the profile on signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  inv RECORD;
BEGIN
  -- A pending, unexpired invitation for this email decides the role.
  SELECT * INTO inv
  FROM public.staff_invitations
  WHERE lower(email) = lower(NEW.email)
    AND status = 'pending'
    AND expires_at > now()
  ORDER BY created_at DESC
  LIMIT 1;

  -- `AS p` gives the ON CONFLICT branch a stable, schema-independent way to
  -- reference the pre-existing row.
  INSERT INTO public.profiles AS p (
    id, email, full_name, role, branch_id, needs_password_reset, is_active
  ) VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NULLIF(btrim(NEW.raw_user_meta_data->>'full_name'), ''),
      inv.full_name,
      'New User'
    ),
    COALESCE(inv.role, 'Pending'),
    inv.branch_id,
    -- Force a password change ONLY for accounts an admin created and handed
    -- over with a starter password (no invitation on file). A user who signed
    -- up against an invitation already chose their own password — forcing a
    -- reset there would demand they change the password they just typed.
    (inv.id IS NULL),
    true
  )
  ON CONFLICT (id) DO UPDATE SET
    email      = EXCLUDED.email,
    full_name  = COALESCE(NULLIF(btrim(EXCLUDED.full_name), ''), p.full_name),
    role       = CASE
                   WHEN p.role = 'Pending' THEN EXCLUDED.role
                   ELSE p.role   -- never overwrite an admin-assigned role
                 END,
    branch_id  = COALESCE(EXCLUDED.branch_id, p.branch_id),
    updated_at = now();

  IF inv.id IS NOT NULL THEN
    UPDATE public.staff_invitations
    SET status = 'used', used_at = now(), used_by = NEW.id
    WHERE id = inv.id;
  END IF;

  INSERT INTO public.activities (user_id, action, entity_type, entity_id, details, branch_id)
  VALUES (
    NEW.id, 'user.signup', 'profile', NEW.id,
    jsonb_build_object(
      'email', NEW.email,
      'role', COALESCE(inv.role, 'Pending'),
      'via_invitation', (inv.id IS NOT NULL)
    ),
    inv.branch_id
  );

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
-- 10. updated_at TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, extensions
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS branch_settings_updated_at ON public.branch_settings;
CREATE TRIGGER branch_settings_updated_at
  BEFORE UPDATE ON public.branch_settings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS products_updated_at ON public.products;
CREATE TRIGGER products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


-- ============================================================
-- 11. FUNCTION GRANTS
-- ============================================================
-- SECURITY DEFINER functions are EXECUTE-granted to PUBLIC by default. Lock
-- every internal helper down to authenticated, then re-open only the two
-- entry points that genuinely need to be callable before a session exists.
REVOKE ALL ON FUNCTION public.get_user_role()               FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_branch_id()          FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_super_admin()              FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_auditor()                  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_permission(TEXT)          FROM PUBLIC;
REVOKE ALL ON FUNCTION public.hash_pin(TEXT)                FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_supervisor_pin(TEXT)   FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_supervisor_pin(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_pending_invitation(TEXT)  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.heartbeat_probe()             FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_user_role()               TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_branch_id()          TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_super_admin()              TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_auditor()                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_permission(TEXT)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_supervisor_pin(TEXT)   TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_supervisor_pin(UUID, TEXT) TO authenticated;

-- Pre-session entry points.
GRANT EXECUTE ON FUNCTION public.has_pending_invitation(TEXT)  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.heartbeat_probe()             TO anon, authenticated;
-- hash_pin() stays private to postgres: it is only used by the seed and by
-- set_supervisor_pin(), both of which are already privileged.


-- ============================================================
-- 12. VERIFY
-- ============================================================
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
-- Expect the 13 original tables + profiles, role_permissions,
-- staff_invitations, branch_settings, heartbeat_pings, products, activities.
