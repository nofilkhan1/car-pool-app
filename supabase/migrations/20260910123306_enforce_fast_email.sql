-- Enforce FAST Lahore student email domains at the auth.users boundary.
-- This runs for every signup path, including direct calls to /auth/v1/signup.
create schema if not exists private;
revoke all on schema private from public;

create or replace function private.enforce_fast_email_domain()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  email_domain text;
begin
  email_domain := lower(split_part(coalesce(new.email, ''), '@', 2));

  -- FAST Lahore student accounts use lhr.nu.edu.pk. nu.edu.pk is retained
  -- for legacy student accounts issued before campus-specific domains.
  if email_domain not in ('lhr.nu.edu.pk', 'nu.edu.pk') then
    raise exception using
      errcode = 'check_violation',
      message = 'Only FAST NUCES Lahore student email addresses are allowed.';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_fast_email_domain() from public, anon, authenticated;

drop trigger if exists enforce_fast_email_domain on auth.users;
create trigger enforce_fast_email_domain
  before insert on auth.users
  for each row
  execute function private.enforce_fast_email_domain();
