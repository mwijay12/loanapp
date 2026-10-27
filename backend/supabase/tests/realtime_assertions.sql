-- ============================================================================
-- realtime_assertions.sql — run this after 2026_10_27_01_realtime.sql.
--
-- It raises an exception on the first broken rule, so it can be wired into CI or
-- run by hand in the SQL editor. It reads nothing but catalog views and rows are
-- never touched.
--
--   psql "$DB_URL" -f backend/supabase/tests/realtime_assertions.sql
-- ============================================================================

-- 1. The tables the app subscribes to must actually be published. A missing one
--    is the exact bug this migration fixes, so it is asserted, not assumed.
do $$
declare
  missing text;
  wanted text[] := array[
    'sales','products','loans','staff','branches','activities',
    'product_units','stock_receipts','stock_receipt_lines'
  ];
begin
  select string_agg(t, ', ') into missing
  from unnest(wanted) as t
  where not exists (
    select 1 from pg_publication_tables pt
    where pt.pubname = 'supabase_realtime' and pt.tablename = t
  );
  if missing is not null then
    raise exception 'ASSERT 1 FAILED: not published to supabase_realtime: %', missing;
  end if;
  raise notice 'ASSERT 1 ok: all 9 tables are published';
end
$$;

-- 2. Nothing broadcast to an anonymous websocket. Realtime applies RLS per
--    subscriber, so a published table whose SELECT policy admits `anon`/`public`
--    with `using (true)` leaks its rows to any browser holding the publishable
--    key. petty_cash has exactly that policy today, which is why it is not
--    published; this assertion catches it if someone adds it back.
do $$
declare
  leaked text;
begin
  select string_agg(x, ', ') into leaked from (
    select distinct pt.tablename || ' (' || p.policyname || ')' as x
    from pg_publication_tables pt
    join pg_policies p
      on p.tablename = pt.tablename
     and p.cmd = 'SELECT'
    join pg_roles r on r.rolname = any(p.roles)
    where pt.pubname = 'supabase_realtime'
      and r.rolname in ('anon', 'public')
      and p.qual is distinct from null
  ) s;
  if leaked is not null then
    raise exception
      'ASSERT 2 FAILED: published table reachable without a login: %',
      leaked;
  end if;
  raise notice 'ASSERT 2 ok: no published table is readable by anon/public';
end
$$;

-- 3. Every published table needs a replica identity that lets a DELETE be
--    identified: a primary key (DEFAULT), or FULL. Without one the client gets a
--    delete event with no key and can only guess, which is how a row comes back
--    after being removed.
do $$
declare
  bad text;
begin
  select string_agg(distinct pt.tablename, ', ') into bad
  from pg_publication_tables pt
  join pg_class c on c.relname = pt.tablename
  where pt.pubname = 'supabase_realtime'
    and c.relreplident not in ('d', 'f', 'p')
    and not exists (
      select 1 from pg_index i where i.indrelid = c.oid and i.indisprimary
    );
  if bad is not null then
    raise exception 'ASSERT 3 FAILED: published tables with no usable replica identity: %', bad;
  end if;
  raise notice 'ASSERT 3 ok: every published table can identify a deleted row';
end
$$;

-- 4. petty_cash and profiles must stay out until their policies are reworked
--    (remediation plan P2). This is a reminder with teeth, not a suggestion.
do $$
declare
  forbidden text;
begin
  select string_agg(pt.tablename, ', ') into forbidden
  from pg_publication_tables pt
  where pt.pubname = 'supabase_realtime'
    and pt.tablename in ('petty_cash', 'profiles');
  if forbidden is not null then
    raise exception
      'ASSERT 4 FAILED: % is published, but its SELECT policy has not been closed yet (see P2).',
      forbidden;
  end if;
  raise notice 'ASSERT 4 ok: petty_cash and profiles are still excluded';
end
$$;

select 'realtime_assertions: all checks passed' as result;
