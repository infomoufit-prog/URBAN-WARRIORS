-- Read-only verification for R110 Pilot Club activation.
select public.app_kombax_pilot_registration_window_r110() as pilot_window;

select count(*) filter(where subject_type='club') as pilot_clubs
from kombax_commercial.pilot_entities_r97;

select c.relname,
       c.relrowsecurity as rls_enabled,
       has_table_privilege('anon',c.oid,'SELECT,INSERT,UPDATE,DELETE') as anon_dml,
       has_table_privilege('authenticated',c.oid,'SELECT,INSERT,UPDATE,DELETE') as authenticated_dml
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='kombax_commercial'
  and c.relname in ('pilot_club_activations_r110','pilot_club_invites_r110')
order by c.relname;

select p.oid::regprocedure::text as signature,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute,
       p.prosecdef as security_definer,
       p.proconfig
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in (
    'app_kombax_pilot_invite_create_r110',
    'app_kombax_pilot_registration_window_r110',
    'app_kombax_pilot_club_activate_r110',
    'app_kombax_pilot_metrics_r97'
  )
order by p.proname;
