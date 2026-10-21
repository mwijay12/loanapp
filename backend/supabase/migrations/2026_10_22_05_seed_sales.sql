-- Give the sales ledger some history so "Today's Sales" means something.
--
-- The home card used to sum `products.sold_today`, a column that only changes when
-- a row is edited by hand — which is why it read 66,006,000 for days. It now reads
-- `public.sales`, and an empty ledger would show zero.
--
-- This writes fourteen days of demo takings, three sales a day, with the receipt
-- numbers marked DEMO- so the whole set can be removed in one statement when the
-- real shop starts trading:
--
--   delete from public.sales where receipt_no like 'DEMO-%';
--
-- Amounts are derived from the day number, so the figures differ day to day and
-- the chart has a shape rather than a flat line.
--
-- Safe to run twice: existing DEMO receipts are skipped.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

with days as (
  select generate_series(0, 13) as d
),
per_day as (
  select d, s as slot
  from days, generate_series(1, 3) as s
),
rows as (
  select
    d,
    slot,
    (current_date - d) + time '09:30' + (slot * interval '2 hours') as sold_at,
    450000 + (d * 37000) + (slot * 61000) as total
  from per_day
)
insert into public.sales (
  receipt_no, branch_id, product_id, customer_name, customer_phone,
  kind, total, paid, balance, payment_channel, sold_at
)
select
  'DEMO-' || to_char(r.sold_at, 'YYYYMMDD') || '-' || lpad(r.slot::text, 2, '0'),
  (select id from public.branches order by name limit 1),
  (select id from public.products where category = 'phones' order by id limit 1),
  'Demo customer ' || r.slot,
  '+2557000000' || r.slot,
  'cash',
  r.total,
  r.total,
  0,
  'cash',
  r.sold_at
from rows r
where not exists (
  select 1 from public.sales s
  where s.receipt_no =
        'DEMO-' || to_char(r.sold_at, 'YYYYMMDD') || '-' || lpad(r.slot::text, 2, '0')
);

commit;

select count(*) as demo_sales,
       sum(paid) filter (where sold_at::date = current_date) as today_total,
       count(*) filter (where sold_at::date = current_date) as today_count
from public.sales
where receipt_no like 'DEMO-%';
