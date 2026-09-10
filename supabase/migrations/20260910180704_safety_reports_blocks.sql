create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(), reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (length(trim(reason)) between 3 and 1000), created_at timestamptz not null default now()
);
create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(), primary key (blocker_id, blocked_user_id), check (blocker_id <> blocked_user_id)
);
alter table public.reports enable row level security; alter table public.blocks enable row level security;
create policy "users create reports" on public.reports for insert to authenticated with check (reporter_id = (select auth.uid()) and reporter_id <> reported_user_id);
create policy "users view own reports" on public.reports for select to authenticated using (reporter_id = (select auth.uid()));
create policy "users block others" on public.blocks for insert to authenticated with check (blocker_id = (select auth.uid()) and blocker_id <> blocked_user_id);
create policy "users manage own blocks" on public.blocks for select to authenticated using (blocker_id = (select auth.uid()));
create policy "users remove own blocks" on public.blocks for delete to authenticated using (blocker_id = (select auth.uid()));
drop policy if exists "verified users can view compatible active rides" on public.rides;
create policy "verified users can view compatible active rides" on public.rides for select to authenticated using (
 status = 'active' and not exists (select 1 from public.blocks b where b.blocker_id = (select auth.uid()) and b.blocked_user_id = rides.driver_id) and (driver_id = (select auth.uid()) or exists (select 1 from public.profiles viewer join public.profiles driver on driver.id = rides.driver_id where viewer.id = (select auth.uid()) and viewer.fast_id_status = 'verified' and (rides.gender_pref = 'any' or viewer.gender = driver.gender)))
);
