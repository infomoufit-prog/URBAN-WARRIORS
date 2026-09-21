-- Rollback conservador 033: restaura gateway 032 y conserva eventos/participantes/combates.
begin;
do $rollback$
begin
  if to_regprocedure('public.app_mutate_v160_pre_events_033(text,jsonb,uuid)') is not null then
    drop function if exists public.app_mutate_v160(text,jsonb,uuid);
    alter function public.app_mutate_v160_pre_events_033(text,jsonb,uuid) rename to app_mutate_v160;
    grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;
  end if;
end
$rollback$;
do $rollback_contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_events_033(uuid)') is not null then
    drop function if exists public.app_runtime_contract_v160(uuid);
    alter function public.app_runtime_contract_v160_pre_events_033(uuid) rename to app_runtime_contract_v160;
    grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;
  end if;
end
$rollback_contract$;
revoke execute on function public.app_evento_participantes_visibles_v033(uuid,uuid) from authenticated;
revoke execute on function public.app_evento_combates_visibles_v033(uuid,uuid) from authenticated;
revoke insert,update,delete on public.eventos_competicion from authenticated;
revoke insert,update,delete on public.evento_participantes from authenticated;
revoke insert,update,delete on public.evento_combates from authenticated;
notify pgrst,'reload schema';
commit;
