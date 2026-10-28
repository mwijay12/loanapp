-- P2 — petty_cash was readable and writable by ANONYMOUS callers.
--
-- Live proof, taken before this file was written: a request carrying only the
-- publishable key (the one compiled into the web bundle, no login) returned
--   GET /rest/v1/petty_cash?select=amount,category  -> 200, content-range: 0-0/*
-- with a real row (25000 / Stationery / Mbagala). The same query on `loans`
-- returns content-range: */*, which is why this was not a general RLS outage —
-- 2026_10_24_01_petty_cash.sql created two policies addressed to `public`:
--   "Allow anon insert to petty_cash"   FOR INSERT WITH CHECK (true)
--   "Allow public select from petty_cash" FOR SELECT USING (true)
-- They were scaffolding for a demo build and were never removed.
--
-- Why DROP + CREATE and not just tightening: a policy addressed to `public`
-- covers `authenticated` as well, so dropping it without a replacement takes
-- the cash screen down for real staff too (2026_10_22_02_drop_public_policies.sql
-- is the earlier example of that failure mode). Both halves are therefore
-- replaced in the same transaction.
--
-- Deliberately absent: UPDATE and DELETE policies. A cash line is corrected by
-- writing another line, not by editing history. This is also what makes the
-- table usable as evidence.
--
-- Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

drop policy if exists "Allow anon insert to petty_cash" on public.petty_cash;
drop policy if exists "Allow public select from petty_cash" on public.petty_cash;
drop policy if exists petty_cash_read on public.petty_cash;
drop policy if exists petty_cash_append on public.petty_cash;

create policy petty_cash_read on public.petty_cash
  for select to authenticated
  using (public.current_staff_role() is not null);

create policy petty_cash_append on public.petty_cash
  for insert to authenticated
  with check (public.current_staff_role() is not null);

-- ------------------------------------------------------------------ attribution
-- The live row that leaked carried staff_id = 'noSession'. That string comes
-- from the client, so the cash ledger could never say who actually touched the
-- drawer. The insert now takes its attribution from the JWT, and the client's
-- copy is only trusted when there is no session (a migration or a seed run by
-- the database owner, where auth.uid() is null).
--
-- branch_id stays TEXT with a branch NAME inside (existing rows say 'Mbagala'),
-- so it is filled from profiles.branch_name rather than branches.id. When the
-- session's profile has a branch, that value wins over whatever the client sent:
-- a drawer movement recorded at Mbagala must not be typed as Kariakao from the
-- till. A profile without a branch keeps the client value rather than losing it.
create or replace function public.stamp_petty_cash_author()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_branch text;
begin
  if auth.uid() is not null then
    new.staff_id := auth.uid()::text;
    select p.branch_name into v_branch
    from public.profiles p
    where p.auth_user_id = auth.uid()
    limit 1;
    if v_branch is not null then
      new.branch_id := v_branch;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists petty_cash_stamp_author on public.petty_cash;
create trigger petty_cash_stamp_author
  before insert on public.petty_cash
  for each row execute function public.stamp_petty_cash_author();

commit;

-- Verification: nobody anonymous should appear in the role list any more, and
-- every statement should be `to authenticated`.
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = 'petty_cash'
order by cmd;
