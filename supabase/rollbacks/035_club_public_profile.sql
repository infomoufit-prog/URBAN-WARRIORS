-- Rollback 035: restaura gateway/contrato 034 y elimina objetos propios de 035.
begin;
drop trigger if exists clubes_seed_perfil_publico_v035 on public.clubes;
drop function if exists public.app_seed_perfil_club_publico_v035();
drop function if exists public.app_buscar_identidades_publicas_v035(uuid,text,integer);
drop function if exists public.app_perfil_club_publico_v035(uuid);
drop function if exists public.app_puede_gestionar_perfil_club_v035(uuid);
drop table if exists public.perfiles_club_publicos;
drop function if exists public.app_mutate_v160(text,jsonb,uuid);
do $$ begin if to_regprocedure('public.app_mutate_v160_pre_club_profile_035(text,jsonb,uuid)') is not null then alter function public.app_mutate_v160_pre_club_profile_035(text,jsonb,uuid) rename to app_mutate_v160; end if; end $$;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;
drop function if exists public.app_runtime_contract_v160(uuid);
do $$ begin if to_regprocedure('public.app_runtime_contract_v160_pre_club_profile_035(uuid)') is not null then alter function public.app_runtime_contract_v160_pre_club_profile_035(uuid) rename to app_runtime_contract_v160; end if; end $$;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
