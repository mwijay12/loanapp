-- Why a signed-in user still sees nothing.
--
-- A valid session was confirmed: /auth/v1/token returns 200, and the access token
-- decodes to { role: authenticated, sub: a5381ecc-…, email: demo.admin@… }.
-- Reading products, branches, loans, profiles, activities and staff all return
-- 200 with zero rows.
--
-- Every read policy passes through public.has_any_role(), which passes through
-- public.current_staff_role(). If that function returns null, all of them are
-- false at once — which is exactly the shape of the symptom. Two things can make
-- it return null even when the profile is linked:
--
--   1. The function is not SECURITY DEFINER, so RLS on profiles applies *inside*
--      the function, it sees no row, and returns null. This is the classic way
--      this pattern breaks.
--   2. It resolves `profiles` through the caller's search_path, and a caller
--      without public on the path finds nothing.
--
-- Both are fixed by defining the function explicitly. The policies themselves are
-- left to 2026_10_20_01_rls_policies.sql, which is idempotent — run it again
-- after this file so the set is complete.
--
-- Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- 1. Recreate the helpers with an explicit search path and definer rights.
create or replace function public.current_staff_role()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.role
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1
$$;

create or replace function public.has_any_role(roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.current_staff_role() = any (roles), false)
$$;

grant execute on function public.current_staff_role() to authenticated, anon;
grant execute on function public.has_any_role(text[]) to authenticated, anon;

-- 2. Re-link by email, in case the previous update matched nothing.
update public.profiles p
set auth_user_id = u.id
from auth.users u
where lower(u.email) = lower(p.email)
  and p.auth_user_id is distinct from u.id;

commit;

-- 3. Diagnostics. These three should tell the whole story.
--    a) every profile and whether its link points at a real auth user
select p.email,
       p.role,
       p.auth_user_id,
       (u.id is not null) as link_resolves
from public.profiles p
left join auth.users u on u.id = p.auth_user_id
order by p.email;

--    b) the function bodies, to confirm SECURITY DEFINER took effect
select proname,
       prosecdef as security_definer,
       proconfig as settings
from pg_proc
where proname in ('current_staff_role', 'has_any_role');

--    c) how many policies exist per table. A table with zero is closed to
--       everyone, which reads as "no data" in the app.
select tablename, count(*) as policies
from pg_policies
where schemaname = 'public'
group by tablename
order by tablename;
