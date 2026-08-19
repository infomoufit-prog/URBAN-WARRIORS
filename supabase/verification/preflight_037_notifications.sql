select '034 instalada' control,case when to_regprocedure('public.app_notificacion_requiere_accion_v034(uuid)') is not null then 'OK' else 'FALLO' end estado;
select 'lecturas' control,case when to_regclass('public.notificaciones_lecturas') is not null then 'OK' else 'FALLO' end estado;
select 'gateway' control,case when to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then 'OK' else 'FALLO' end estado;
