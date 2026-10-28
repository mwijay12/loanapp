-- One product, one picture.
--
-- The owner's words: "picha zinabadilika for one product in different screens".
-- He is right, and the cause is in the data rather than in Supabase. Two things were
-- wrong at once:
--
--  1. Seven of the twelve rows store a *Dart constant name* in `image_asset` —
--     'ProductArt.samsung', 'ProductArt.watch', 'ProductArt.earbuds' and so on.
--     `ProductArt` is a class in lib/core/data/product_art.dart, and those names are
--     the constants *inside* it. `Image.asset('ProductArt.samsung')` loads nothing,
--     so each screen fell back through its own errorBuilder and drew its own
--     substitute: the stock list, the featured carousel and the storekeeper hero
--     then showed three different pictures of one handset.
--  2. Four rows carry an Unsplash `image_url` as well, and one of them is a photo of
--     a different phone than the row it is attached to (id 6, Galaxy A55, holds the
--     Redmi Note 13 Pro photo `photo-1598327105666-5b89351a...`, the same image id 3
--     uses). A screen that prefers the URL shows a photo; a screen that prefers the
--     asset shows artwork. Same product, two looks.
--
-- The rule this migration installs: `image_asset` holds a real asset path, or it is
-- NULL and the single ProductArt.resolve fallback applies. Both halves are enforced
-- — the values are corrected here, and the CHECK at the bottom stops a symbolic name
-- from being stored again by any client.
--
-- Run in the Supabase SQL editor, or: python3 tools/sql.py -f <this file>
-- Safe to run twice.
--
-- To undo, restore what was there on 2026-10-28 (this is the whole list; nothing
-- else was touched):
--   update public.products set image_asset = 'ProductArt.earbuds',   image_url = 'https://images.unsplash.com…&fit=crop&q=80'  where id = 5;
--   update public.products set image_asset = 'ProductArt.samsung',   image_url = 'https://images.unsplash.com…&fit=crop&q=80'  where id = 6;
--   update public.products set image_url = 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=600&auto=format&fit=crop&q=80' where id = 4;
--   update public.products set image_url = 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=600&auto=format&fit=crop&q=80' where id = 3;
--   update public.products set image_url = 'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=600&auto=format&fit=crop&q=80' where id = 2;
--   update public.products set image_asset = 'ProductArt.infinix'  where id = 8;
--   update public.products set image_asset = 'ProductArt.itel'     where id = 9;
--   update public.products set image_asset = 'ProductArt.powerBank' where id = 10;
--   update public.products set image_asset = 'ProductArt.watch'    where id = 11;
--   update public.products set image_asset = 'ProductArt.laptop'   where id = 12;
--   alter table public.products drop constraint if exists products_image_asset_is_path;

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- 1. The symbolic names become the files those constants point at. Taken from
--    lib/core/data/product_art.dart, which is the only place they were ever defined.
update public.products set image_asset = 'assets/images/samsung_galaxy_ultra.png' where image_asset = 'ProductArt.samsung';
update public.products set image_asset = 'assets/images/phone_midnight.png'       where image_asset = 'ProductArt.infinix';
update public.products set image_asset = 'assets/images/phone_entry_teal.png'     where image_asset = 'ProductArt.itel';
update public.products set image_asset = 'assets/images/phone_generic.png'        where image_asset = 'ProductArt.genericPhone';
update public.products set image_asset = 'assets/images/laptop.png'               where image_asset = 'ProductArt.laptop';
update public.products set image_asset = 'assets/images/powerbank.png'            where image_asset = 'ProductArt.powerBank';
update public.products set image_asset = 'assets/images/smartwatch.png'           where image_asset = 'ProductArt.watch';
update public.products set image_asset = 'assets/images/earbuds.png'              where image_asset = 'ProductArt.earbuds';

-- 2. Where a row now has real artwork, the placeholder photo is dropped. The photo
--    was a stand-in from the seed data, and on at least one row it was the wrong
--    model. `image_url` stays available: it is the column for a photo the shop
--    uploads itself, and the app reads it when `image_asset` is empty.
update public.products
   set image_url = null
 where image_url is not null
   and image_asset is not null
   and image_url like 'https://images.unsplash.com%';

-- 3. Stop it happening again. A value that is neither a bundled asset path nor a
--    URL cannot be rendered by anything, so it is not allowed in the column. This
--    is the same rule SupabaseSource._realAssetPath applies on the way in; a CHECK
--    is the version that does not depend on the client choosing to obey.
alter table public.products
  drop constraint if exists products_image_asset_is_path;
alter table public.products
  add constraint products_image_asset_is_path
  check (
    image_asset is null
    or image_asset like 'assets/%'
    or image_asset like 'http://%'
    or image_asset like 'https://%'
  );

commit;

-- What the catalogue looks like now: every row resolves to one picture, and no row
-- carries two competing ones.
select id, left(name, 30) as name, category, stock,
       coalesce(image_asset, '(none -> ProductArt fallback)') as image_asset,
       coalesce(left(image_url, 46), '(none)') as image_url
from public.products
order by id;

select count(*) filter (where image_asset is not null
                          and image_asset not like 'assets/%'
                          and image_asset not like 'http%') as still_symbolic,
       count(*) filter (where image_asset is not null and image_url is not null) as both_sources
from public.products;
