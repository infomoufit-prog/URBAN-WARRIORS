# KOMBAX R114 — Pilot Master Performance, Scalability & Operations Audit

Fecha: 2026-10-01  
Baseline congelada: KOMBAX R113  
Baseline SHA-256: `63f4ed73777179f8dcefcf84d6c3476e59e0b70eb6f7e1797459b790969ec2a8`  
Release candidata: `2.0.0-rc.13-r114-owner-command-center-performance`  
Build: `20167`

## 1. Estado general

**Apto con observaciones para validación de piloto.**

La intervención preserva la arquitectura existente y aplica únicamente cambios aditivos o localizados. El gate de release del propio proyecto finaliza con **56 suites PASS, 7 P2 históricos conocidos y 0 fallos nuevos**. El build sincroniza **619 archivos** entre `web`, `dist` y los assets Android.

La aptitud operacional final requiere todavía validaciones externas que no pueden demostrarse desde el ZIP: migración R114 aplicada en el proyecto Supabase enlazado, despliegue de las Edge Functions modificadas/nuevas, entrega push en dispositivos físicos, firma Android local y medición real de Web Vitals/red sobre el despliegue.

## 2. Baseline / freeze

- R113 se preservó sin modificación en una copia separada.
- La intervención se realizó sobre copia R114.
- No se cambió framework, proveedor, modelo comercial, identidad, RLS ni arquitectura de tenants.
- No se reconstruyeron Social, Showcase, Events, Mi Club, Owner, agentes IA ni notificaciones.
- Se mantuvo la regla `1 correo = 1 cuenta = 1 identidad principal` y la continuidad de Competidor/Practicante existente.

## 3. Rendimiento de arranque — evidencia estática

Se midió el grafo de imports ES **síncronos** alcanzable desde `web/js/app.js`.

| Métrica | R113 | R114 | Diferencia |
|---|---:|---:|---:|
| módulos síncronos alcanzables | 107 | 99 | -8 |
| bytes fuente JS en el grafo síncrono | 4.940.145 | 4.253.738 | -686.407 (-13,9 %) |

Cambios aplicados:

- Social pasa a carga dinámica por ruta.
- Showcase pasa a carga dinámica por ruta.
- Events pasa a carga dinámica por ruta.
- Owner pasa a carga dinámica tras el gate de acceso.
- Assist/Migrations/Support se difieren desde el router principal.
- Gateway deja de fijar Social/Showcase/Events en el grafo inicial.

**NO VALIDADO:** FCP, LCP, INP, TTFB y tiempo real hasta interacción. Esas métricas requieren navegador/red/despliegue real y no se inventan.

## 4. Multimedia

La release conserva las optimizaciones y tests existentes, incluido el gate R55 de presupuesto multimedia. En la regresión R114 el test conserva:

- presupuesto físico worst-case inferior al límite del test;
- reducción teórica >20x por thumbnails en grids;
- carga lazy de imágenes de Fight Card/player;
- `metadata preload` para vídeo;
- paginación de participantes.

No se ejecutó migración multimedia masiva ni reprocesado de biblioteca.

**P2:** medir egress real, hit-rate de caché y pesos transferidos en Social/Showcase/Events sobre el despliegue con contenido real.

## 5. Owner Command Center — mejora aplicada

Owner ya existía y se ha preservado. R114 añade una capa operativa encima del Owner actual:

- centro de alertas Owner globales;
- contadores de alertas sin leer, acción requerida, críticas, warning y push pendiente;
- alertas directas por nuevas verificaciones;
- alertas al Owner solicitante cuando una ejecución de agente falla o entrega resultado de riesgo alto/crítico;
- métricas por periodo 30/90/180/365 días;
- gráfico interactivo de series agregadas;
- filtro y ordenación de tabla de clubes con mayor actividad;
- exportación CSV de métricas agregadas;
- informe PDF privado de Owner con KPIs, gráfico de tendencia y tabla de actividad;
- enlaces firmados de 10 minutos para informes almacenados en bucket privado.

Las tablas y gráficos no requieren descargar datasets completos de miembros al navegador: reutilizan agregaciones server-side ya existentes.

## 6. Agentes SaaS / IA Owner

Se conserva la arquitectura de agentes existente. R114 **no concede nuevas acciones autónomas sensibles**.

Se añade supervisión operacional:

- fallos y resultados high/critical generan alerta persistente para el Owner solicitante;
- la alerta puede producir push mediante el dispatcher existente;
- se preservan logs/turns existentes;
- el informe Owner incluye ejecución total, completadas, fallidas, high-risk y distribución de agentes.

**P2 / post-piloto:** un kill switch global de agentes no se ha creado porque R113 no opera como daemon autónomo continuo; introducir un nuevo sistema de ejecución/suspensión en esta fase sería arquitectura nueva y aumentaría riesgo.

## 7. Notificaciones internas y push

### Hallazgo P1 corregido

El dispatcher filtraba siempre `dispositivos_push` por `club_id`. Una notificación Owner global usa `club_id = null`, por lo que no podía resolver dispositivos del Owner aunque la notificación interna existiera.

Corrección R114:

- para notificaciones con `club_id`, se mantiene aislamiento por club;
- para alertas Owner globales, no se exige `club_id` al resolver los dispositivos del perfil destinatario;
- se deduplican tokens idénticos antes del envío;
- no se cambia la fuente persistente: la notificación interna sigue existiendo aunque falle push.

La regresión `RC13 NOTIFICATIONS 20020` pasa completa.

**NO VALIDADO:** entrega real FCM en app abierta, background, cerrada, PWA y Android físico. Requiere dispositivos/credenciales/servicios externos desplegados.

## 8. Verificaciones

R114 añade un trigger aditivo sobre `kombax_solicitudes_alta`: una nueva transición a `submitted` crea una alerta Owner global idempotente con `requiere_accion=true`. No cambia el proceso de aprobación/rechazo ni las reglas de verificación.

## 9. Informes Owner

Nueva función privada `kombax-owner-report-r114`:

- exige JWT;
- llama a un RPC Owner protegido;
- usa métricas agregadas de plataforma;
- incorpora contadores de alertas y agentes;
- genera PDF A4 de dos páginas;
- añade gráfico de sesiones por día;
- añade top de clubes por actividad;
- no incluye detalle identificativo de miembros;
- sube al bucket privado `kombax-reports`;
- entrega signed URL de 600 segundos;
- devuelve SHA-256 del PDF generado.

**NO VALIDADO:** ejecución remota real antes de aplicar migración/desplegar función.

## 10. Supabase / PostgreSQL

Nueva migración aditiva: `300_kombax_owner_command_center_r114.sql`.

Incluye:

- índice único parcial para claves de notificación Owner globales;
- RPC `app_kombax_owner_alerts_r114`;
- RPC `app_kombax_owner_report_payload_r114`;
- trigger de alertas de verificaciones;
- trigger de alertas de agentes.

No se desactiva ni relaja RLS. Los RPC Owner validan `app_kombax_es_platform_admin_v055()`.

**NO VALIDADO:** `EXPLAIN ANALYZE` contra la base remota y aplicación de la migración en el entorno enlazado.

## 11. RLS / aislamiento / Multiclub

No se modifican policies de RLS ni la regla Multiclub. El cambio de push conserva el filtro por club para notificaciones tenant-scoped. Solo las notificaciones globales directas al perfil Owner omiten el filtro de club.

## 12. Social / Discovery / Competidores

No se recrean. El gate R76 Social Discovery pasa 10/10 y se preservan las reglas de privacidad/búsqueda de competidores existentes. R114 mejora el coste de arranque al no cargar estos módulos hasta su ruta.

## 13. Showcase / Events / Mi Club

No se alteran reglas comerciales ni flujos. Los gates R77 Analytics/Reports pasan 24/24 y R55 media-load 5/5. Showcase y Events pasan a import dinámico desde el router inicial.

## 14. Android / PWA

- Build Android: `20167`.
- `web = dist = Android`: 619 archivos verificados por SHA-256 durante build.
- Android preflight: **7/8**.
- Único pendiente: firma local (`android/keystore.properties` o variables `UW_*`).
- No se empaquetan claves privadas.

## 15. I18N

Los ocho locales contienen el catálogo maestro completo.

El gate R79 estricto sigue señalando deuda legacy, ya existente en la baseline:

- R113: 255 unresolved.
- R114: 249 unresolved.

R114 **no aumenta** la deuda y reduce 6 coincidencias. `i18n-validate` sigue señalando el hardcode regional histórico de `customer-operations.js`, igual que R113.

## 16. QA ejecutado

Confirmado:

- `npm run pretest`: PASS.
- R114 Owner Command Center/performance: 12/12 PASS.
- R113 profile editor save: 12/12 PASS.
- R112 free public identity: 12/12 PASS.
- R105 Owner Agents: PASS.
- R106 Owner Document Inbox: 17 PASS.
- RC13 Notifications Actionable: PASS.
- R77 Premium Analytics/Reports: 24/24 PASS.
- R76 Social Discovery Premium: 10/10 PASS.
- R55 Events load budget: 5/5 PASS.
- `npm run release:legal-gate`: PASS.
- `npm run release:build`: **56 PASS, 7 P2 históricos, 0 fallos nuevos**.
- local server HTTP: `/` = 200; `/js/app.js` = 200.
- build determinista: 619 archivos `web = dist = Android`.

P2 históricos aceptados por el gate del proyecto:

1. R79 full product audit.
2. R79 phases 6–10 legacy expectation.
3. runtime copy audit.
4. i18n validate regional hardcode histórico.
5. i18n B02 histórico.
6. R72 commercial continuity (14/18 también en R113).
7. R72 identity/spectator legacy expectation.

## 17. Hallazgos clasificados

### P0

No se ha demostrado un P0 nuevo introducido por R114.

### P1 corregidos

1. Push Owner global incompatible con filtro obligatorio `club_id`.
2. Carga síncrona inicial innecesaria de módulos grandes por rutas no visitadas.
3. Falta de una superficie Owner unificada de alertas/periodos/export/report sobre capacidades ya existentes.

### P2

- deuda I18N legacy ya existente;
- medición Web Vitals real;
- pruebas de carga/EXPLAIN con datasets remotos;
- auditoría económica de egress/storage bajo tráfico real;
- posibles mejoras adicionales de fragmentación del gran catálogo I18N;
- observabilidad externa de producción más profunda;
- automatización adicional de agentes solo tras política explícita de acciones autorizadas.

### P3

- refactors amplios de UI/arquitectura;
- nuevo proveedor push;
- nuevo buscador;
- microservicios;
- rediseño completo del Owner.

## 18. Before / After

### Before R113

- 107 módulos JS en grafo síncrono desde `app.js`.
- 4.940.145 bytes fuente síncronos.
- alertas Owner globales no podían resolver dispositivos por el filtro `club_id=null`.
- Owner analytics existente sin esta capa Command Center R114.

### After R114

- 99 módulos JS síncronos.
- 4.253.738 bytes.
- reducción estática: 686.407 bytes (~13,9 %).
- dispatcher admite notificación Owner global y deduplica tokens.
- Command Center con alertas, métricas interactivas, CSV y PDF.

## 19. Rollback

Los cambios son localizados y reversibles:

- Frontend: revertir imports dinámicos y módulos Owner R114.
- DB: deshabilitar/drop de triggers/RPC/index R114 mediante migración de rollback preparada solo si fuese necesaria; no borrar datos de negocio.
- Edge Function: retirar `kombax-owner-report-r114` y redeploy de `notification-dispatch` R113.
- Build: volver a ZIP R113 congelado cuyo hash está registrado arriba.

No ejecutar rollback destructivo directamente sobre producción sin snapshot/backup.

## 20. No validado / gates externos

- migración R114 ejecutada en Supabase remoto;
- Edge Functions R114 desplegadas;
- FCM real en dispositivos físicos;
- permisos push Android/PWA en estados abierta/background/cerrada;
- Web Vitals medidos en `kombax.es` después del deploy;
- Stripe real;
- emails reales;
- firma Android de release;
- benchmark de 50.000 miembros/1.000 clubes sobre infraestructura remota.

## 21. Conclusión

R114 mantiene la baseline funcional y concentra el trabajo pre-piloto en tres puntos de bajo riesgo: **menos JS síncrono inicial, notificación Owner operativa y Owner Command Center sobre datos agregados**. La release puede pasar a validación de despliegue, pero no debe etiquetarse como completamente validada en producción hasta completar los gates externos anteriores.
