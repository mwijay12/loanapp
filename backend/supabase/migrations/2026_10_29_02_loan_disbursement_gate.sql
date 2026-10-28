-- A high-value loan needs a manager, and the database has to be the one that says so.
--
-- The rule "a loan above TZS 1,000,000 needs supervisor approval" lives in the app
-- and nowhere else. `sell_loan_screen.dart` reads
--
--   static const String _supervisorPin = String.fromEnvironment('SUPERVISOR_PIN');
--
-- and compares the typed PIN with it before allowing the sale. Three problems, in
-- increasing order of seriousness:
--
--  1. It is one shared secret baked into a build. It identifies no person, so
--     `override_audit` could never say who approved what even if it wanted to. It
--     cannot be revoked per person, and it is present in the bundle of every device
--     that runs the build.
--  2. If the flag is not passed at build time - which is the normal case, since it
--     is not in the documented build command - `_supervisorPin` is the empty string
--     and the check refuses every high-value loan with "not configured. Contact
--     your administrator." The shop's answer is then to build without the check, or
--     to book the loan as cash.
--  3. It is client-side. `POST /rest/v1/loans` with an amount of 5,000,000 and no
--     PIN at all is accepted today by `loans_create`, whose only condition is
--     `has_any_role('Super Admin','Branch Manager','Loan Officer')`. The publishable
--     key is in the web bundle, so the form is not the gate - the policy is.
--
-- This migration moves the rule to the policy, using the machinery already proven
-- in 2026_10_28_02: the manager types *their own* PIN, `request_manager_override`
-- verifies it with bcrypt against `profiles.manager_pin_hash`, and the row is
-- accepted only with the single-use token it hands back. Who approved, when, for
-- how much, and what the customer's name was, all land in `override_audit`, which
-- no client may write, change or delete.
--
-- Deliberate choices:
--   * The role check stays first. A Storekeeper with a perfectly good
--     disbursement token is still refused, because they may not book loans at all.
--     An approval lifts a limit on an authorised action; it does not authorise the
--     action itself.
--   * The threshold is a function, not a magic number in two places, so the app's
--     copy and the policy cannot drift.
--   * `amount` is compared with `<`, so exactly TZS 1,000,000 still needs no
--     approval, matching the sentence the screen shows.
--   * The token is spent by an AFTER INSERT trigger, one function per table: a
--     shared function would have failed with 42703 on `new.record_no` versus
--     `new.receipt_no` - PL/pgSQL resolves column *names* when it plans, so a CASE
--     on `tg_table_name` does not protect you (the lesson from 2026_10_28_02).
--
-- Run in the Supabase SQL editor, or: python3 tools/sql.py -f <this file>
-- Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

-- ------------------------------------------------------------------ threshold
create or replace function public.loan_override_threshold()
returns numeric
language sql
immutable
as $$
  select 1000000::numeric;
$$;

comment on function public.loan_override_threshold() is
  'A loan at or below this amount may be booked by an authorised role alone. Above '
  'it, sales-style manager approval is required: see loans_create with_check.';

-- ------------------------------------------------------------- token columns
alter table public.loans add column if not exists override_token uuid;

-- ------------------------------------------------------ widen the action sets
-- `manager_overrides` and `override_audit` only knew 'sale' and 'payment'.
-- Dropping a CHECK re-validates nothing here (the new set is a superset), so the
-- existing audit rows are untouched.
alter table public.manager_overrides
  drop constraint if exists manager_overrides_action_check;
alter table public.manager_overrides
  add constraint manager_overrides_action_check
  check (action in ('sale', 'payment', 'disbursement'));

alter table public.override_audit
  drop constraint if exists override_audit_action_check;
alter table public.override_audit
  add constraint override_audit_action_check
  check (action in ('pin_set', 'pin_failed', 'override_granted',
                    'sale_recorded', 'payment_recorded', 'disbursement_recorded'));

-- ------------------------------------------------------------- the real gate
drop policy if exists loans_create on public.loans;
create policy loans_create on public.loans
  for insert to authenticated
  with check (
    has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer'])
    and (
      coalesce(amount, 0) < public.loan_override_threshold()
      or manager_override_is_valid(override_token, 'disbursement')
    )
  );

-- Stamp the real author on an approved row, exactly as the sales trigger does: the
-- token means a manager stood here, so the booking is attributed to the session
-- that holds it rather than to whatever id the client sent.
create or replace function public.stamp_override_loan_author()
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

drop trigger if exists loans_stamp_override_author on public.loans;
create trigger loans_stamp_override_author
  before insert on public.loans
  for each row execute function public.stamp_override_loan_author();

create or replace function public.record_override_loan_spent()
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
  select 'disbursement_recorded', o.granted_to, o.granted_by, o.branch_name,
         'loans', new.id::text,
         -- `loans` calls it borrower_name; sales calls it customer_name. Writing the
         -- sales name here applied cleanly and would have raised 42703 on the first
         -- approved loan - the exact trap 2026_10_28_02 documents.
         jsonb_build_object('loan_no', new.loan_no,
                            'borrower_name', new.borrower_name,
                            'item_name', new.item_name,
                            'imei', new.imei,
                            'amount', new.amount)
    from public.manager_overrides o
   where o.token = new.override_token;
  return new;
end;
$$;

drop trigger if exists loans_record_override_spent on public.loans;
create trigger loans_record_override_spent
  after insert on public.loans
  for each row execute function public.record_override_loan_spent();

revoke all on function public.stamp_override_loan_author() from public, anon, authenticated;
revoke all on function public.record_override_loan_spent() from public, anon, authenticated;
grant execute on function public.stamp_override_loan_author() to authenticated;
grant execute on function public.record_override_loan_spent() to authenticated;

-- ------------------------------------------------------ widen the RPC's own list
-- `request_manager_override` refused anything but 'sale'/'payment' with
-- override_action_unknown, so the token this gate needs could not be issued at all.
-- Postgres cannot alter a function body, so this is the original definition with
-- exactly one line changed - the action list. Everything else, including the
-- "return null on a wrong PIN so the audit row survives" behaviour, is byte-identical
-- to 2026_10_28_02.
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
  if p_action is null or p_action not in ('sale', 'payment', 'disbursement') then
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
    -- A wrong PIN is recorded and then answered with NULL, NOT with an exception:
    -- raising here would roll back the pin_failed row and make the lockout
    -- decorative. The full reason is written once, in
    -- 2026_10_28_02_manager_override.sql, and is unchanged in this version.
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


commit;

-- ------------------------------------------------------------------ what to look at
-- tools/verify_loan_gate.py runs this whole contract against the live project as
-- real roles and removes what it created.
--
-- select polname, pg_get_expr(polwithcheck, 'public.loans'::regclass) as with_check
--   from pg_policy where polrelid = 'public.loans'::regclass and polname = 'loans_create';
--
-- select action, count(*) from public.override_audit
--  where action = 'disbursement_recorded' group by action;

