-- Rollback conservador 032: restaura gateway y conserva datos sociales creados.
begin;
do $rollback$
begin
  if to_regprocedure('public.app_mutate_v160_pre_social_032(text,jsonb,uuid)') is not null then
    drop function if exists public.app_mutate_v160(text,jsonb,uuid);
    alter function public.app_mutate_v160_pre_social_032(text,jsonb,uuid) rename to app_mutate_v160;
    grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;
  end if;
end
$rollback$;
do $rollback_contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_social_032(uuid)') is not null then
    drop function if exists public.app_runtime_contract_v160(uuid);
    alter function public.app_runtime_contract_v160_pre_social_032(uuid) rename to app_runtime_contract_v160;
    grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;
  end if;
end
$rollback_contract$;
-- Se cierran las nuevas mutaciones dejando las tablas intactas para no perder datos.
revoke execute on function public.app_puede_ver_perfil_deportivo_v032(uuid,uuid) from authenticated;
revoke execute on function public.app_perfiles_deportivos_publicos_v032(uuid,uuid) from authenticated;
revoke insert,update,delete on public.perfiles_deportivos from authenticated;
revoke insert,update,delete on public.comunidad_likes from authenticated;
notify pgrst,'reload schema';
commit;
