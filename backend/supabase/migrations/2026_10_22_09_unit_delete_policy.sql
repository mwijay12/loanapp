-- Remove a serial that was entered by mistake.
--
-- Verifying the new register exposed a gap: `product_units` had select, insert
-- and update policies but no delete policy. A DELETE therefore matched zero rows
-- and still returned 204, so a mistyped IMEI could never be removed and nobody
-- would see an error. That is how a test row survived its own cleanup.
--
-- Delete is deliberately narrow. A serial can only be deleted while it is still
-- in stock and has never been attached to a loan or a sale; once a handset has
-- left the shelf its row is part of the audit trail and must stay. Corrections
-- after that point belong in a status change ('returned', 'lost'), not a delete.
--
-- Run in the Supabase SQL editor. Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

drop policy if exists product_units_delete on public.product_units;
create policy product_units_delete on public.product_units
  for delete to authenticated
  using (status = 'in_stock' and loan_id is null and sale_id is null);

drop policy if exists stock_receipt_lines_delete on public.stock_receipt_lines;
create policy stock_receipt_lines_delete on public.stock_receipt_lines
  for delete to authenticated using (true);

drop policy if exists stock_receipts_delete on public.stock_receipts;
create policy stock_receipts_delete on public.stock_receipts
  for delete to authenticated using (true);

-- Remove the row created while checking that insert/read worked. It was written
-- under the old policy set, which is why the delete in that check did nothing.
delete from public.product_units
where imei = '356938035643809' and model = 'RLS probe';

commit;

-- Expect zero: the probe row must be gone.
select count(*) as probe_rows_left
from public.product_units
where model = 'RLS probe';

-- Expect: one row per delivered handset.
select status, count(*) from public.product_units group by status;
