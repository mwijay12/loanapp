-- Step 5 — "on offer" handsets.
--
-- WHY: the shop owner needs to put a handset in front of the cashier on the
-- till home, usually a model that has been sitting on the shelf. The flag is a
-- column, not a screen-only setting, because a flag that reaches one device and
-- not the database is exactly the kind of thing that looks saved and is not.
--
-- Safe to run twice. Run it in the Supabase SQL editor, then reload the app: the
-- admin can then switch any handset on offer from Stock → open a product.
--
-- The client reads `products.on_offer` already. A missing column reads as false
-- instead of breaking the catalogue, and the switch reports that the migration
-- has not been run rather than silently dropping the change.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

alter table public.products
  add column if not exists on_offer boolean not null default false,
  add column if not exists offer_note text;

-- Only the flagged rows are ever queried together, and they are few.
create index if not exists products_on_offer_idx
  on public.products (on_offer) where on_offer;

commit;

-- Verification: should list on_offer / offer_note as boolean / text.
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'products'
  and column_name in ('on_offer', 'offer_note')
order by column_name;

-- Verification: how many handsets are on offer right now.
select count(*) filter (where on_offer) as on_offer, count(*) as total
from public.products;
