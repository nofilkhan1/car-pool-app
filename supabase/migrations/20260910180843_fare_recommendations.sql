alter table public.rides add column if not exists vehicle_type text not null default 'car' check (vehicle_type in ('car','bike'));
alter table public.rides add column if not exists distance_km numeric(8,2) not null default 0 check (distance_km >= 0);
alter table public.rides add column if not exists rate_per_km numeric(8,2) not null default 35 check (rate_per_km in (35,20));
alter table public.rides add column if not exists recommended_fare numeric(10,2) not null default 0 check (recommended_fare >= 0);
alter table public.ride_requests add column if not exists proposed_fare numeric(10,2);
create or replace function public.validate_ride_fare() returns trigger language plpgsql as $$
begin
  if new.price_per_seat < greatest(0, new.distance_km * (new.rate_per_km - 5)) or new.price_per_seat > new.distance_km * (new.rate_per_km + 5) then
    raise exception 'Fare must stay within +/- 5 PKR per km of the vehicle rate';
  end if;
  return new;
end $$;
drop trigger if exists rides_fare_range on public.rides;
create trigger rides_fare_range before insert or update on public.rides for each row execute function public.validate_ride_fare();
