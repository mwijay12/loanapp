-- Step 2 of 4 — the columns a loan needs in order to describe what was sold.
--
-- Today `loans` holds borrower_name, item_name, amount, paid_percent, due_info,
-- status. That is not enough to reprint a receipt: no IMEI, no customer phone, no
-- deposit, no instalment amount, no guarantor. Run after 02a (needs branches).
--
-- Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

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

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'loans'
      and column_name = 'amount' and data_type = 'text'
  ) then
    update public.loans
    set amount = regexp_replace(amount, '[^0-9.\-]', '', 'g')
    where amount ~ '[^0-9.\-]';

    alter table public.loans
      alter column amount type numeric(14,2) using nullif(amount, '')::numeric;
  end if;
end $$;

commit;

select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'loans'
  and column_name in ('amount', 'imei', 'deposit', 'weekly_installment',
                      'installment_weeks', 'guarantor_name', 'branch_id')
order by column_name;
