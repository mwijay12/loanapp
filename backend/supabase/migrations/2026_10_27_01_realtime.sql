-- ============================================================================
-- 2026_10_27_01_realtime.sql — put the shop's live tables into the Realtime
-- publication so a sale written at one branch reaches the other screens.
--
-- WHY THIS FILE EXISTS
-- The app read its rows once, at launch, and never again: LiveDataLoader called
-- `_load()` from initState behind an `if (_started) return;` guard, and no file in
-- lib/ contained a `.stream()` or an `onPostgresChanges` subscription. On the
-- server side the same gap was visible: the `supabase_realtime` publication
-- existed but held zero tables (`pg_publication_tables` was empty), so even a
-- subscribing client would have been told nothing. A Branch Manager who sold a
-- handset on their phone left the admin's PC showing yesterday's ledger.
--
-- Prerequisites were already true on this project, so nothing else is changed:
--   * `wal_level = logical`          (verified: pg_settings)
--   * every table below has a single-column `id` primary key
--   * every table below is `REPLICA IDENTITY DEFAULT` (relreplident = 'd'), which
--     sends the whole new record on INSERT/UPDATE and the key on DELETE.
--     REPLICA IDENTITY FULL was deliberately NOT set: it duplicates every column
--     into the WAL for every update, and the keys are already sufficient here.
--
-- WHAT DELIBERATELY IS NOT PUBLISHED
--   * petty_cash — its only SELECT policy is
--       "Allow public select from petty_cash" ... to public using (true)
--     and Realtime applies RLS per subscriber. Publishing it would stream the
--     shop's cash expenses to any browser that opens a websocket with the
--     publishable key, with no login at all. Fix that policy first (remediation
--     plan P2); only then belongs this table here.
--   * profiles — RLS is `auth_user_id = auth.uid()` per person, and the rows hold
--     staff identities. Nothing on screen needs a live push of them.
--   * loan_payments, product_history, heartbeat_pings — no code in lib/ reads
--     them yet (`grep "from('loan_payments')"` -> 0 hits), so a subscription
--     would only add decode work for a client that throws the row away.
--     Add them here when the app actually displays them.
--
-- Every table that IS published has a PERMISSIVE SELECT policy for the
-- `authenticated` role (activities_read, branches_read, loans_read,
-- product_units_read, products_read, sales_read, staff_read,
-- stock_receipts_read, stock_receipt_lines_read). That is what lets a signed-in
-- device receive its rows; an anonymous socket still receives nothing.
--
-- ROLLBACK (removes the membership, touches no rows):
--   alter publication supabase_realtime drop table
--     public.sales, public.products, public.loans, public.staff,
--     public.branches, public.activities, public.product_units,
--     public.stock_receipts, public.stock_receipt_lines;
-- ============================================================================

-- The publication is created by Supabase itself; the guard is for a fresh local
-- database where it is not.
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end
$$;

-- `alter publication ... add table` has no IF NOT EXISTS, and this migration has
-- to survive being replayed on a project that already has some of the tables.
do $$
declare
  t text;
  wanted text[] := array[
    'sales',
    'products',
    'loans',
    'staff',
    'branches',
    'activities',
    'product_units',
    'stock_receipts',
    'stock_receipt_lines'
  ];
begin
  foreach t in array wanted loop
    if not exists (
      select 1
      from pg_publication_tables pt
      where pt.pubname = 'supabase_realtime'
        and pt.tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
      raise notice 'realtime: published public.%', t;
    else
      raise notice 'realtime: public.% was already published', t;
    end if;
  end loop;
end
$$;

-- Print what the publication ended up holding, so whoever runs this in the
-- dashboard can see the answer instead of trusting the notice above.
select c.relname as published, c.relreplident as replica_identity
from pg_publication_tables pt
join pg_class c on c.relname = pt.tablename
where pt.pubname = 'supabase_realtime'
order by c.relname;

-- The tables that must never appear here, checked in the same place they are
-- excluded from, so a future edit cannot forget the reason.
do $$
declare
  leaked text;
begin
  select string_agg(pt.tablename, ', ') into leaked
  from pg_publication_tables pt
  where pt.pubname = 'supabase_realtime'
    and pt.tablename in ('petty_cash', 'profiles');
  if leaked is not null then
    raise exception
      'realtime: % is published while its SELECT policy is still open to anon / self-scoped. Drop it from the publication.',
      leaked;
  end if;
end
$$;
