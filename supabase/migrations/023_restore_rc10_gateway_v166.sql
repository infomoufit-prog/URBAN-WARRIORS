-- 023_restore_rc10_gateway_v166.sql
-- Recupera el gateway RC10 preservado por PostgreSQL sin modificar datos.

begin;

do $migration$
declare
  v_active_definition text;
  v_rc10_definition text;
begin
  if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then
    raise exception '023: no existe el gateway activo app_mutate_v160';
  end if;
  if to_regprocedure('public.app_mutate_v160_v166(text,jsonb,uuid)') is null then
    raise exception '023: no existe el gateway RC10 preservado app_mutate_v160_v166';
  end if;

  select pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure)
    into v_active_definition;
  select pg_get_functiondef('public.app_mutate_v160_v166(text,jsonb,uuid)'::regprocedure)
    into v_rc10_definition;

  if strpos(v_rc10_definition,'notificacion.leer_grupo')=0
     or strpos(v_rc10_definition,'notificacion.leer_todas')=0
     or strpos(v_rc10_definition,'notificaciones.preferencias')=0
     or strpos(v_rc10_definition,'comunidad.publicar')=0 then
    raise exception '023: la función v166 no contiene el contrato RC10 esperado';
  end if;

  -- Punto de rollback: conserva exactamente la función activa anterior.
  v_active_definition:=regexp_replace(
    v_active_definition,
    'CREATE OR REPLACE FUNCTION public\.app_mutate_v160\(',
    'CREATE OR REPLACE FUNCTION public.app_mutate_v160_pre_restore_023('
  );
  execute v_active_definition;

  -- Promueve la copia RC10 ya instalada al nombre público estable.
  v_rc10_definition:=regexp_replace(
    v_rc10_definition,
    'CREATE OR REPLACE FUNCTION public\.app_mutate_v160_v166\(',
    'CREATE OR REPLACE FUNCTION public.app_mutate_v160('
  );
  execute v_rc10_definition;

  if strpos(pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure),'notificacion.leer_todas')=0 then
    raise exception '023: la promoción del gateway RC10 no se pudo verificar';
  end if;
end
$migration$;

revoke all on function public.app_mutate_v160_pre_restore_023(text,jsonb,uuid)
  from public,anon,authenticated;
revoke all on function public.app_mutate_v160(text,jsonb,uuid)
  from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid)
  to authenticated;

commit;

select * from public.app_diagnostico_instalacion_v166();
