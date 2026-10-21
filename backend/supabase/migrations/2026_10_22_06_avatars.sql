-- Give each person their own portrait.
--
-- The seed screenshots showed "Peter Msechu" beside a woman's photograph. Two
-- separate faults produced that:
--
--   1. Portraits were chosen by role. Every Storekeeper got the same picture, so
--      a person's face carried no identity.
--   2. The header picked the first staff row matching the role, so a male
--      storekeeper was greeted with the female store manager's name as well.
--
-- Fix 2 is in the app (signedInNameProvider). Fix 1 needs a per-person column,
-- and the portraits below are picked to match each name's gender and age.
--
-- When real staff join, set avatar_asset to their own photo path and the fallback
-- never runs. Anything left null still renders the role portrait, then initials.
--
-- Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

alter table public.staff
  add column if not exists avatar_asset text;
alter table public.profiles
  add column if not exists avatar_asset text;
alter table public.loans
  add column if not exists avatar_asset text;

update public.staff set avatar_asset = case name
  when 'Neema Julius' then 'assets/images/avatar_manager.png'
  when 'Baraka Mushi' then 'assets/images/avatar_person_m30.png'
  when 'Amina Komba'  then 'assets/images/avatar_cashier.png'
  when 'Peter Msechu' then 'assets/images/avatar_store.png'
  when 'Zawadi Nnaji' then 'assets/images/avatar_person_f20.png'
  else avatar_asset end
where name in ('Neema Julius','Baraka Mushi','Amina Komba','Peter Msechu','Zawadi Nnaji');

update public.loans set avatar_asset = case borrower_name
  when 'John Mwalimu' then 'assets/images/avatar_loan.png'
  when 'Amina Komba'  then 'assets/images/avatar_cashier.png'
  when 'Peter Msechu' then 'assets/images/avatar_store.png'
  when 'Neema Lyimo'  then 'assets/images/avatar_person_f40.png'
  when 'Baraka Mushi' then 'assets/images/avatar_person_m30.png'
  else avatar_asset end
where borrower_name in ('John Mwalimu','Amina Komba','Peter Msechu','Neema Lyimo','Baraka Mushi');

update public.profiles set avatar_asset = case email
  when 'demo.admin@example.com'   then 'assets/images/avatar_admin.png'
  when 'demo.manager@example.com' then 'assets/images/avatar_manager.png'
  when 'demo.loan@example.com'    then 'assets/images/avatar_loan.png'
  when 'demo.store@example.com'   then 'assets/images/avatar_store.png'
  when 'demo.cashier@example.com' then 'assets/images/avatar_cashier.png'
  when 'demo.audit@example.com'   then 'assets/images/avatar_auditor.png'
  when 'admin@lims.co.tz'         then 'assets/images/avatar_admin.png'
  else avatar_asset end
where email like '%@example.com' or email = 'admin@lims.co.tz';

commit;

select name, role, avatar_asset from public.staff order by name;
select borrower_name, avatar_asset from public.loans order by id;
select email, avatar_asset from public.profiles order by email;
