# KOMBAX · Monitoring Runbook · build 20077

## Alcance del piloto

Monitorización mínima para el piloto controlado de **2 clubes**. No sustituye un servicio externo de observabilidad ni una guardia 24/7. El objetivo es detectar con rapidez indisponibilidad, fallos de jobs, errores de Auth/Edge y regresiones críticas sin exponer datos personales.

Responsable operativo primario: **BRYAN RIVERA GREY**  
Canal de seguridad/alerta: **seguridad@kombax.es**  
Canal general: **soporte@kombax.es**  
Child Safety: **childsafety@kombax.es**

No se publica ni se inventa un teléfono o suplente mientras no exista un dato operativo real aprobado.

## Endpoint de salud backend

Edge Function pública: `/functions/v1/health` del proyecto Supabase KOMBAX.

Contrato esperado:

- HTTP `200` cuando Edge + PostgREST/DB responden.
- JSON mínimo: `ok`, `status`, `build`, `db`, `checked_at`.
- `build` debe ser **20077** durante este piloto.
- HTTP `503` cuando el chequeo de base de datos falla.
- No devuelve claves, errores internos, usuarios, tablas privadas ni detalles sensibles.

Evidencia 2026-08-24: **HTTP 200 · build 20077 · db ok** en Supabase real.

## Jobs y cron

Comprobar en Supabase:

- `urban-warriors-notification-dispatch`: cada 10 minutos. Umbral de alerta: sin ejecución exitosa durante **25 minutos** o cualquier serie de 2 fallos consecutivos.
- `urban-warriors-payment-reminders`: minuto 5 de cada hora. Umbral de alerta: sin ejecución exitosa durante **90 minutos** o 2 fallos consecutivos.
- `kombax-data-lifecycle-daily-v133`: 02:20 UTC diario. Umbral de alerta tras su primera ventana real: ausencia de ejecución exitosa durante **36 horas** o cualquier fallo de mantenimiento.

Evidencia 2026-08-24: notification-dispatch y payment-reminders muestran ejecuciones repetidas exitosas. El lifecycle está activo y programado, pero fue creado después de la ventana diaria y aún debe certificar su primera ejecución programada.

## Auth, Edge y telemetría

Revisión diaria durante el piloto:

1. Auth logs: errores 5xx, picos 429, fallos SMTP y patrones de refresh token anómalos.
2. Edge logs: cualquier 5xx; 401 aislados se clasifican como control de acceso si proceden de llamadas no autenticadas.
3. `kombax_client_incidents_v117`: revisar incidencias nuevas y agrupar por `codigo`/build. La telemetría cliente redacta secretos y limita repetición.
4. Advisors de Security/Performance: revisar cambios, no solo el recuento bruto.

Evidencia 2026-08-24: **0 incidencias cliente registradas**, health 200, jobs principales 200. Existe un 401 de `invite-email` por llamada no autenticada y se considera comportamiento defensivo esperado.

## Rutina piloto

Durante los primeros 7 días:

- Inicio de jornada: health + cron + Auth/Edge logs + incidencias cliente.
- Fin de jornada: repetir health/cron y registrar cualquier S1/S2/S3.
- Tras cualquier despliegue autorizado: health, login, recuperación, una lectura multiclub y una acción no destructiva Owner.
- Tras cualquier cambio Supabase: advisors Security/Performance y revisión de funciones/grants afectados.

## Alertas externas

**Pendiente de configuración externa.** El monitor debe ser independiente de Supabase para detectar también una caída total del proveedor. Cuando `kombax.es` esté desplegado y autorizado:

1. Monitor HTTPS de `https://kombax.es`.
2. Monitor HTTPS de `/functions/v1/health`.
3. Alerta a `seguridad@kombax.es` tras 2 fallos consecutivos; recuperación también notificada.
4. No incluir datos personales, tokens, cuerpos de error internos ni parámetros de usuario en la alerta.

Hasta activar ese monitor, el piloto solo puede considerarse monitorizado mediante revisión operativa manual y logs del proveedor.

## Respuesta

- Web KO + health OK: revisar Netlify/DNS/certificado/frontend.
- Web OK + health 503: revisar Supabase Edge/PostgREST/DB.
- Ambos KO: comprobar DNS/conectividad/proveedores y activar `INCIDENT_RESPONSE_RUNBOOK_20070.md`.
- Error de permisos, aislamiento o posible fuga: **S1**; contener de inmediato y preservar evidencia mínima.
- Incidente que implique menores/CSAM/CSAE: aplicar además `CHILD_SAFETY_RESPONSE_RUNBOOK_20071.md`.

## Estado 20077

- Health build 20077: **PASS**.
- DB/Edge comprobados: **PASS**.
- notification-dispatch/payment-reminders: **PASS operativo**.
- lifecycle cron: **PENDIENTE primera ejecución programada**.
- Telemetría cliente: **PASS técnica; 0 incidentes actuales**.
- Monitor externo independiente: **REQUIERE CONFIGURACIÓN antes de producción general; aceptable como condición explícita de piloto de 2 clubes con revisión manual diaria**.
