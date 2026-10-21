-- Make the database able to hold a real sale.
--
-- Found by querying the live project (fzlykkwgkydswvnlryhk) with the publishable
-- key on 20 Oct 2026. Three problems, in order of how much they hurt:
--
-- 1. Money is text. `products.price` reads '3,850,000' and `loans.amount` reads
--    '2,400,000'. You cannot sum a formatted string, a locale change breaks the
--    parse, and sorting by price is alphabetical. Every total in the app is
--    therefore computed from mock values, never from the database.
--
-- 2. A loan cannot record what was sold. `loans` has borrower_name, item_name,
--    amount, paid_percent, due_info, status. There is no IMEI, no phone, no
--    deposit, no instalment, no guarantor — so the receipt the app prints cannot
--    be reconstructed from the database.
--
-- 3. There is no `sales` or `loan_payments` table. A payment has nowhere to go,
--    which is why the ledger behind the chart is generated in Dart.
--
-- Run inside a transaction and inspect before committing:
--   begin;  \i this_file.sql  ...  commit;  (or rollback;)
--
-- This migration rewrites money columns from text to numeric. It strips commas
-- and the 'TZS' prefix first. Take a backup before running it on data you care
-- about; the casts are one-way.

-- ---------------------------------------------------------------- products
alter table public.products
  add column if not exists brand text,
  add column if not exists imei1 text,
  add column if not exists imei2 text,
  add column if not exists cost_price numeric(14,2),
  add column if not exists loan_price numeric(14,2),
  add column if not exists image_asset text,
  add column if not exists image_url text;

-- strip formatting, then cast; the regex keeps digits, dot and minus only
update public.products
set price = regexp_replace(price::text, '[^0-9.\-]', '', 'g')
where price::text ~ '[^0-9.\-]';

alter table public.products
  alter column price type numeric(14,2) using nullif(price::text, '')::numeric;

-- one IMEI per physical handset, when the row represents a single device
create unique index if not exists products_imei1_key
  on public.products (imei1) where imei1 is not null;

-- ---------------------------------------------------------------- branches
-- Do NOT strip `sales`. 'TZS 4.85M' would become 4.85, which is a different
-- number, and the loss is silent. The column stays as display text; the numeric
-- value lives in `sales_today` below.

-- 'TZS 4.85M' becomes 4.85 after the strip, which is not the same number.
-- Keep the original text until someone confirms the intended value, and add a
-- numeric column that the app can write to.
alter table public.branches
  add column if not exists sales_today numeric(14,2) default 0;

-- ---------------------------------------------------------------- loans
alter table public.loans
  add column if not exists phone text,
  add column if not exists nida text,
  add column if not exists location text,
  add column if not exists business_address text,
  add column if not exists imei text,
  add column if not exists deposit numeric(14,2) default 0,
  add column if not exists weekly_installment numeric(14,2) default 0,
  add column if not exists installment_weeks int default 8,
  add column if not exists guarantor_name text,
  add column if not exists guarantor_phone text,
  add column if not exists guarantor_relation text,
  add column if not exists branch_id uuid references public.branches(id),
  add column if not exists staff_id uuid references public.profiles(id);

update public.loans
set amount = regexp_replace(amount::text, '[^0-9.\-]', '', 'g')
where amount::text ~ '[^0-9.\-]';

alter table public.loans
  alter column amount type numeric(14,2) using nullif(amount::text, '')::numeric;

-- ---------------------------------------------------------------- sales
-- The ledger the chart needs, and the record a receipt is printed from.
create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  receipt_no text unique not null,
  branch_id uuid references public.branches(id),
  staff_id uuid references public.profiles(id),
  loan_id int references public.loans(id),   -- loans.id is int in the live project
  product_id int references public.products(id),
  imei text,
  customer_name text,
  customer_phone text,
  kind text not null default 'cash',      -- 'cash' | 'loan'
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

-- ---------------------------------------------------------- loan_payments
create table if not exists public.loan_payments (
  id uuid primary key default gen_random_uuid(),
  loan_id int not null references public.loans(id) on delete cascade,
  amount numeric(14,2) not null,
  paid_at timestamptz not null default now(),
  channel text,
  reference text,
  recorded_by uuid references public.profiles(id)
);

create index if not exists loan_payments_loan_idx on public.loan_payments (loan_id, paid_at desc);

alter table public.loan_payments enable row level security;

drop policy if exists loan_payments_read on public.loan_payments;
create policy loan_payments_read on public.loan_payments
  for select to authenticated
  using (public.has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer', 'Counter Cashier', 'Auditor']));

drop policy if exists loan_payments_create on public.loan_payments;
create policy loan_payments_create on public.loan_payments
  for insert to authenticated
  with check (public.has_any_role(array['Super Admin', 'Branch Manager', 'Loan Officer', 'Counter Cashier']));

-- ---------------------------------------------------------------- profiles
-- `password_hash` held what looks like a plaintext password ('demo1234') and was
-- readable with the publishable key, which ships inside the web bundle. Auth is
-- handled by Supabase Auth now, so the column has no purpose.
-- Null it first, then drop it once you have confirmed no code reads it.
update public.profiles set password_hash = null where password_hash is not null;

alter table public.profiles
  drop column if exists password_hash;

-- ---------------------------------------------------------------- verify
--   select column_name, data_type from information_schema.columns
--   where table_schema='public' and table_name in ('products','loans','sales')
--   order by table_name, ordinal_position;
