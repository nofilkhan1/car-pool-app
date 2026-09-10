-- FAST Carpool onboarding and verification storage.
-- Replace the ADMIN_USER_ID placeholder in the admin policies before applying.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  batch text not null,
  gender text not null,
  phone text not null,
  fast_id_status text not null default 'pending' check (fast_id_status in ('pending', 'verified', 'rejected')),
  created_at timestamptz not null default now()
);

create table if not exists public.fast_id_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  id_card_image_url text not null,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewer_notes text,
  status text not null default 'pending' check (status in ('pending', 'verified', 'rejected'))
);

create index if not exists fast_id_verifications_pending_idx on public.fast_id_verifications(status, submitted_at);

alter table public.profiles enable row level security;
alter table public.fast_id_verifications enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select to authenticated using ((select auth.uid()) = id);
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

drop policy if exists "verification_select_own" on public.fast_id_verifications;
create policy "verification_select_own" on public.fast_id_verifications for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "verification_insert_own" on public.fast_id_verifications;
create policy "verification_insert_own" on public.fast_id_verifications for insert to authenticated with check ((select auth.uid()) = user_id);

-- Temporary admin gate. This is the current owner's Supabase auth user ID.
drop policy if exists "verification_admin_select" on public.fast_id_verifications;
create policy "verification_admin_select" on public.fast_id_verifications for select to authenticated using ((select auth.uid()) = '7e19995c-437e-4f15-9a3f-b50ea1414402'::uuid);
drop policy if exists "verification_admin_delete" on public.fast_id_verifications;
create policy "verification_admin_delete" on public.fast_id_verifications for delete to authenticated using ((select auth.uid()) = '7e19995c-437e-4f15-9a3f-b50ea1414402'::uuid);
drop policy if exists "profiles_admin_update" on public.profiles;
create policy "profiles_admin_update" on public.profiles for update to authenticated using ((select auth.uid()) = '7e19995c-437e-4f15-9a3f-b50ea1414402'::uuid) with check (fast_id_status in ('pending', 'verified', 'rejected'));

insert into storage.buckets (id, name, public) values ('fast-id-cards', 'fast-id-cards', false) on conflict (id) do update set public = false;

drop policy if exists "id_cards_insert_own_folder" on storage.objects;
create policy "id_cards_insert_own_folder" on storage.objects for insert to authenticated with check (bucket_id = 'fast-id-cards' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "id_cards_select_own_folder" on storage.objects;
create policy "id_cards_select_own_folder" on storage.objects for select to authenticated using (bucket_id = 'fast-id-cards' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "id_cards_select_admin" on storage.objects;
create policy "id_cards_select_admin" on storage.objects for select to authenticated using (bucket_id = 'fast-id-cards' and (select auth.uid()) = '7e19995c-437e-4f15-9a3f-b50ea1414402'::uuid);
drop policy if exists "id_cards_delete_admin" on storage.objects;
create policy "id_cards_delete_admin" on storage.objects for delete to authenticated using (bucket_id = 'fast-id-cards' and (select auth.uid()) = '7e19995c-437e-4f15-9a3f-b50ea1414402'::uuid);
