-- SALUD BACKEND PREVIA A APK. SOLO LECTURA.
-- Ejecutar después de 029, 030 y las Edge Functions.

-- 1) Dispositivos Android: no muestra tokens.
select
  club_id,
  count(*) filter(where plataforma='android') as android_total,
  count(*) filter(where plataforma='android' and activo) as android_activos,
  max(ultimo_uso) filter(where plataforma='android') as ultimo_android
from public.dispositivos_push
group by club_id
order by club_id;

-- 2) Cola push e incidencias recientes: no muestra contenido sensible.
select
  club_id,
  count(*) filter(where push_enviado_en is null and push_intentos<5) as pendientes,
  count(*) filter(where push_enviado_en is not null) as enviados,
  count(*) filter(where push_intentos>=5 and push_enviado_en is null) as agotados,
  max(creado_en) as ultima_notificacion
from public.notificaciones
where creado_en>=now()-interval '14 days'
group by club_id
order by club_id;

-- 3) Configuración del motor de avisos.
select
  club_id,activo,dias_aviso,hora_envio,zona_horaria,canal_app,canal_push,
  cardinality(dias_aviso)=5
    and 0<all(dias_aviso)
    and 29>all(dias_aviso) as configuracion_valida
from public.configuracion_avisos_cuota
order by club_id;

-- 4) Duplicados de avisos: resultado esperado, 0 filas.
select club_id,cuota_id,perfil_id,aviso_numero,canal,count(*) as duplicados
from public.historial_avisos_cuota
group by club_id,cuota_id,perfil_id,aviso_numero,canal
having count(*)>1;

-- 5) Auditoría tenant: cada fila debe ser true / true / true / false.
select * from public.app_multiclub_audit_v030();
