-- ============================================================================
-- realtime_publication_refresh.sql — repair a Realtime feed that is subscribed
-- but silent.
--
-- WHEN TO RUN IT
--   A device subscribes, the channel reports `subscribed`, the pill reads `Live`,
--   and no row ever changes on screen. Confirmed on this project on 2026-10-31.
--
-- WHAT THE SYMPTOM LOOKED LIKE FROM THE INSIDE
--   * pg_publication had `supabase_realtime`, with all 9 wanted tables in
--     pg_publication_tables — so tests/realtime_assertions.sql passed, and that is
--     the trap: catalog membership does not prove delivery.
--   * pg_stat_replication showed `realtime_replication_connection` streaming with
--     sent_lsn == replay_lsn, i.e. the worker was reading the WAL.
--   * pg_replication_slots listed only
--     `supabase_realtime_messages_replication_slot_*` — the transactional-messages
--     pipeline. Nothing was consuming `supabase_realtime` itself.
--   * Both the official JS client (supabase-js 2.118) and a hand-written Phoenix
--     client subscribed as an authenticated Branch Manager and received zero
--     postgres_changes frames for real INSERT / UPDATE / trigger-driven writes.
--   * Project status was ACTIVE_HEALTHY; `config/realtime` reported suspend=false.
--
-- THE FIX
--   Re-register each table in the publication. Membership churns, the publication
--   is republished to the logical decoding machinery, and delivery resumes. Proven:
--   immediately after this script, the JS client received `UPDATE {id:1,stock:25}`
--   within ~1s, and tools/verify_realtime.py went from 5/10 to 10/10
--   (products INSERT 0.14s, sale + trigger-driven stock UPDATE 1.03s, admin PATCH
--   1.07s).
--
-- WHAT THIS FILE IS NOT
--   It is not a schema change: no data, no policies, no grants, no indexes. It only
--   drops and re-adds tables to one publication. It is idempotent and safe to re-run.
--   It is NOT applied by CI, and it is not a substitute for fixing the platform-side
--   cause — if the feed goes silent again after this, the cause is upstream in
--   Supabase Realtime and belongs in a support ticket, not in more SQL here.
--
-- HOW TO RUN IT
--   psql "$DB_URL" -f backend/supabase/maintenance/realtime_publication_refresh.sql
--   ... or paste it into the Supabase SQL editor.
--
-- ALWAYS FOLLOW IT WITH A LIVE CHECK. Nothing in the catalog can prove a frame will
-- be delivered, so run the only test that can:
--   python3 tools/verify_realtime.py        # expects 10/10
-- ============================================================================

begin;

do $$
declare
  t text;
  wanted text[] := array[
    'sales','products','loans','staff','branches','activities',
    'product_units','stock_receipts','stock_receipt_lines'
  ];
begin
  foreach t in array wanted loop
    -- Drop first, tolerating "not a member": the point of this script is to leave
    -- the table registered, whichever way it arrived.
    begin
      execute format('alter publication supabase_realtime drop table public.%I', t);
    exception
      when undefined_object then
        raise notice 'realtime_publication_refresh: % was not published', t;
      when insufficient_privilege then
        raise exception
          'realtime_publication_refresh: cannot alter supabase_realtime for % — run as the project owner', t;
    end;

    execute format('alter publication supabase_realtime add table public.%I', t);
  end loop;
end $$;

-- The count is asserted rather than assumed, so a run that silently did nothing is
-- visible instead of reassuring.
do $$
declare
  n int;
begin
  select count(*) into n from pg_publication_tables
  where pubname = 'supabase_realtime' and schemaname = 'public';
  if n < 9 then
    raise exception
      'realtime_publication_refresh FAILED: only % of 9 tables are published', n;
  end if;
  raise notice 'realtime_publication_refresh: % tables registered in supabase_realtime', n;
end $$;

commit;
