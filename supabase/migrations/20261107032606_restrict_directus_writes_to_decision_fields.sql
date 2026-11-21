-- Restrict Directus-originated writes to review decision fields only.
-- Directus connects as nocobase_admin with no Supabase JWT, so auth.uid() is NULL
-- and the existing *_trust_fields guards never fire for it. This binds on the
-- database role instead, which is the one thing Postgres can see.
-- Column-level permissions are a licensed Directus feature not available on this
-- edition, so the restriction cannot live in the panel.

create or replace function public.enforce_directus_column_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  allowed text[] := tg_argv[0]::text[];
  changed text[] := '{}';
  k text;
begin
  if current_user <> 'nocobase_admin' then
    return new;
  end if;

  for k in select jsonb_object_keys(to_jsonb(new)) loop
    if (to_jsonb(old) -> k) is distinct from (to_jsonb(new) -> k)
       and not (k = any(allowed)) then
      changed := changed || k;
    end if;
  end loop;

  if array_length(changed, 1) > 0 then
    raise exception
      'Directus may only update review decision fields on %. Rejected: %',
      tg_table_name, array_to_string(changed, ', ')
      using errcode = '42501',
            hint = 'Content edits go through the app, not the admin panel.';
  end if;

  return new;
end;
$$;

drop trigger if exists z_directus_column_scope on public.profiles_talent;
create trigger z_directus_column_scope
before update on public.profiles_talent
for each row execute function public.enforce_directus_column_scope(
  '{approval_status,is_verified,is_public,profile_status,reviewed_by,reviewed_at,rejection_reason,rejection_note,base_latitude,base_longitude,updated_at}');

drop trigger if exists z_directus_column_scope on public.profiles_venues;
create trigger z_directus_column_scope
before update on public.profiles_venues
for each row execute function public.enforce_directus_column_scope(
  '{approval_status,is_verified,updated_at}');

drop trigger if exists z_directus_column_scope on public.profiles_clients;
create trigger z_directus_column_scope
before update on public.profiles_clients
for each row execute function public.enforce_directus_column_scope(
  '{approval_status,updated_at}');

drop trigger if exists z_directus_column_scope on public.talent_identity;
create trigger z_directus_column_scope
before update on public.talent_identity
for each row execute function public.enforce_directus_column_scope(
  '{kyc_status,verified_by,verified_at,updated_at}');

-- Match the ACL convention of the other trigger functions: EXECUTE revoked
-- from PUBLIC, anon and authenticated, leaving postgres and service_role.
revoke execute on function public.enforce_directus_column_scope() from public, anon, authenticated;
