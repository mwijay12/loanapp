-- Remove the eighteen policies that grant the world access.
--
-- Confirmed from pg_policies on 22 Oct 2026. Every one of these has
-- roles = {public}, which is the role an anonymous request gets:
--
--   Allow public read  activities
--   Allow public write activities
--   Allow public read  branches
--   Allow public write branches
--   Allow public read  loans
--   Allow public write loans
--   Allow public read  product_history
--   Allow public write product_history
--   Allow public read  products
--   Allow public write products
--   Allow public read  profiles
--   Allow public write profiles
--   Allow public read  staff
--   Allow public write staff
--   Allow anon heartbeat read
--   Allow anon heartbeat insert
--
-- Postgres ORs policies, so a single `{public}` policy beside the role-aware ones
-- opens the table completely. That is why the app's own policies looked correct
-- while an anonymous caller could still read every profile row and insert rows.
--
-- This drops them by exact name. Nothing else is touched, so there is no window
-- where a legitimately scoped policy is missing.
--
-- Safe to run twice: dropping a policy that is already gone does nothing.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

drop policy if exists "Allow public read activities"        on public.activities;
drop policy if exists "Allow public write activities"       on public.activities;

drop policy if exists "Allow public read branches"          on public.branches;
drop policy if exists "Allow public write branches"         on public.branches;

drop policy if exists "Allow public read loans"             on public.loans;
drop policy if exists "Allow public write loans"            on public.loans;

drop policy if exists "Allow public read product_history"   on public.product_history;
drop policy if exists "Allow public write product_history"  on public.product_history;

drop policy if exists "Allow public read products"          on public.products;
drop policy if exists "Allow public write products"         on public.products;

drop policy if exists "Allow public read profiles"          on public.profiles;
drop policy if exists "Allow public write profiles"         on public.profiles;

drop policy if exists "Allow public read staff"             on public.staff;
drop policy if exists "Allow public write staff"            on public.staff;

drop policy if exists "Allow anon heartbeat read"           on public.heartbeat_pings;
drop policy if exists "Allow anon heartbeat insert"         on public.heartbeat_pings;

commit;

-- Expect only the role-aware policies now: names ending in _read, _read_self,
-- _read_staff, _admin_write, _create, _update, _delete, _append, _stock_write.
select tablename, policyname, roles::text, cmd
from pg_policies
where schemaname = 'public'
order by tablename, policyname;
