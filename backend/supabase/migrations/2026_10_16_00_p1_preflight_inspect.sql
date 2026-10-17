-- ============================================================
-- LIMS P1 — PREFLIGHT INSPECTION (read-only)
-- ============================================================
-- Run this FIRST, before 01/02/03.
-- It tells us what the live database ACTUALLY contains, because
-- backend/supabase/schema.sql and the live DB have drifted apart
-- (see: profiles.password_hash is used by the app but does not
-- exist in schema.sql; products/activities/heartbeat_pings do not
-- exist in schema.sql at all).
--
-- Nothing here writes anything. Paste the output back if you want
-- me to confirm the migrations will apply cleanly.
-- ============================================================

-- 1. Which tables exist right now?
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- 2. Full column inventory for the tables P1 touches.
--    Watch for: profiles.password_hash, profiles.branch_name,
--    customers without branch_id, notifications without user_id,
--    attendance without user_id, stock_transfers without branch_id,
--    heartbeat_pings.metadata vs heartbeat_pings.payload.
SELECT table_name, ordinal_position, column_name, data_type,
       is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'profiles', 'products', 'activities', 'heartbeat_pings',
    'branches', 'staff_invitations', 'role_permissions',
    'branch_settings', 'customers', 'notifications', 'attendance',
    'stock_transfers', 'transfer_items'
  )
ORDER BY table_name, ordinal_position;

-- 3. Existing constraints (PK / FK / CHECK / UNIQUE) on those tables.
SELECT conrelid::regclass::text AS tbl,
       conname,
       contype,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
ORDER BY 1, 2;

-- 4. Is RLS already on anywhere? (expected: every row = false)
SELECT tablename, rowsecurity, forcerowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- 5. Row counts, so we know whether there is real data at risk.
SELECT
  (SELECT count(*) FROM public.branches)          AS branches,
  (SELECT count(*) FROM public.profiles)          AS profiles,
  (SELECT count(*) FROM public.customers)         AS customers,
  (SELECT count(*) FROM public.phones)            AS phones,
  (SELECT count(*) FROM public.loans)             AS loans,
  (SELECT count(*) FROM public.sales)             AS sales,
  (SELECT count(*) FROM public.employees)         AS employees;

-- 6. Branches — copy the Mbagala UUID from here for Migration 03.
SELECT id, name, location, manager_name, is_active, created_at
FROM public.branches
ORDER BY created_at;

-- 7. Auth users — copy the admin UUID from here for Migration 03.
SELECT id, email, email_confirmed_at, created_at, last_sign_in_at
FROM auth.users
ORDER BY created_at;

-- 8. Which schema does pgcrypto live in?
--    Supabase normally installs it into `extensions`, NOT `public`.
--    verify_supervisor_pin() must include it on its search_path.
SELECT e.extname, n.nspname AS installed_schema
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
ORDER BY e.extname;

-- 9. Default search_path of the role you are running as.
SELECT current_user, current_setting('search_path') AS search_path;
