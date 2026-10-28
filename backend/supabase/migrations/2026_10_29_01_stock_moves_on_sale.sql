-- A sale must move the shelf.
--
-- Found while answering "database inazingua". The owner's stock figure never changed,
-- and the first reason was that the stock screens never wrote (fixed in Dart in
-- commit 546df64, `SupabaseSource.createProduct` / `adjustStock`). Second reason,
-- bigger: **nothing has ever
-- decremented `products.stock` when a handset is sold.** `sales` holds 47 rows with
-- 46 of them naming a product, `products.stock` is untouched by them,
-- `products.sold_today` is still the number the seed data shipped with, and
-- `product_history` — the trail the owner asked where it was — has **0 rows**.
-- `InventoryNotifier.sellProduct` moves the number in memory, `recordSale` writes
-- the ledger, and the two have never met.
--
-- So the shop's most important number drifts upward from reality with every sale,
-- on every screen, forever. A shelf that says 166 after 40 phones left it is worse
-- than a shelf that says nothing.
--
-- Why this lives in the database and not in Dart:
--   * A Counter Cashier, and a Storekeeper selling under a manager override, do not
--     hold the `products_stock_write` role. An UPDATE from the client would be
--     refused by RLS — and on an UPDATE PostgREST refuses this way, nothing is
--     updated and nothing is thrown. The sale would commit and the stock would
--     quietly stay. SECURITY DEFINER runs as the owner, so the row moves.
--   * The rule then holds for every writer that ever exists: the till, a receipt
--     replay, a bulk import, an admin console.
--
-- Decisions, with the reason each was taken:
--   * One sale row = one unit. `sales` has no quantity column; the till prints one
--     handset per receipt. Anything else would be invented.
--   * Stock is clamped at zero, never negative. `products_stock_not_negative`
--     (migration 2026_10_28_03) would otherwise abort the INSERT — which means the
--     till could refuse to record money it has physically taken because the book
--     said zero. Money is recorded; the count stops at zero; the history row says
--     what happened.
--   * The historical 47 sales are deliberately NOT replayed. Their stock was never
--     checked against a physical count, so subtracting 46 from 166 would replace one
--     unverified number with another. Today's `stock` is treated as the opening
--     count, and every movement from here on is recorded. That is a decision the
--     owner can reverse with a real count, not a silent assumption.
--   * `sold_today` is incremented because the home screen reads that column. Nothing
--     resets it at midnight yet; that is a follow-up (see the plan), and it is the
--     honest state rather than a prettier one.
--
-- Run in the Supabase SQL editor, or: python3 tools/sql.py -f <this file>
-- Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

-- ------------------------------------------------------------------- the move
create or replace function public.record_sale_stock_move()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  product public.products;
  moved   int;
begin
  -- An accessory sale without a product id is a note, not a movement.
  if new.product_id is null then
    return new;
  end if;

  select * into product from public.products where id = new.product_id;
  if not found then
    -- The row is gone. Recording the sale is still right; inventing a product is not.
    return new;
  end if;

  moved := greatest(coalesce(product.stock, 0) - 1, 0);

  update public.products
     set stock      = moved,
         sold_today = coalesce(sold_today, 0) + 1,
         status     = case when moved <= 0 then 'out'
                           when moved <= coalesce(min_stock, 0) then 'low'
                           else 'in' end
   where id = product.id;

  -- The trail the owner asked for. It used to be empty even though the shop had
  -- been selling: 47 sales, 0 history rows.
  insert into public.product_history (product_id, title, detail, time_label, event_type)
  values (
    product.id,
-- A financed handset leaves the shop exactly as a sold one does, but a history line
-- reading "Sold" for a loan is wrong in a way a manager will notice while chasing a
-- device. Same movement, honest verb.
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

  -- If the serial is on the ledger, it stops being shop property on this row.
  -- Inert today (`product_units` is empty); correct from the first scanned intake.
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

revoke all on function public.record_sale_stock_move() from public, anon, authenticated;
grant execute on function public.record_sale_stock_move() to authenticated;

drop trigger if exists sales_record_stock_move on public.sales;
create trigger sales_record_stock_move
  after insert on public.sales
  for each row execute function public.record_sale_stock_move();

commit;

-- ------------------------------------------------------------------ what to look at
-- Sell one handset and the row should answer: stock -1, sold_today +1, one new
-- product_history row. tools/verify_product_writes.py section J does exactly this
-- against the live project and restores what it changed.
--
-- select p.id, p.name, p.stock, p.sold_today, p.status
--   from public.products p join public.sales s on s.product_id = p.id
--  where s.receipt_no like 'J-%' order by s.id desc limit 5;
--
-- select event_type, count(*) from public.product_history group by event_type;
