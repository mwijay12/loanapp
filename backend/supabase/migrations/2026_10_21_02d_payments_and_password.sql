-- Step 4 of 4 — payments, and removing the exposed password column.
--
-- `profiles.password_hash` held 'demo1234' and was readable with the publishable
-- key, which ships inside the web bundle. Auth goes through Supabase Auth, so the
-- column has no purpose. Nulled first so the drop is not a surprise.
--
-- Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

create table if not exists public.loan_payments (
  id uuid primary key default gen_random_uuid(),
  loan_id int not null references public.loans(id) on delete cascade,
  amount numeric(14,2) not null,
  paid_at timestamptz not null default now(),
  channel text,
  reference text,
  recorded_by uuid references public.profiles(id)
);

create index if not exists loan_payments_loan_idx
  on public.loan_payments (loan_id, paid_at desc);

alter table public.loan_payments enable row level security;

drop policy if exists loan_payments_read on public.loan_payments;
create policy loan_payments_read on public.loan_payments
  for select to authenticated
  using (public.has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer', 'Counter Cashier', 'Auditor']));

drop policy if exists loan_payments_create on public.loan_payments;
create policy loan_payments_create on public.loan_payments
  for insert to authenticated
  with check (public.has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer', 'Counter Cashier']));

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
      and column_name = 'password_hash'
  ) then
    update public.profiles set password_hash = null where password_hash is not null;
    alter table public.profiles drop column password_hash;
  end if;
end $$;

commit;

select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and ((table_name = 'loan_payments')
       or (table_name = 'profiles' and column_name = 'password_hash'))
order by table_name, ordinal_position;
