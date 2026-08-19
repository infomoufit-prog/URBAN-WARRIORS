select 'centro v037' control,case when to_regprocedure('public.app_notificaciones_centro_v037(uuid,integer)') is not null then 'OK' else 'FALLO' end estado;
select 'RLS lecturas' control,case when exists(select 1 from pg_class where oid='public.notificaciones_lecturas'::regclass and relrowsecurity) then 'OK' else 'FALLO' end estado;
select 'índice v037' control,case when to_regclass('public.idx_notificaciones_lecturas_notificacion_perfil_v037') is not null then 'OK' else 'FALLO' end estado;
