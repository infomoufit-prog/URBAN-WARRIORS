-- Restaura el motor de avisos anterior sin modificar historial ni cargos.

begin;
do $rollback$
declare v_definition text;
begin
  if to_regprocedure('public.procesar_avisos_cobro_pre_material_026(date,uuid)') is null then
    raise exception 'Rollback 026 no disponible';
  end if;
  select pg_get_functiondef('public.procesar_avisos_cobro_pre_material_026(date,uuid)'::regprocedure) into v_definition;
  v_definition:=regexp_replace(v_definition,
    'CREATE OR REPLACE FUNCTION public\.procesar_avisos_cobro_pre_material_026\(',
    'CREATE OR REPLACE FUNCTION public.procesar_avisos_cobro(');
  execute v_definition;
end
$rollback$;
revoke all on function public.procesar_avisos_cobro(date,uuid) from public,anon,authenticated;
grant execute on function public.procesar_avisos_cobro(date,uuid) to service_role;
commit;
