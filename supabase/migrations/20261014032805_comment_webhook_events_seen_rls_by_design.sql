COMMENT ON TABLE public.webhook_events_seen IS
'Internal idempotency ledger for inbound webhooks. Written and read only via service_role. RLS is enabled with NO policies deliberately: that is the intended deny-all for anon and authenticated, not an oversight. The Supabase linter reports this as INFO rls_enabled_no_policy (0008) - expected, do not "fix" by adding a policy.';
