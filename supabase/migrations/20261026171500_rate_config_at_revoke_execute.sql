-- Follow-up to 20261026164500.
--
-- `revoke all on function ... from public` does NOT remove the EXECUTE that
-- Supabase's default privileges grant to anon and authenticated by name.
-- rate_config_at is SECURITY DEFINER and returns the whole rate row, so it
-- was callable over PostgREST by any anonymous visitor -- exposing the
-- client-side commission rate the talent is never meant to see.

revoke execute on function public.rate_config_at(timestamptz) from anon, authenticated;
revoke execute on function public.rate_configs_append_only() from anon, authenticated;
