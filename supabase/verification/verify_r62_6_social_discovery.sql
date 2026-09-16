-- KOMBAX R62.6 · Social Discovery verification
-- Read-only verification. Run authenticated runtime QA separately for actual contact/search flows.

select count(*) = 10 as fighter_columns_ok
from information_schema.columns
where table_schema='public' and table_name='kombax_fighter_discovery_v221'
  and column_name in ('availability_status','availability_reason','availability_public','accepts_short_notice','fight_count_declared','wins_declared','losses_declared','draws_declared','affiliation_status','availability_updated_at');

select to_regclass('public.kombax_professional_discovery_r626') is not null as professional_discovery_ok,
       to_regclass('public.kombax_discovery_availability_slots_r626') is not null as optional_slots_ok;

select p.proname,
       p.prosecdef as security_definer,
       p.proconfig,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in (
    'app_kombax_discovery_search_r626',
    'app_kombax_discovery_profile_r626',
    'app_kombax_discovery_mutate_r626',
    'app_kombax_discovery_slots_r626',
    'app_kombax_discovery_slot_mutate_r626',
    'app_kombax_discovery_public_profile_r626'
  )
order by p.proname;

select relname, relrowsecurity
from pg_class
where oid in ('public.kombax_professional_discovery_r626'::regclass,'public.kombax_discovery_availability_slots_r626'::regclass);

select 'PRIVATE_AGENDA_NOT_REFERENCED' as check_name,
       bool_and(position('kombax_professional_availability_v198' in pg_get_functiondef(p.oid))=0) as ok
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname like 'app_kombax_discovery%r626';
