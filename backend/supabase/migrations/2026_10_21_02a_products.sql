-- Step 1 of 4 — products and branches.
--
-- WHY THIS IS SPLIT: the single-file version timed out the dashboard with
-- "Failed to fetch (api.supabase.com)". That message is the browser losing the
-- HTTP request, not Postgres rejecting the SQL. A statement that waits on a lock
-- or rewrites a large column keeps the request open until the dashboard gives up.
-- Four short requests finish well inside that window.
--
-- If a previous attempt is still holding locks, find it first:
--   select pid, state, left(query, 60), now() - query_start as age
--   from pg_stat_activity
--   where datname = current_database() and state <> 'idle'
--     and pid <> pg_backend_pid();
-- then, only for a session you recognise as your own failed attempt:
--   select pg_terminate_backend(<pid>);
--
-- Every statement here is safe to run twice.

begin;

-- Fail in 5 seconds with a clear lock error instead of hanging until the
-- dashboard drops the connection.
set local lock_timeout = '5s';
set local statement_timeout = '120s';

alter table public.products
  add column if not exists brand text,
  add column if not exists imei1 text,
  add column if not exists imei2 text,
  add column if not exists cost_price numeric(14,2),
  add column if not exists loan_price numeric(14,2),
  add column if not exists image_asset text,
  add column if not exists image_url text;

-- Strip formatting only where the column is still text. Once it is numeric the
-- cast below is a no-op, so a second run does not touch the data.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'products'
      and column_name = 'price' and data_type = 'text'
  ) then
    update public.products
    set price = regexp_replace(price, '[^0-9.\-]', '', 'g')
    where price ~ '[^0-9.\-]';

    alter table public.products
      alter column price type numeric(14,2) using nullif(price, '')::numeric;
  end if;
end $$;

create unique index if not exists products_imei1_key
  on public.products (imei1) where imei1 is not null;

-- `branches.sales` stays text on purpose: 'TZS 4.85M' stripped of its letters is
-- 4.85, and that is a different number. Display text stays as written; the value
-- the app can sum lives in sales_today.
alter table public.branches
  add column if not exists sales_today numeric(14,2) default 0;

commit;

select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name in ('products', 'branches')
  and column_name in ('price', 'imei1', 'imei2', 'brand', 'sales', 'sales_today')
order by table_name, column_name;
