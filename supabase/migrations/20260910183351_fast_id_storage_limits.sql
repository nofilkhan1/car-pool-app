-- Enforce the ID-card upload contract at the Storage bucket level.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fast-id-cards', 'fast-id-cards', false, 51200, array['image/jpeg','image/png']::text[])
on conflict (id) do update set
  public = false,
  file_size_limit = 51200,
  allowed_mime_types = array['image/jpeg','image/png']::text[];
