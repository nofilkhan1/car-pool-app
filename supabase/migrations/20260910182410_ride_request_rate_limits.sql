create or replace function public.enforce_ride_request_limits() returns trigger language plpgsql as $$
declare pending_count integer; recent_count integer; last_rejected timestamptz;
begin
 select count(*) into pending_count from public.ride_requests where rider_id=new.rider_id and status='pending';
 if pending_count >= 5 then raise exception 'You can have at most 5 pending ride requests'; end if;
 select count(*) into recent_count from public.ride_requests where rider_id=new.rider_id and created_at > now() - interval '1 hour';
 if recent_count >= 10 then raise exception 'Request limit reached. Try again later.'; end if;
 select max(created_at) into last_rejected from public.ride_requests where rider_id=new.rider_id and status in ('rejected','cancelled');
 if last_rejected is not null and last_rejected > now() - interval '10 minutes' then raise exception 'Please wait 10 minutes after a rejection or cancellation'; end if;
 return new;
end $$;
drop trigger if exists ride_request_limits on public.ride_requests;
create trigger ride_request_limits before insert on public.ride_requests for each row execute function public.enforce_ride_request_limits();
