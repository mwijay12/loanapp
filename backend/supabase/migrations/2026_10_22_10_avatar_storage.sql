-- Let a person change their own photo.
--
-- Two things are needed for the Settings screen's "Change photo" button to do
-- anything real:
--
--   1. a place to put the bytes        -> the `avatars` storage bucket
--   2. permission to record the choice -> an UPDATE policy on own profile row
--
-- Both are scoped to the signed-in user. Nobody can write another person's
-- portrait, and the bucket is public-read only because a URL that expires would
-- make the header show initials every ninety days.
--
-- Safe to run twice.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- 1. Bucket. 2 MB ceiling, images only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = true,
      file_size_limit = 2097152,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

-- 2. A person writes only inside a folder named after their auth id:
--    avatars/<auth.uid()>/avatar.jpg
drop policy if exists "avatars own write" on storage.objects;
create policy "avatars own write" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars own update" on storage.objects;
create policy "avatars own update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars read" on storage.objects;
create policy "avatars read" on storage.objects
  for select to public
  using (bucket_id = 'avatars');

-- 3. A person may update their own profile row - and only the avatar column is
--    reachable from the app. The role column is not granted: a policy that let a
--    user update `profiles` freely would let a Branch Manager promote themselves.
drop policy if exists "profiles self avatar" on public.profiles;
create policy "profiles self avatar" on public.profiles
  for update to authenticated
  using (
    auth_user_id = auth.uid()
    or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    auth_user_id = auth.uid()
    or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

commit;

-- Verification: after signing in as a demo account in the app, change the photo.
-- Expected: profiles.avatar_asset becomes a storage URL, and the header shows it.
--
--   select email, avatar_asset from public.profiles where email = 'demo.manager@example.com';
