-- Rollback de 023_restore_rc10_gateway_v166.sql
-- Restaura el gateway que estaba activo justo antes de ejecutar 023.

begin;

do $rollback$
declare
  v_previous_definition text;
begin
  if to_regprocedure('public.app_mutate_v160_pre_restore_023(text,jsonb,uuid)') is null then
    raise exception 'ROLLBACK 023: no existe el punto de retorno';
  end if;

  select pg_get_functiondef(
    'public.app_mutate_v160_pre_restore_023(text,jsonb,uuid)'::regprocedure
  ) into v_previous_definition;

  v_previous_definition:=regexp_replace(
    v_previous_definition,
    'CREATE OR REPLACE FUNCTION public\.app_mutate_v160_pre_restore_023\(',
    'CREATE OR REPLACE FUNCTION public.app_mutate_v160('
  );
  execute v_previous_definition;
end
$rollback$;

revoke all on function public.app_mutate_v160(text,jsonb,uuid)
  from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid)
  to authenticated;

commit;
