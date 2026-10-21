-- Step 3 of 4 — the sales ledger.
--
-- This is the table the counter writes once per sale, and the one the revenue
-- chart should read instead of the generated Dart ledger.
--
-- `loan_id` is int because public.loans.id is int. The earlier version declared
-- uuid references loans(id), which Postgres rejects outright: "Key columns are of
-- incompatible types: uuid and integer". That single mismatch is what aborted the
-- whole migration on 20 Oct.
--
-- Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  receipt_no text unique not null,
  branch_id uuid references public.branches(id),
  staff_id uuid references public.profiles(id),
  loan_id int references public.loans(id),
  product_id int references public.products(id),
  imei text,
  customer_name text,
  customer_phone text,
  kind text not null default 'cash',       -- 'cash' | 'loan'
  total numeric(14,2) not null default 0,
  paid numeric(14,2) not null default 0,
  balance numeric(14,2) not null default 0,
  payment_channel text,
  sold_at timestamptz not null default now()
);

create index if not exists sales_sold_at_idx on public.sales (sold_at desc);
create index if not exists sales_branch_idx on public.sales (branch_id, sold_at desc);

alter table public.sales enable row level security;

drop policy if exists sales_read on public.sales;
create policy sales_read on public.sales
  for select to authenticated
  using (public.has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer', 'Counter Cashier', 'Auditor']));

drop policy if exists sales_create on public.sales;
create policy sales_create on public.sales
  for insert to authenticated
  with check (public.has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer', 'Counter Cashier']));

commit;

select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'sales'
order by ordinal_position;
