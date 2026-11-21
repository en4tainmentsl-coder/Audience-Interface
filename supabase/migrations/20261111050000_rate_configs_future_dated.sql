-- Rate changes must be future-dated so a mistaken row can be superseded
-- before it ever prices a quote. rate_configs is append-only in both
-- directions: a wrong row cannot be edited or deleted by anyone.

create or replace function public.rate_configs_future_dated()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(current_setting('en4.admin_override', true), '') = 'on' then
    return new;
  end if;

  if new.effective_from < now() + interval '48 hours' then
    raise exception
      'A rate configuration must take effect at least 48 hours from now. Earliest permitted: %. Given: %.',
      (now() + interval '48 hours'), new.effective_from
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke execute on function public.rate_configs_future_dated() from public, anon, authenticated;

create trigger rate_configs_future_dated_only
  before insert on public.rate_configs
  for each row execute function public.rate_configs_future_dated();

alter table public.rate_configs
  alter column effective_from set default (now() + interval '48 hours');

comment on trigger rate_configs_future_dated_only on public.rate_configs is
  'Rate changes are future-dated by at least 48 hours. rate_configs cannot be edited or deleted, so this window is the only correction route: supersede the wrong row before it takes effect. Bypass with: begin; set local en4.admin_override = ''on''; insert ...; commit;';