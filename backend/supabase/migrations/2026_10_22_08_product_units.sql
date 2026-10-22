-- Serial numbers for handsets, and the deliveries they arrived on.
--
-- Until now a product row carried a quantity: "iPhone 15 Pro Max, stock 10". That
-- answers "how many" and nothing else. A Tanzanian phone shop is asked the other
-- question constantly - which handset is this, is it under warranty, was it the one
-- reported stolen, which delivery did it come on - and the answer is an IMEI.
--
-- Three tables:
--   stock_receipts       one row per delivery (supplier, transfer or return)
--   stock_receipt_lines  what arrived on it, per model
--   product_units        one row per physical handset, keyed by IMEI
--
-- Run in the Supabase SQL editor. Safe to run twice.
--
-- To undo:
--   drop table if exists public.product_units;
--   drop table if exists public.stock_receipt_lines;
--   drop table if exists public.stock_receipts;

-- ---------------------------------------------------------------- deliveries
create table if not exists public.stock_receipts (
  id            bigint generated always as identity primary key,
  branch        text not null,
  source        text not null check (source in ('supplier', 'transfer', 'return')),
  supplier_name text,
  invoice_no    text,
  from_branch   text,
  units         int  not null default 0,
  note          text,
  received_by   text,
  received_at   timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create index if not exists stock_receipts_branch_time_idx
  on public.stock_receipts (branch, received_at desc);

create table if not exists public.stock_receipt_lines (
  id         bigint generated always as identity primary key,
  receipt_id bigint not null references public.stock_receipts(id) on delete cascade,
  product_id bigint,
  sku        text,
  name       text not null,
  qty        int  not null check (qty > 0),
  unit_cost  numeric(14, 2) not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists stock_receipt_lines_receipt_idx
  on public.stock_receipt_lines (receipt_id);

-- ------------------------------------------------------------------- handsets
create table if not exists public.product_units (
  id          bigint generated always as identity primary key,
  imei        text not null unique,
  imei2       text,
  serial      text,
  product_id  bigint,
  sku         text,
  model       text,
  branch      text,
  receipt_id  bigint references public.stock_receipts(id) on delete set null,
  status      text not null default 'in_stock'
              check (status in ('in_stock', 'sold', 'on_loan', 'returned', 'lost')),
  loan_id     bigint,
  sale_id     bigint,
  received_at timestamptz not null default now(),
  sold_at     timestamptz,
  updated_at  timestamptz not null default now()
);

create index if not exists product_units_branch_status_idx
  on public.product_units (branch, status);

create index if not exists product_units_product_idx
  on public.product_units (product_id);

-- A serial is fifteen digits; anything else is a scanning mistake or a wrong label.
alter table public.product_units
  drop constraint if exists product_units_imei_len;
alter table public.product_units
  add constraint product_units_imei_len check (char_length(imei) = 15);

-- ------------------------------------------------------------------------ RLS
alter table public.stock_receipts      enable row level security;
alter table public.stock_receipt_lines enable row level security;
alter table public.product_units       enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['stock_receipts', 'stock_receipt_lines', 'product_units']
  loop
    execute format('drop policy if exists %I_read on public.%I', t, t);
    execute format(
      'create policy %I_read on public.%I for select to authenticated using (true)',
      t, t);

    execute format('drop policy if exists %I_write on public.%I', t, t);
    execute format(
      'create policy %I_write on public.%I for insert to authenticated with check (true)',
      t, t);

    execute format('drop policy if exists %I_update on public.%I', t, t);
    execute format(
      'create policy %I_update on public.%I for update to authenticated using (true)',
      t, t);
  end loop;
end $$;

-- Anon keeps no access: these rows describe physical property and its owners.

-- ------------------------------------------------------------------- checks
-- select count(*) filter (where status = 'in_stock') as in_stock,
--        count(*) filter (where status = 'on_loan') as on_loan
-- from public.product_units;
