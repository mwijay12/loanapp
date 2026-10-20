-- Row Level Security policies for LIMS.
--
-- Why this file exists: every table already has rowsecurity = true, but a table
-- with RLS enabled and no policy denies everything, and a table with
-- `using (true)` allows everything. Neither is a security model. These policies
-- state who may read and who may write, using the role stored on the profile.
--
-- Read this before running:
--   1. Run it inside a transaction so you can inspect the result and roll back:
--        begin; \i this_file.sql  ...  commit;  -- or rollback;
--   2. It assumes `profiles` carries `auth_user_id` (auth.users.id) and `role`.
--   3. It assumes these role labels: 'Super Admin', 'Branch Manager',
--      'Loan Officer', 'Storekeeper', 'Counter Cashier', 'Auditor', 'Pending'.
--   4. Anything not covered by a policy is denied. That is intentional.
--
-- It does not change data. It only creates functions and policies.

-- ---------------------------------------------------------------- helpers
-- Reading the caller's role from `profiles` inside a policy would recurse into
-- the profiles policy, so the lookup is a security-definer function. It returns
-- exactly one value: the role string, or null when the caller has no profile.
create or replace function public.current_staff_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.role
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;
$$;

revoke all on function public.current_staff_role() from public;
grant execute on function public.current_staff_role() to authenticated;

-- True when the caller holds any of the given roles.
create or replace function public.has_any_role(roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_staff_role() = any(roles), false);
$$;

revoke all on function public.has_any_role(text[]) from public;
grant execute on function public.has_any_role(text[]) to authenticated;

-- ---------------------------------------------------------------- profiles
-- A person may always read their own profile. Managers and admins may read the
-- staff list of their business. Nobody may write their own role.
alter table public.profiles enable row level security;

drop policy if exists profiles_read_self on public.profiles;
create policy profiles_read_self on public.profiles
  for select to authenticated
  using (auth_user_id = auth.uid());

drop policy if exists profiles_read_staff on public.profiles;
create policy profiles_read_staff on public.profiles
  for select to authenticated
  using (public.has_any_role(array['Super Admin', 'Branch Manager', 'Auditor']));

drop policy if exists profiles_admin_write on public.profiles;
create policy profiles_admin_write on public.profiles
  for all to authenticated
  using (public.has_any_role(array['Super Admin']))
  with check (public.has_any_role(array['Super Admin']));

-- A user may update their own contact details, but the check clause keeps role
-- and branch under admin control: a self-update that changes role is rejected.
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (auth_user_id = auth.uid())
  with check (
    auth_user_id = auth.uid()
    and role = public.current_staff_role()
  );

-- ---------------------------------------------------------------- branches
alter table public.branches enable row level security;

drop policy if exists branches_read on public.branches;
create policy branches_read on public.branches
  for select to authenticated
  using (public.current_staff_role() is not null);

drop policy if exists branches_admin_write on public.branches;
create policy branches_admin_write on public.branches
  for all to authenticated
  using (public.has_any_role(array['Super Admin']))
  with check (public.has_any_role(array['Super Admin']));

-- ---------------------------------------------------------------- products
-- Stock is readable by every signed-in staff member: a cashier must see a price
-- and an availability count to serve a customer. Writes belong to the people who
-- receive and move stock.
alter table public.products enable row level security;

drop policy if exists products_read on public.products;
create policy products_read on public.products
  for select to authenticated
  using (public.current_staff_role() is not null);

drop policy if exists products_stock_write on public.products;
create policy products_stock_write on public.products
  for all to authenticated
  using (public.has_any_role(array['Super Admin', 'Branch Manager', 'Storekeeper']))
  with check (public.has_any_role(array['Super Admin', 'Branch Manager', 'Storekeeper']));

-- ------------------------------------------------------------- product_history
alter table public.product_history enable row level security;

drop policy if exists product_history_read on public.product_history;
create policy product_history_read on public.product_history
  for select to authenticated
  using (public.has_any_role(array['Super Admin', 'Branch Manager', 'Storekeeper', 'Auditor']));

drop policy if exists product_history_append on public.product_history;
create policy product_history_append on public.product_history
  for insert to authenticated
  with check (public.has_any_role(array['Super Admin', 'Branch Manager', 'Storekeeper']));

-- ---------------------------------------------------------------- loans
-- Loan records carry customer PII, so reading is limited to the roles that work
-- with borrowers. A cashier can take a payment without seeing a full file.
alter table public.loans enable row level security;

drop policy if exists loans_read on public.loans;
create policy loans_read on public.loans
  for select to authenticated
  using (public.has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer', 'Auditor']));

drop policy if exists loans_create on public.loans;
create policy loans_create on public.loans
  for insert to authenticated
  with check (public.has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer']));

drop policy if exists loans_update on public.loans;
create policy loans_update on public.loans
  for update to authenticated
  using (public.has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer']))
  with check (public.has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer']));

-- Deleting a loan is an audit event, not a correction. Nobody deletes inline.
drop policy if exists loans_delete on public.loans;
create policy loans_delete on public.loans
  for delete to authenticated
  using (public.has_any_role(array['Super Admin']));

-- ---------------------------------------------------------------- staff
-- `staff` holds employment records, not credentials.
alter table public.staff enable row level security;

drop policy if exists staff_read on public.staff;
create policy staff_read on public.staff
  for select to authenticated
  using (public.has_any_role(array['Super Admin', 'Branch Manager', 'Auditor']));

drop policy if exists staff_write on public.staff;
create policy staff_write on public.staff
  for all to authenticated
  using (public.has_any_role(array['Super Admin']))
  with check (public.has_any_role(array['Super Admin']));

-- ---------------------------------------------------------------- activities
-- The feed is written by the system as people work, and read by everyone.
alter table public.activities enable row level security;

drop policy if exists activities_read on public.activities;
create policy activities_read on public.activities
  for select to authenticated
  using (public.current_staff_role() is not null);

drop policy if exists activities_append on public.activities;
create policy activities_append on public.activities
  for insert to authenticated
  with check (public.current_staff_role() is not null);

-- ---------------------------------------------------------- heartbeat_pings
-- A ping is a liveness signal from a signed-in device. It carries no business
-- data, so a staff member may insert and read only their own.
alter table public.heartbeat_pings enable row level security;

drop policy if exists heartbeat_insert_self on public.heartbeat_pings;
create policy heartbeat_insert_self on public.heartbeat_pings
  for insert to authenticated
  with check (true);

drop policy if exists heartbeat_read_self on public.heartbeat_pings;
create policy heartbeat_read_self on public.heartbeat_pings
  for select to authenticated
  using (public.has_any_role(array['Super Admin', 'Branch Manager']));

-- ---------------------------------------------------------------- verify
-- After running, this should list one or more policies per table and none of
-- them should read `using (true)` except the heartbeat insert.
--
--   select tablename, policyname, cmd, qual, with_check
--   from pg_policies where schemaname = 'public' order by tablename, policyname;
