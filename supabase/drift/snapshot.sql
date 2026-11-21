-- Catalog snapshot of the public schema, one row per object: (kind, key, value).
-- Run the SAME query against two databases and compare the output with
-- compare.py. See README.md in this directory.
--
-- Read-only. Directus's own tables (directus_*) are excluded: they live in
-- public on production but are created by Directus, not by this history.
with ns as (select oid from pg_namespace where nspname='public'),
rel as (select c.* from pg_class c, ns where c.relnamespace=ns.oid and c.relname not like 'directus\_%'),
s as (
 select 'policy' k, tablename||'.'||policyname key, concat_ws('|',cmd,permissive,roles::text,qual,with_check) val from pg_policies where schemaname='public' and tablename not like 'directus\_%'
 union all select 'rls', relname, relrowsecurity::text||'|'||relforcerowsecurity::text from rel where relkind in ('r','p')
 union all select 'relation', relname, relkind::text from rel where relkind in ('r','p','v','m','S')
 union all select 'column', r.relname||'.'||a.attname, concat_ws('|',format_type(a.atttypid,a.atttypmod),a.attnotnull::text,coalesce(pg_get_expr(d.adbin,d.adrelid),'-'),a.attgenerated::text,a.attidentity::text)
   from rel r join pg_attribute a on a.attrelid=r.oid and a.attnum>0 and not a.attisdropped left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where r.relkind in ('r','p')
 union all select 'constraint', r.relname||'.'||c.conname, pg_get_constraintdef(c.oid) from pg_constraint c join rel r on r.oid=c.conrelid
 union all select 'index', i.indexname, i.indexdef from pg_indexes i where i.schemaname='public' and i.tablename not like 'directus\_%'
 union all select 'trigger', r.relname||'.'||t.tgname, pg_get_triggerdef(t.oid)||'|'||t.tgenabled::text from pg_trigger t join rel r on r.oid=t.tgrelid where not t.tgisinternal
 union all select 'function', p.proname||'('||pg_get_function_identity_arguments(p.oid)||')', concat_ws('|',md5(lower(regexp_replace(regexp_replace(p.prosrc,'--[^\n]*','','g'),'\s+','','g'))),p.prosecdef::text,coalesce(p.proconfig::text,'-'),p.provolatile::text,pg_get_function_result(p.oid),l.lanname)
   from pg_proc p join ns on p.pronamespace=ns.oid join pg_language l on l.oid=p.prolang where not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e')
 union all select 'functext', p.proname||'('||pg_get_function_identity_arguments(p.oid)||')', md5(p.prosrc)
   from pg_proc p join ns on p.pronamespace=ns.oid where not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e')
 union all select 'funcacl', p.proname||'('||pg_get_function_identity_arguments(p.oid)||')', coalesce((select string_agg(split_part(x,'/',1),',' order by split_part(x,'/',1)) from unnest(p.proacl::text[]) x where split_part(x,'=',1) not in ('supabase_admin','dashboard_user')),'NULLACL')
   from pg_proc p join ns on p.pronamespace=ns.oid where not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e')
 union all select 'view', relname, pg_get_viewdef(oid)||'|'||coalesce(reloptions::text,'-') from rel where relkind in ('v','m')
 union all select 'enum', t.typname, (select string_agg(e.enumlabel,',' order by e.enumsortorder) from pg_enum e where e.enumtypid=t.oid) from pg_type t, ns where t.typnamespace=ns.oid and t.typtype='e'
 union all select 'relacl', relname, coalesce((select string_agg(split_part(x,'/',1),',' order by split_part(x,'/',1)) from unnest(relacl::text[]) x where split_part(x,'=',1) not in ('supabase_admin','dashboard_user')),'NULLACL') from rel where relkind in ('r','p','v','m','S')
 union all select 'colacl', r.relname||'.'||a.attname, (select string_agg(split_part(x,'/',1),',' order by split_part(x,'/',1)) from unnest(a.attacl::text[]) x) from rel r join pg_attribute a on a.attrelid=r.oid where a.attacl is not null and not a.attisdropped
 union all select 'cron', jobname, schedule||'|'||command from cron.job
)
select k, key, val from s order by k, key;
