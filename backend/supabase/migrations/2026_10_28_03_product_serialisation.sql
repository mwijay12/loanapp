-- R10 — phones are tracked per serial, accessories and cartons are tracked by count.
--
-- The owner's ruling (2026-10-28): "vifaa vya pale sehemu wanapouza simu … store
-- accessories ziwe kwa kaunti" — accessories sold in the phone section are counted,
-- not serialised. A charger has no IMEI and nobody is ever asked which charger a
-- customer took back; a handset is. So the difference is a property of the product,
-- decided once at intake, not something the cashier has to remember at the till.
--
-- WHAT THIS DELIBERATELY DOES NOT DO
-- -----------------------------------
-- The obvious next step is a trigger that keeps products.stock in step with the
-- rows in product_units (count of units where status = 'in_stock'). It is not here,
-- and that is not an oversight — on this database it would be a data-destroying
-- change. Live counts on 2026-10-28:
--
--   product_units                    0 rows
--   products (acc 3 / laptops 1 / phones 8)   242 units of stock between them
--   products.imei1 / imei2           every value NULL
--   sales                            47 rows, 4 of them carry an imei
--
-- A sync trigger firing on the first new unit row would set a phone model's stock to
-- 1 while the shop still shows and sells 26 of them, because 25 of those handsets
-- were never entered as units. The shop would appear to have lost stock it is
-- holding. Serial tracking has to be *backfilled* (or started at the next delivery)
-- before it is allowed to *drive* the number on the shelf. That backfill needs the
-- physical stock count, which is a person with a clipboard, not a migration.
--
-- So: `is_serialised` marks which regime a product belongs to, the guards below stop
-- a serial from being re-keyed or un-sold, and the two counters stay independent
-- until someone has actually entered the handsets. Read products.stock for "how many
-- do we have"; read product_units for "which one".
--
-- Safe to run twice. Verified against fzlykkwgkydswvnlryhk.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

-- ------------------------------------------------- 1. which products have serials
alter table public.products
  add column if not exists is_serialised boolean not null default true;

-- Set it from the category that is actually on the row today. Using the live data
-- rather than a literal list means a re-run converges instead of overwriting a
-- manager's manual correction to `false` on, say, a boxed laptop bag.
update public.products
   set is_serialised = (category is distinct from 'acc')
 where is_serialised <> (category is distinct from 'acc');

-- The app writes 'phones' / 'acc' / 'laptops' today (live: acc 3, laptops 1,
-- phones 8, nothing outside that set). A check turns a typo like 'Phone' or 'ACC'
-- from a silently unfindable product into an error at the till. 'service' and
-- 'other' are allowed so airtime/top-ups can be added without a migration.
alter table public.products
  drop constraint if exists products_category_known;
alter table public.products
  add constraint products_category_known
  check (category in ('phones', 'acc', 'laptops', 'service', 'other'));

-- A negative stock is what a "sale decrements an untracked counter" bug leaves
-- behind, and the shop then sells units it does not have. Zero rows violate this
-- today (checked before writing the constraint), so it costs nothing to make
-- negative stock impossible from now on.
alter table public.products
  drop constraint if exists products_stock_not_negative;
alter table public.products
  add constraint products_stock_not_negative check (stock >= 0);

-- ------------------------------------------------- 2. a unit must be a real product
-- product_units.product_id has never had a foreign key, so a unit can point at a
-- product that does not exist and the app renders a handset with no model, no price
-- and no shelf. The table is empty right now (0 rows, 0 orphans), so adding it is
-- free today and expensive the day a delivery is scanned.
alter table public.product_units
  drop constraint if exists product_units_product_id_fkey;
alter table public.product_units
  add constraint product_units_product_id_fkey
  foreign key (product_id) references public.products(id) on delete set null;

-- A serialised product with no units is the state this shop is in right now, so the
-- flag is descriptive and must not be used as a constraint ("each serialised product
-- needs a unit row") — that would reject the 9 existing phone/laptop rows.

-- --------------------------------- 3. a serial is an identity, not an editable field
-- product_units RLS is deliberately open to every authenticated role (read, insert,
-- update all evaluate to true): a Storekeeper receiving a delivery and a Cashier
-- selling a handset both have to write here, and the app cannot be given a narrower
-- policy without breaking both. That openness is fine for moving a phone between
-- branches and fatal for the fields that make a handset *this* handset.
--
-- These are the writes the app actually makes today (frontend/lib/core/data/
-- api_service.dart): a transfer updates branch + receipt_id + updated_at; a delivery
-- inserts imei + branch + receipt_id + status + received_at; a sale sets status +
-- sale_id + sold_at. None of them intends to change an IMEI. All of them can, which
-- is how a mis-scan becomes "the stolen phone is back in stock".
create or replace function public.guard_product_unit_identity()
returns trigger
language plpgsql
as $$
begin
  if new.imei is distinct from old.imei then
    raise exception 'unit_imei_immutable' using errcode = '42501';
  end if;
  if new.product_id is distinct from old.product_id then
    raise exception 'unit_product_immutable' using errcode = '42501';
  end if;
  if new.received_at is distinct from old.received_at then
    raise exception 'unit_received_immutable' using errcode = '42501';
  end if;
  -- A sold handset is a finished transaction. To put it back on the shelf it has to
  -- arrive as a return on a receipt, which is a new row with its own evidence. A
  -- client that can quietly null sale_id can make a sold phone sellable twice.
  if old.sale_id is not null and new.sale_id is distinct from old.sale_id then
    raise exception 'unit_sale_immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;

-- loan_id is NOT guarded, on purpose: the loan-close/return flow has to release the
-- handset, and this database contains no rows to prove which value it writes when it
-- does. Guarding it would risk breaking a working money path in order to protect an
-- empty table. Note it as the next thing to pin down once real units exist.

drop trigger if exists product_units_guard_identity on public.product_units;
create trigger product_units_guard_identity
  before update on public.product_units
  for each row execute function public.guard_product_unit_identity();

commit;

-- ------------------------------------------------------------ verification
select
  (select count(*) from public.products)                                    as products,
  (select count(*) from public.products where is_serialised)                as serialised,
  (select count(*) from public.products where not is_serialised)            as by_count,
  (select count(*) from public.product_units)                               as units,
  (select count(*) from pg_trigger where tgname = 'product_units_guard_identity') as guard_trigger,
  (select count(*) from pg_constraint
    where conname in ('products_category_known', 'products_stock_not_negative',
                      'product_units_product_id_fkey'))                     as new_constraints;

-- Expected: 12 products, 9 serialised, 3 by_count (the acc rows), 0 units,
-- guard_trigger 1, new_constraints 3.
