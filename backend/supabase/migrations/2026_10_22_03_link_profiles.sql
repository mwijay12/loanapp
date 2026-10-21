-- Link each profile row to its auth user.
--
-- Symptom: signing in as demo.admin@example.com (password accepted, 200 from
-- /auth/v1/token) then reading any table returns 200 with zero rows — products,
-- branches, loans and profiles alike.
--
-- Cause: every policy routes through public.current_staff_role(), which looks up
-- `profiles where auth_user_id = auth.uid()`. If that column is null the helper
-- returns null, has_any_role() is false, and the row is filtered out. The session
-- is valid; the profile simply is not connected to it. The app then shows a
-- signed-in user with no role and no data.
--
-- The join key is the email, which exists on both sides. Where several auth users
-- share an email this could match more than one row, so the update is limited to
-- profiles that are not linked yet and takes the lowest auth id deterministically.
--
-- Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- What we are about to connect. Keep this output.
select p.email, p.role, p.auth_user_id, u.id as auth_id
from public.profiles p
left join auth.users u on lower(u.email) = lower(p.email)
order by p.email;

update public.profiles p
set auth_user_id = u.id
from auth.users u
where lower(u.email) = lower(p.email)
  and p.auth_user_id is distinct from u.id;

commit;

-- Profiles with a session but no link are the ones that behave as Pending.
select email, role, auth_user_id
from public.profiles
where auth_user_id is null;

-- Auth users with no profile at all cannot sign in usefully either.
select u.email
from auth.users u
left join public.profiles p on p.auth_user_id = u.id
where p.id is null
order by u.email;
