-- "Sold today" that means today, and a way to write down a real count.
--
-- Two things the owner was asked and answered "weka sawa" / "try any reasonable":
--
-- 1. SOLD TODAY. `record_sale_stock_move` (2026_10_29_01) increments
--    `products.sold_today`, but nothing has ever reset it, so after a week it is
--    "sold this week" wearing a label that says "leo". A counter reading 9 on a
--    morning when nothing has sold is not a stale number, it is a wrong one.
--    Fix: the counter now carries the day it belongs to.
--      * `shop_today()` is the date in the shop's own timezone. Dar es Salaam is
--        UTC+3 with no DST, but writing the zone rather than a fixed offset means
--        the answer cannot rot, and `set local timezone` in a session, a dashboard
--        or a psql tab is no longer allowed to move midnight.
--      * The sale trigger compares that day and restarts the count when it has
--        turned. No scheduler is involved: `pg_cron` is available on this project
--        but not installed, and a nightly job that only exists when someone
--        remembers to install it is a reset that silently stops happening.
--      * The remaining honesty gap is stated rather than hidden: with no sale today,
--        the *column* still holds yesterday's figure until the next write. The
--        reports screen therefore stops reading the column and counts today's rows
--        in `sales`, which is where the truth actually lives. The column is now a
--        cache, not a source.
--
-- 2. OPENING STOCK. The historical 47 sales were deliberately not replayed, so
--    today's `stock` is treated as an opening count nobody has physically verified.
--    The honest way to close that gap is not to invent a number here; it is to give
--    the shop a way to enter the number it can see on the shelf.
--      * `set_product_stock` writes an absolute count and records the previous one
--        in `product_history` as a `count` event, so "why is it 143 now?" has an
--        answer with a name and a time attached.
--      * `adjust_product_stock` replaces the read-modify-write the Dart client was
--        doing. That version read the row, added, and wrote the sum back, which
--        loses one of two movements whenever a sale and a delivery overlapped - the
--        race is named in the Dart file that used to do it. One UPDATE that adds in
--        the database cannot lose a race it is not participating in.
--      * Both functions check the same roles as `products_stock_write` themselves.
--        SECURITY DEFINER bypasses RLS, and a function that let a Counter Cashier
--        move stock because it was convenient to write would be a privilege the
--        policies explicitly refuse. That check is the price of the definer.
--
-- Run in the Supabase SQL editor, or: python3 tools/sql.py -f <this file>
-- Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

-- ---------------------------------------------------------------- the shop's day
create or replace function public.shop_today()
returns date
language sql
stable
as $$
  select (now() at time zone 'Africa/Dar_es_Salaam')::date;
$$;

comment on function public.shop_today() is
  'The calendar date the shop operates on. Use this instead of current_date, which '
  'follows the session timezone: 30 minutes after local midnight, Postgres still '
  'thinks it is yesterday.';

alter table public.products
  add column if not exists sold_today_on date not null default public.shop_today();

-- ------------------------------------------------- stock movement, day aware now
create or replace function public.record_sale_stock_move()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  product  public.products;
  moved    int;
  today    date := public.shop_today();
begin
  if new.product_id is null then
    return new;
  end if;

  select * into product from public.products where id = new.product_id;
  if not found then
    return new;
  end if;

  moved := greatest(coalesce(product.stock, 0) - 1, 0);

  update public.products
     set stock        = moved,
         sold_today   = case when product.sold_today_on = today
                             then coalesce(product.sold_today, 0) + 1
                             else 1 end,
         sold_today_on = today,
         status       = case when moved <= 0 then 'out'
                             when moved <= coalesce(min_stock, 0) then 'low'
                             else 'in' end
   where id = product.id;

  insert into public.product_history (product_id, title, detail, time_label, event_type)
  values (
    product.id,
    case when coalesce(new.kind, 'cash') = 'loan'
         then 'Financed: ' || product.name
         else 'Sold: ' || product.name end,
    'Receipt ' || coalesce(new.receipt_no, '—')
      || ' · ' || coalesce(new.kind, 'cash')
      || ' · ' || coalesce(new.payment_channel, 'unspecified')
      || case when new.imei is not null and new.imei <> '' then ' · IMEI ' || new.imei else '' end
      || case when moved = 0 and coalesce(product.stock, 0) = 0
              then ' · shelf was already at zero, count left at zero' else '' end,
    'Just now',
    'sale'
  );

  if new.imei is not null and char_length(new.imei) = 15 then
    update public.product_units
       set status     = 'sold',
           sale_id    = new.id,
           sold_at    = coalesce(new.sold_at, now()),
           updated_at = now()
     where imei = new.imei
       and status <> 'sold';
  end if;

  return new;
end;
$$;

-- ------------------------------------------------ the two stock-count RPCs
create or replace function public.stock_write_guard(p_product_id bigint)
returns public.products
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  product public.products;
begin
  -- The same list as the `products_stock_write` policy. SECURITY DEFINER walks past
  -- RLS, so the function has to refuse on its own or it becomes a way for a role the
  -- policy says no to reach a write anyway.
  if not public.has_any_role(array['Super Admin', 'Branch Manager', 'Storekeeper']) then
    raise exception 'stock_write_forbidden' using errcode = '42501';
  end if;

  select * into product from public.products where id = p_product_id;
  if not found then
    raise exception 'stock_product_unknown' using errcode = 'P0002';
  end if;
  return product;
end;
$$;

create or replace function public.adjust_product_stock(
  p_product_id bigint,
  p_delta      int,
  p_reason     text default null
)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  before_row public.products := public.stock_write_guard(p_product_id);
  after      int;
begin
  if p_delta is null or p_delta = 0 then
    raise exception 'stock_delta_zero' using errcode = '22023';
  end if;

  -- One statement. The client used to read the count, add in Dart and write the
  -- sum back, so a delivery and a sale landing within the same breath overwrote
  -- each other. Nothing can be lost here because nothing is computed outside.
  update public.products
     set stock  = greatest(coalesce(stock, 0) + p_delta, 0),
         status = case when greatest(coalesce(stock, 0) + p_delta, 0) <= 0 then 'out'
                       when greatest(coalesce(stock, 0) + p_delta, 0) <= coalesce(min_stock, 0) then 'low'
                       else 'in' end
   where id = p_product_id
  returning stock into after;

  insert into public.product_history (product_id, title, detail, time_label, event_type)
  values (
    p_product_id,
    case when p_delta > 0 then 'Stock in: ' else 'Stock out: ' end
      || before_row.name,
    coalesce(before_row.stock, 0)::text || ' → ' || after::text
      || case when p_delta < 0 and after = 0 and coalesce(before_row.stock, 0) < -p_delta
              then ' · asked for ' || (-p_delta)::text || ', only '
                   || coalesce(before_row.stock, 0)::text || ' were on hand'
              else '' end
      || coalesce(' · ' || p_reason, ''),
    'Just now',
    case when p_delta > 0 then 'receive' else 'adjust' end
  );

  return after;
end;
$$;

create or replace function public.set_product_stock(
  p_product_id bigint,
  p_stock      int,
  p_reason     text default null
)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  before_row public.products := public.stock_write_guard(p_product_id);
  after      int;
begin
  if p_stock is null or p_stock < 0 then
    -- A count is a physical fact. There is no such thing as eleven negative
    -- chargers on a shelf, and `products_stock_not_negative` would refuse the row
    -- anyway with a worse message.
    raise exception 'stock_count_invalid' using errcode = '22023';
  end if;

  update public.products
     set stock  = p_stock,
         status = case when p_stock <= 0 then 'out'
                       when p_stock <= coalesce(min_stock, 0) then 'low'
                       else 'in' end
   where id = p_product_id
  returning stock into after;

  insert into public.product_history (product_id, title, detail, time_label, event_type)
  values (
    p_product_id,
    'Counted: ' || before_row.name,
    'Shelf said ' || coalesce(before_row.stock, 0)::text || ', counted ' || after::text
      || coalesce(' · ' || p_reason, ''),
    'Just now',
    'count'
  );

  return after;
end;
$$;

revoke all on function public.stock_write_guard(bigint) from public, anon, authenticated;
revoke all on function public.adjust_product_stock(bigint, int, text) from public, anon, authenticated;
revoke all on function public.set_product_stock(bigint, int, text) from public, anon, authenticated;
grant execute on function public.stock_write_guard(bigint) to authenticated;
grant execute on function public.adjust_product_stock(bigint, int, text) to authenticated;
grant execute on function public.set_product_stock(bigint, int, text) to authenticated;

commit;

-- ---------------------------------------------------------------- what to look at
-- tools/verify_product_writes.py section K drives all of this over the same HTTP
-- surface the app uses, as a Storekeeper, a Cashier and an unauthenticated caller.
--
-- select id, name, stock, sold_today, sold_today_on from public.products order by id;
-- select event_type, count(*) from public.product_history group by event_type;
