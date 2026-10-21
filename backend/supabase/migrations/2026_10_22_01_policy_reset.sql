-- Remove the leftover permissive policies.
--
-- Verified on 22 Oct 2026 with the publishable key, i.e. as an anonymous caller:
--
--   GET  /rest/v1/profiles  -> 200 with email and role        (should be empty)
--   GET  /rest/v1/loans     -> 200 with rows                  (should be empty)
--   POST /rest/v1/heartbeat_pings -> 201 created              (should be 401)
--   POST /rest/v1/loan_payments   -> 401 / 42501              (correct)
--
-- So RLS is switched on and the new policies do work — loan_payments refuses an
-- anonymous insert exactly as intended. The older tables still carry policies
-- created before this work, and Postgres ORs policies together: one permissive
-- policy makes every restrictive one beside it irrelevant.
--
-- This drops every policy on the affected tables, whatever it is called, so the
-- next run of 2026_10_20_01_rls_policies.sql is the only thing defining access.
--
-- ORDER: run this, then run 2026_10_20_01_rls_policies.sql again.
-- Between the two the tables deny everything, which is the safe direction.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

-- What is there now, before it goes. Keep this output.
select tablename, policyname, roles::text, cmd
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

do $$
declare
  r record;
begin
  for r in
    select tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('profiles', 'products', 'loans', 'branches', 'activities',
                        'staff', 'product_history', 'heartbeat_pings',
                        'sales', 'loan_payments')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- Belt and braces: make sure RLS is actually on for each table. A table with RLS
-- off ignores policies entirely, which is another way the hole can exist.
alter table public.profiles        enable row level security;
alter table public.products        enable row level security;
alter table public.loans           enable row level security;
alter table public.branches        enable row level security;
alter table public.activities      enable row level security;
alter table public.staff           enable row level security;
alter table public.product_history enable row level security;
alter table public.heartbeat_pings enable row level security;

commit;

-- Should be empty. Then run 01 to install the real policies.
select tablename, policyname from pg_policies where schemaname = 'public';
