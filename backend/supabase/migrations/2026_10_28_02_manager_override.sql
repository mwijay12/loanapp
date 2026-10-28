-- R9 — a Storekeeper may sell, but only while a Branch Manager is standing at
-- the till and has typed their own PIN. Chosen by the owner over "give the
-- Storekeeper the sale role", because the shop has few staff and the person
-- holding the stock is not the person who should be able to write revenue.
--
-- What has to be true for that sentence to mean something:
--
--   1. The check must live in the database. A Dart gate is a UI courtesy: the
--      publishable key ships inside the bundle, so anyone who can open devtools
--      can POST /rest/v1/sales directly. Enforcement is therefore in the INSERT
--      policy of `sales` / `loan_payments`.
--   2. The PIN must not become a second password that gets shared. It is stored
--      bcrypt-hashed (extensions.crypt) and is never returned by any function —
--      verification returns a single-use token instead.
--   3. The token must be unrepeatable and short-lived: bound to (the staff being
--      helped, the branch, the action), expires in 3 minutes, and consumed by the
--      database the first time it is spent.
--   4. The record of who approved what must be one the client cannot write, edit
--      or delete. `override_audit` has INSERT revoked from anon/authenticated and
--      no UPDATE/DELETE policy at all; only SECURITY DEFINER functions append.
--
-- Read scope deliberately NOT changed: sales_read stays closed to Storekeeper.
-- `sales` carries customer_name and customer_phone, and the owner's question was
-- about selling, not about reading the branch ledger. Same principle as R6.
--
-- Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

-- --------------------------------------------------------------- 1. PIN storage
alter table public.profiles add column if not exists manager_pin_hash text;
alter table public.profiles add column if not exists manager_pin_set_at timestamptz;

comment on column public.profiles.manager_pin_hash is
  'bcrypt hash of the till-override PIN. NULL = this manager has never set one, '
  'so no override can be granted through them.';

-- ---------------------------------------------------------- 2. helpers (definer)
-- The tables these read have RLS of their own, and a policy that asks about the
-- caller's role/profile would recurse back into profiles. SECURITY DEFINER with a
-- pinned search_path is the same pattern 2026_10_22_04_repair_rls.sql established.

create or replace function public.current_branch_name()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.branch_name
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;
$$;

-- The signed-in staff member's `profiles.id`. Needed by the attribution triggers:
-- `sales.staff_id` points at profiles, not at auth.users, so the JWT subject
-- cannot be written into it directly.
create or replace function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;
$$;

-- `sales.branch_id` is a uuid while `profiles.branch_name` is a label, so the two
-- are joined on the branch name. Matching is case-insensitive because seeded
-- rows say 'Mbagala' in one table and 'Mbagala Branch' in another; the lookup
-- prefers an exact name and only falls back to the loose one.
create or replace function public.branch_id_for_current_staff()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select b.id
  from public.branches b
  where lower(b.name) = lower(coalesce(public.current_branch_name(), ''))
  order by (b.name = public.current_branch_name()) desc nulls last
  limit 1;
$$;

-- --------------------------------------------------------------- 3. the two ledgers
create table if not exists public.manager_overrides (
  id uuid primary key default gen_random_uuid(),
  token uuid not null unique default gen_random_uuid(),
  action text not null,
  branch_name text not null,
  granted_to uuid not null references public.profiles (id),
  granted_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '3 minutes',
  consumed_at timestamptz,
  constraint manager_overrides_action_check check (action in ('sale', 'payment'))
);

create index if not exists manager_overrides_open_idx
  on public.manager_overrides (granted_to, action, expires_at)
  where consumed_at is null;

create table if not exists public.override_audit (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  action text not null,
  actor_profile uuid references public.profiles (id),
  manager_profile uuid references public.profiles (id),
  branch_name text,
  target_table text,
  target_id text,
  detail jsonb not null default '{}'::jsonb,
  constraint override_audit_action_check check (action in
    ('pin_set', 'pin_failed', 'override_granted', 'sale_recorded', 'payment_recorded'))
);

create index if not exists override_audit_at_idx on public.override_audit (at desc);
create index if not exists override_audit_actor_idx on public.override_audit (actor_profile, at desc);

-- ------------------------------------------------------------- 4. who can see them
alter table public.manager_overrides enable row level security;
alter table public.override_audit enable row level security;

-- No INSERT/UPDATE/DELETE policy on manager_overrides or override_audit, and the
-- grants below take even SELECT away from the client on the token table: an
-- override is granted by the database, never declared by the caller.
drop policy if exists override_audit_read on public.override_audit;
create policy override_audit_read on public.override_audit
  for select to authenticated
  using (public.has_any_role(array['Super Admin', 'Branch Manager', 'Auditor']));

revoke all on public.manager_overrides from anon, authenticated;
revoke update, delete, truncate on public.override_audit from anon, authenticated;
revoke insert on public.override_audit from anon, authenticated;
grant select on public.override_audit to authenticated;

-- --------------------------------------------------------- 5. set / verify the PIN
--
-- Parameters are prefixed `p_` on purpose. The first version named them `pin` and
-- `action`, and the moment `request_manager_override` ran it died with
--   42702: it could refer to either a PL/pgSQL variable or a table column
-- because `override_audit.action` is also called `action`. The failure only
-- appeared at call time, not at create time, so a review that only reads the DDL
-- would have signed it off. Prefixing every parameter makes the collision
-- impossible instead of unlikely.
--
-- WARNING for whoever writes the Dart client: PostgREST resolves an RPC by the
-- *names* of its parameters, so `p_pin` and `p_action` are part of the public HTTP
-- contract, not internal detail. The body must be {"p_pin": ..., "p_action": ...};
-- {"pin": ...} returns 404 PGRST202 "function could not be found". Renaming a
-- parameter later is a breaking API change, exactly like renaming a column.
--
-- `create or replace function` cannot rename an existing parameter, so the
-- first (broken) definitions must be dropped or the whole migration dies with
--   42P13: cannot change name of input parameter "pin"
-- Function identity is (name, arg types), so dropping by type list removes the
-- old badly-named version regardless of what its parameters were called.
-- Neither function is referenced by a policy or view, so nothing depends on them.
drop function if exists public.set_manager_pin(text);
drop function if exists public.request_manager_override(text, text);

create or replace function public.set_manager_pin(p_pin text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role text := public.current_staff_role();
begin
  if v_role is null then
    raise exception 'override_no_session' using errcode = '42501';
  end if;
  if v_role not in ('Super Admin', 'Branch Manager') then
    raise exception 'override_role_forbidden' using errcode = '42501';
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{4,8}$' then
    raise exception 'override_pin_format' using errcode = '22023';
  end if;

  update public.profiles
     set manager_pin_hash = extensions.crypt(p_pin, extensions.gen_salt('bf', 8)),
         manager_pin_set_at = now(),
         updated_at = now()
   where auth_user_id = auth.uid();

  insert into public.override_audit (action, actor_profile, manager_profile, branch_name, detail)
  select 'pin_set', p.id, p.id, p.branch_name, jsonb_build_object('role', p.role)
    from public.profiles p
   where p.auth_user_id = auth.uid();
end;
$$;

-- Returns the single-use token, or raises a code the app can translate. Five
-- wrong guesses in a quarter of an hour locks the caller out, because a 4-digit
-- PIN on a counter screen is otherwise brute-forceable by a patient person.
create or replace function public.request_manager_override(p_pin text, p_action text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor   public.profiles%rowtype;
  v_manager public.profiles%rowtype;
  v_fails   int;
  v_token   uuid;
begin
  if p_action is null or p_action not in ('sale', 'payment') then
    raise exception 'override_action_unknown' using errcode = '22023';
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{4,8}$' then
    raise exception 'override_pin_format' using errcode = '22023';
  end if;

  select * into v_actor from public.profiles where auth_user_id = auth.uid();
  if v_actor.id is null then
    raise exception 'override_no_session' using errcode = '42501';
  end if;

  -- The lockout counter reads the audit trail itself, so the same five guesses
  -- that would brute-force a PIN also build the evidence a manager would want.
  select count(*) into v_fails
    from public.override_audit a
   where a.actor_profile = v_actor.id
     and a.action = 'pin_failed'
     and a.at > now() - interval '15 minutes';
  if v_fails >= 5 then
    raise exception 'override_pin_locked' using errcode = '42501';
  end if;

  select * into v_manager
    from public.profiles
   where role in ('Branch Manager', 'Super Admin')
     and branch_name is not null
     and lower(branch_name) = lower(coalesce(v_actor.branch_name, ''))
     and manager_pin_hash is not null
     and manager_pin_hash = extensions.crypt(p_pin, manager_pin_hash)
   limit 1;

  if v_manager.id is null then
    -- A wrong PIN is recorded and then answered with NULL, NOT with an exception.
    --
    -- The first version inserted the pin_failed row and immediately did
    --   raise exception 'override_pin_invalid'
    -- which looked completely correct — the API returned 403 and the test for
    -- "wrong PIN is refused" passed. But PL/pgSQL raises inside a security definer
    -- function abort the enclosing transaction, so the audit row written two lines
    -- earlier was rolled back. `select count(*) from override_audit where action =
    -- 'pin_failed'` returned 0 after three deliberate wrong-PIN calls, which means
    -- the lockout counter above could never reach five: the brute-force protection
    -- was decorative. A third defect in this file that a DDL review cannot see —
    -- it is only visible by querying the table after a failure, never by reading
    -- the code, and never by checking the HTTP status.
    --
    -- Returning NULL keeps the same security property (no row is written to
    -- manager_overrides, so the sale/payment is still refused by RLS — see checks
    -- B, F3 and G) and lets the transaction commit so the evidence survives. The
    -- lockout branch below still raises, and that is fine: by the time it fires the
    -- five counted rows are already committed, so the lockout is sticky even though
    -- its own sixth row is rolled back.
    insert into public.override_audit (action, actor_profile, branch_name, detail)
    values ('pin_failed', v_actor.id, v_actor.branch_name,
            jsonb_build_object('attempt', v_fails + 1, 'action', p_action));
    return null;
  end if;

  insert into public.manager_overrides (action, branch_name, granted_to, granted_by)
  values (p_action, v_actor.branch_name, v_actor.id, v_manager.id)
  returning token into v_token;

  insert into public.override_audit (action, actor_profile, manager_profile, branch_name, detail)
  values ('override_granted', v_actor.id, v_manager.id, v_actor.branch_name,
          jsonb_build_object('token', v_token, 'action', p_action));

  return v_token;
end;
$$;

-- Called from inside the INSERT policies. STABLE because it only reads; the token
-- is spent by the AFTER INSERT trigger, not here.
create or replace function public.manager_override_is_valid(p_token uuid, p_action text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p_token is not null
     and exists (
       select 1
         from public.manager_overrides o
         join public.profiles actor on actor.id = o.granted_to
        where o.token = p_token
          and o.action = p_action
          and o.consumed_at is null
          and o.expires_at > now()
          and actor.auth_user_id = auth.uid()
     );
$$;

-- ------------------------------------------------------------ 6. the actual gates
alter table public.sales add column if not exists override_token uuid;
alter table public.loan_payments add column if not exists override_token uuid;

drop policy if exists sales_create on public.sales;
create policy sales_create on public.sales
  for insert to authenticated
  with check (
    public.has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer', 'Counter Cashier'])
    or public.manager_override_is_valid(override_token, 'sale')
  );

drop policy if exists loan_payments_create on public.loan_payments;
create policy loan_payments_create on public.loan_payments
  for insert to authenticated
  with check (
    public.has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer', 'Counter Cashier'])
    or public.manager_override_is_valid(override_token, 'payment')
  );

-- --------------------------------------------------- 7. spend it, and record the spend
-- Attribution. A sale that needed an override is exactly the case where the
-- database must not trust the client: `staff_id` and `branch_id` are taken from
-- the session, so a token granted to the Mbagala storekeeper cannot be spent as
-- somebody else's sale or at another branch. `sales` and `loan_payments` use
-- different column names for the same idea (staff_id / recorded_by), so they get
-- separate trigger functions rather than one function guessing.
create or replace function public.stamp_override_sale_author()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.override_token is not null then
    new.staff_id := public.current_profile_id();
    if new.staff_id is null then
      raise exception 'override_no_session' using errcode = '42501';
    end if;
    new.branch_id := public.branch_id_for_current_staff();
  end if;
  return new;
end;
$$;

create or replace function public.stamp_override_payment_author()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.override_token is not null then
    new.recorded_by := public.current_profile_id();
    if new.recorded_by is null then
      raise exception 'override_no_session' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists sales_stamp_override_author on public.sales;
create trigger sales_stamp_override_author
  before insert on public.sales
  for each row execute function public.stamp_override_sale_author();
drop trigger if exists loan_payments_stamp_override_author on public.loan_payments;
create trigger loan_payments_stamp_override_author
  before insert on public.loan_payments
  for each row execute function public.stamp_override_payment_author();

-- Spending the token. One function per table, deliberately.
--
-- The first version was a single function shared by both triggers, choosing its
-- columns with `case when tg_table_name = 'sales' then ... new.total ... else
-- ... new.amount ... end`. Both triggers then failed on every insert:
--   42703: record "new" has no field "amount"     (on sales)
--   42703: record "new" has no field "receipt_no" (on loan_payments)
-- because PL/pgSQL resolves every `new.<column>` reference when the function is
-- first planned, not when the branch is taken — a CASE guards values, not names.
-- `sales` has no `amount` and `loan_payments` has no `receipt_no`, so each branch
-- referenced a column the other table does not own.
--
-- This is the second call-time-only defect in this file (after 42702). Neither is
-- visible in the DDL: the migration applies cleanly either way, and the money
-- path only breaks the first time a real sale is rung. The audit insert is split
-- per table so there is nothing left to guess.
--
-- Drop the shared version first — and note the order: the two triggers depend on
-- it, so `drop function` before `drop trigger` dies with
--   2BP01: cannot drop function record_override_spent() because other objects
--          depend on it (trigger sales_record_override_spent on table sales ...)
-- Dropping the dependents first is what keeps this file re-appliable without
-- CASCADE, which would have silently taken the triggers with it.
drop trigger if exists sales_record_override_spent on public.sales;
drop trigger if exists loan_payments_record_override_spent on public.loan_payments;
drop function if exists public.record_override_spent();

create or replace function public.record_override_sale_spent()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.override_token is null then
    return new;
  end if;

  update public.manager_overrides
     set consumed_at = now()
   where token = new.override_token
     and consumed_at is null;

  insert into public.override_audit
    (action, actor_profile, manager_profile, branch_name, target_table, target_id, detail)
  select 'sale_recorded', o.granted_to, o.granted_by, o.branch_name,
         'sales', new.id::text,
         jsonb_build_object('receipt_no', new.receipt_no, 'kind', new.kind,
                            'total', new.total, 'imei', new.imei)
    from public.manager_overrides o
   where o.token = new.override_token;
  return new;
end;
$$;

create or replace function public.record_override_payment_spent()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.override_token is null then
    return new;
  end if;

  update public.manager_overrides
     set consumed_at = now()
   where token = new.override_token
     and consumed_at is null;

  insert into public.override_audit
    (action, actor_profile, manager_profile, branch_name, target_table, target_id, detail)
  select 'payment_recorded', o.granted_to, o.granted_by, o.branch_name,
         'loan_payments', new.id::text,
         jsonb_build_object('loan_id', new.loan_id, 'amount', new.amount,
                            'channel', new.channel)
    from public.manager_overrides o
   where o.token = new.override_token;
  return new;
end;
$$;

drop trigger if exists sales_record_override_spent on public.sales;
create trigger sales_record_override_spent
  after insert on public.sales
  for each row execute function public.record_override_sale_spent();
drop trigger if exists loan_payments_record_override_spent on public.loan_payments;
create trigger loan_payments_record_override_spent
  after insert on public.loan_payments
  for each row execute function public.record_override_payment_spent();

commit;

-- Verification: every function exists and is SECURITY DEFINER, and the INSERT
-- policies now mention manager_override_is_valid.
select p.proname, p.prosecdef
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('set_manager_pin', 'request_manager_override',
                     'manager_override_is_valid', 'current_branch_name',
                     'current_profile_id', 'branch_id_for_current_staff',
                     'stamp_override_sale_author', 'stamp_override_payment_author',
                      'record_override_sale_spent', 'record_override_payment_spent')
 order by 1;

select tg.tgname as trigger_name, c.relname as on_table
  from pg_trigger tg join pg_class c on c.oid = tg.tgrelid
 where not tg.tgisinternal
   and c.relname in ('sales', 'loan_payments', 'petty_cash')
 order by 2, 1;

select tablename, policyname, cmd, with_check
  from pg_policies
 where schemaname = 'public' and tablename in ('sales', 'loan_payments')
   and cmd = 'INSERT'
 order by 1;
