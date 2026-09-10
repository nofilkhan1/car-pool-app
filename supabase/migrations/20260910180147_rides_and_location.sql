
create extension if not exists cube;

alter table public.profiles add column if not exists push_token text;

create table if not exists public.rides (
  id uuid primary key default gen_random_uuid(), driver_id uuid not null references public.profiles(id) on delete cascade,
  start_area text not null, start_lat double precision, start_lng double precision,
  departure_at timestamptz not null, available_seats integer not null check (available_seats between 1 and 12),
  price_per_seat numeric(10,2) not null check (price_per_seat >= 0),
  gender_pref text not null default 'any' check (gender_pref in ('any','same_gender_only')),
  status text not null default 'active' check (status in ('active','completed','cancelled')), created_at timestamptz not null default now()
);
create index if not exists rides_active_departure_idx on public.rides(status, departure_at);

create table if not exists public.ride_requests (
  id uuid primary key default gen_random_uuid(), ride_id uuid not null references public.rides(id) on delete cascade,
  rider_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled')),
  created_at timestamptz not null default now(), unique(ride_id, rider_id)
);
create index if not exists ride_requests_driver_idx on public.ride_requests(ride_id, status);

create table if not exists public.live_locations (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  ride_id uuid not null references public.rides(id) on delete cascade,
  lat double precision not null, lng double precision not null, updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null, title text not null, body text not null, data jsonb not null default '{}'::jsonb, read_at timestamptz, created_at timestamptz not null default now()
);

alter table public.rides enable row level security; alter table public.ride_requests enable row level security; alter table public.live_locations enable row level security; alter table public.notifications enable row level security;

create policy "verified users can view compatible active rides" on public.rides for select to authenticated using (
  status = 'active' and (driver_id = (select auth.uid()) or exists (select 1 from public.profiles viewer join public.profiles driver on driver.id = rides.driver_id where viewer.id = (select auth.uid()) and viewer.fast_id_status = 'verified' and (rides.gender_pref = 'any' or viewer.gender = driver.gender)))
);
create policy "verified users post rides" on public.rides for insert to authenticated with check (driver_id = (select auth.uid()) and exists (select 1 from public.profiles where id = (select auth.uid()) and fast_id_status = 'verified'));
create policy "drivers update rides" on public.rides for update to authenticated using (driver_id = (select auth.uid())) with check (driver_id = (select auth.uid()));

create policy "riders create own requests" on public.ride_requests for insert to authenticated with check (rider_id = (select auth.uid()) and exists (select 1 from public.profiles where id = (select auth.uid()) and fast_id_status = 'verified') and exists (select 1 from public.rides r join public.profiles d on d.id = r.driver_id join public.profiles me on me.id = (select auth.uid()) where r.id = ride_id and r.status = 'active' and (r.gender_pref = 'any' or d.gender = me.gender)));
create policy "riders view own requests" on public.ride_requests for select to authenticated using (rider_id = (select auth.uid()) or exists (select 1 from public.rides where rides.id = ride_requests.ride_id and rides.driver_id = (select auth.uid())));
create policy "drivers decide requests" on public.ride_requests for update to authenticated using (exists (select 1 from public.rides where rides.id = ride_requests.ride_id and rides.driver_id = (select auth.uid()))) with check (status in ('accepted','rejected','cancelled'));

create policy "active connections read locations" on public.live_locations for select to authenticated using (exists (select 1 from public.ride_requests rr join public.rides r on r.id = rr.ride_id where rr.status = 'accepted' and r.status = 'active' and r.id = live_locations.ride_id and ((rr.rider_id = (select auth.uid())) or (r.driver_id = (select auth.uid())))));
create policy "active users upsert own location" on public.live_locations for insert to authenticated with check (user_id = (select auth.uid()) and exists (select 1 from public.ride_requests rr join public.rides r on r.id = rr.ride_id where rr.status = 'accepted' and r.status = 'active' and r.id = live_locations.ride_id and ((rr.rider_id = (select auth.uid())) or (r.driver_id = (select auth.uid())))));
create policy "active users update own location" on public.live_locations for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()) and exists (select 1 from public.ride_requests rr join public.rides r on r.id = rr.ride_id where rr.status = 'accepted' and r.status = 'active' and r.id = live_locations.ride_id and ((rr.rider_id = (select auth.uid())) or (r.driver_id = (select auth.uid())))));
create policy "users delete own location" on public.live_locations for delete to authenticated using (user_id = (select auth.uid()));
create policy "users read own notifications" on public.notifications for select to authenticated using (user_id = (select auth.uid()));
create policy "users mark notifications" on public.notifications for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

alter publication supabase_realtime add table public.ride_requests, public.live_locations, public.notifications;
