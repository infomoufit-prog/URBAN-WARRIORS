-- Rollback 034: restaura gateway/contrato 033 y elimina solo objetos propios de 034.
begin;
drop function if exists public.app_notificaciones_accionables_v034(uuid);
drop function if exists public.app_notificacion_requiere_accion_v034(uuid);
drop table if exists public.notificaciones_revisiones;
drop function if exists public.app_mutate_v160(text,jsonb,uuid);
do $$ begin
  if to_regprocedure('public.app_mutate_v160_pre_notifications_034(text,jsonb,uuid)') is not null then
    alter function public.app_mutate_v160_pre_notifications_034(text,jsonb,uuid) rename to app_mutate_v160;
  end if;
end $$;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;
drop function if exists public.app_runtime_contract_v160(uuid);
do $$ begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_notifications_034(uuid)') is not null then
    alter function public.app_runtime_contract_v160_pre_notifications_034(uuid) rename to app_runtime_contract_v160;
  end if;
end $$;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
