-- Gives every loan a due date, so ageing is arithmetic instead of a sentence.
--
-- `due_info` held text: some rows a date ("2026-10-29"), the rest a note
-- ("Due in 6 days", "Overdue 5 days"). A note never changes, so a loan written
-- three weeks ago still claimed six days until payment. Nothing on the reports
-- could be aged, which is why "PAR 30" counted every overdue account.
--
-- Safe to run twice: every statement is guarded.

alter table public.loans add column if not exists due_date date;

comment on column public.loans.due_date is
  'Next instalment due. due_info is the free-text note this was backfilled from.';

-- 1. Rows that already carried a date.
update public.loans
   set due_date = due_info::date
 where due_date is null
   and due_info ~ '^\d{4}-\d{2}-\d{2}$';

-- 2. Rows that carried an offset. Anchored to the day the migration runs: the
--    note was written relative to an unknown original date, so today is the only
--    anchor that keeps the demo coherent. Re-check these against the signed
--    agreements before the figures are used for lending.
update public.loans
   set due_date = current_date + (substring(due_info from '(\d+)'))::int
 where due_date is null
   and due_info ~* '^Due in \d+ days?$';

update public.loans
   set due_date = current_date - (substring(due_info from '(\d+)'))::int
 where due_date is null
   and due_info ~* '^Overdue \d+ days?$';

-- 3. Status follows the date it now has.
update public.loans
   set status = case when due_date < current_date then 'overdue' else 'current' end
 where due_date is not null
   and status in ('current', 'overdue');

-- Verify: the two buckets must add up to the whole book.
-- select status, count(*), sum(amount) from public.loans group by status;
