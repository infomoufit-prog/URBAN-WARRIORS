-- Urban Warriors RC13 build 20018 · preflight 034. SOLO LECTURA.
-- Resultado requerido: todos los controles = true.
select * from (values
  ('gateway_033',to_regprocedure('public.app_mutate_v160_pre_events_033(text,jsonb,uuid)') is not null),
  ('contrato_033',to_regprocedure('public.app_runtime_contract_v160_pre_events_033(uuid)') is not null),
  ('eventos_033',to_regclass('public.eventos_competicion') is not null),
  ('notificaciones',to_regclass('public.notificaciones') is not null),
  ('lecturas',to_regclass('public.notificaciones_lecturas') is not null),
  ('marcar_lectura',to_regprocedure('public.app_marcar_notificacion_leida(uuid)') is not null),
  ('idempotencia',to_regclass('public.app_mutation_requests') is not null),
  ('preinscripciones',to_regclass('public.preinscripciones') is not null),
  ('material_pedidos',to_regclass('public.material_pedidos') is not null),
  ('pagos',to_regclass('public.pagos') is not null),
  ('cuotas',to_regclass('public.cuotas') is not null),
  ('columnas_notificacion',not exists(
    select 1 from (values('club_id'),('perfil_id'),('rol_destino'),('audiencia'),('tipo'),('datos'),('ruta'),('leida')) v(col)
    where not exists(select 1 from pg_attribute a where a.attrelid=to_regclass('public.notificaciones') and a.attname=v.col and a.attnum>0 and not a.attisdropped)
  ))
) x(control,ok) order by control;
