-- Demo borrowers, so the loans screen and the notifications feed have something
-- real to show.
--
-- The shop asked for demo data after the empty screen: a branch with no contracts
-- looks broken, and the "overdue loans" notice could never fire because there was
-- nothing to be overdue. These rows are demo rows and are marked as such:
--
--   delete from public.loans where loan_no like 'DEMO-%';
--
-- Each borrower below appears in the demo staff/loan fixtures already used on the
-- login screen, so the names match what people have seen. Nothing here is a real
-- person's contract: the NIDA values are structurally valid but not issued, and
-- the phone numbers are in the reserved 0754 range used elsewhere in the demo.
--
-- Safe to run twice: rows are inserted only when the loan_no is absent.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- `loan_no` may not exist on older databases; add it before using it as the key.
alter table public.loans
  add column if not exists loan_no text;

create unique index if not exists loans_loan_no_key
  on public.loans (loan_no) where loan_no is not null;

with branch as (
  select id from public.branches order by name limit 1
),
seed as (
  select * from (values
    ('DEMO-LN-1001', 'Peter Msechu',        'Tecno Camon 30',       2400000, 35, 'current', '2026-11-02', '358920112849101'),
    ('DEMO-LN-1002', 'Neema Lyimo',         'Samsung Galaxy A55',   1850000, 60, 'current', '2026-10-29', '864920042819387'),
    ('DEMO-LN-1003', 'John Mwalimu',        'itel Vision 3 Plus',    750000, 25, 'overdue', '2026-10-10', '351982746201940'),
    ('DEMO-LN-1004', 'Amina Komba',         'Redmi Note 13 Pro',    1450000, 45, 'overdue', '2026-10-14', '354928104829100'),
    ('DEMO-LN-1005', 'Zawadi Nnaji',        'iPhone 15 Pro Max',    4450000, 30, 'current', '2026-11-08', '358920112849101'),
    ('DEMO-LN-1006', 'Baraka Mushi',        'Galaxy S24 Ultra',     3350000, 70, 'current', '2026-10-31', '351982746201940')
  ) as v(loan_no, borrower_name, item_name, amount, paid_percent, status, due_info, imei)
)
insert into public.loans (
  loan_no, borrower_name, item_name, amount, paid_percent, status, due_info,
  imei, phone, nida, location, deposit, weekly_installment, installment_weeks,
  guarantor_name, guarantor_phone, branch_id
)
select
  s.loan_no,
  s.borrower_name,
  s.item_name,
  s.amount,
  s.paid_percent,
  s.status,
  s.due_info,
  s.imei,
  '0754 ' || lpad(((row_number() over ()) * 137)::text, 3, '0') || ' ' || lpad(((row_number() over ()) * 251)::text, 3, '0'),
  '1990' || lpad(((row_number() over ()) * 11)::text, 2, '0') || '15-' || lpad(((row_number() over ()) * 7)::text, 5, '0') || '-00001-24',
  'Kariakoo, Dar es Salaam',
  round(s.amount * 0.25),
  round((s.amount * 0.75) / 8),
  8,
  'Guarantor for ' || split_part(s.borrower_name, ' ', 1),
  '0713 000 ' || lpad(((row_number() over ()) * 31)::text, 3, '0'),
  (select id from branch)
from seed s
where not exists (
  select 1 from public.loans l where l.loan_no = s.loan_no
);

commit;

-- What to expect:
--   select loan_no, borrower_name, item_name, status
--   from public.loans order by loan_no;
--
-- Two of the six (John Mwalimu, Amina Komba) are 'overdue' on purpose: without
-- them the notifications screen has nothing to report and the collections queue
-- looks like a feature that never worked.
