# Resultados de pruebas

## 2026-08-14 — RC13 MVP build 20017 · certificación local

### Superadas localmente

- `npm test`: **PASS** (24 bloques PASS y 487 comprobaciones OK en la ejecución final).
- Contrato RC13: **86/86** operaciones `app_mutate_v160` implementadas según la prueba de contrato.
- `node --check`: **51/51** archivos JS/MJS sin error de sintaxis.
- `npm run build`: **PASS**.
- Build: **48 archivos**.
- Paridad exacta: `web = dist = android/app/src/main/assets/www`.
- `git diff --check`: **PASS**.
- Migración financiera 031: conservada sin modificación.
- Nuevas pruebas: matemática financiera, capability gate backend, perfiles/likes, eventos, responsive y cadena SQL.

### Pendiente antes del freeze definitivo

- Supabase real: audit 023–030 y ejecución/verificación controlada de 031 → 032 → 033.
- RLS real multiclub con cuentas de dos clubes.
- Matriz funcional por roles reales.
- Validación visual PC y web móvil contra backend real.
- APK física Android, notificaciones, multimedia, safe areas y ciclo foreground/background/cerrada.
- Solo después: commit/tag de freeze, push y Netlify desde el SHA exacto.

### Resultado

Estado: **candidata RC13 implementada y certificada localmente; no congelada todavía**.

---

## 2026-08-13 — RC10 sin modificaciones

### Superadas localmente

- Integridad del ZIP.
- Manifiesto de archivos.
- Suite `npm test`.
- Regresiones RC4 a RC10 incluidas en el repositorio.
- Contrato de 74 operaciones del gateway.
- Build `npm run build`.
- Paridad `web`, `dist` y assets Android.
- Versión Android `2.0.0-rc.10 / 20010`.

### No ejecutables solamente con el ZIP

- Diagnóstico de instalación contra Supabase real.
- Login con todas las cuentas/roles reales.
- CRUD real de comunicaciones, Comunidad, Finanzas y material.
- Logs reales de Edge Functions y cron.
- FCM con la app abierta, en segundo plano y cerrada.
- Arranque, logout, reinicio y safe areas en Pixel 8.

### Supabase real

- `app_diagnostico_instalacion_v166()`: **11/12 OK**.
- Fallo: `notificaciones masivas` / `leer grupos/todas`.
- Estado: pendiente de inspeccionar la definición activa de `app_mutate_v160`; no se ha ejecutado ninguna migración correctiva.
- Inspección del gateway: longitud aproximada 10.182; las tres operaciones RC10 comprobadas no aparecen en la función activa.
- Conclusión: Supabase conserva un gateway distinto o incompleto respecto a la RC10 del ZIP.
- Recuperación disponible: `app_mutate_v160_v166` contiene las operaciones masivas y Comunidad; migración 023 preparada localmente y pendiente de prueba/ejecución.
- Migración 023 ejecutada en Supabase real: **12/12 controles OK**.
- Estado del gateway: RC10 recuperado; pendiente matriz CRUD real.
- Certificación E2E con cuenta Gestor: **19/19 OK**, ejecutada desde la interfaz RC12 que estaba instalada.
- Los datos E2E fueron limpiados por el ciclo final previsto por RC10.
- Alcance de esta evidencia: confirma el gateway/backend RC10 recuperado y su compatibilidad con esos flujos; no certifica el frontend ni la APK RC10.

### Resultado

Estado: **pruebas locales y gateway Supabase superados; frontend web y APK RC10 pendientes de restauración y certificación**.

Supabase real fue corregido mediante la migración controlada 023. No se ha restaurado todavía el frontend publicado ni se ha sustituido la APK RC12 instalada.

### Vista previa web RC10

- Arranque y restauración de sesión Gestor: **OK**.
- Contrato y sonda de escritura: **OK**.
- Diagnóstico de persistencia: **12/12 OK**.
- Comunidad: crear con imagen, leer y eliminar: **OK**.
- Comunicaciones: crear con imagen, leer y eliminar: **OK**.
- Material: crear sin imagen, editar con imagen ligera, leer y eliminar: **OK**.
- Finanzas: carga de secciones y creación/eliminación de registro temporal: **OK**.
- Incidencia observada: una imagen PNG de mayor peso permaneció más de un minuto en subida y terminó con `Failed to fetch`. No se creó el material ni hubo duplicado. Una imagen ligera posterior se guardó correctamente.

## Release B — safe areas Android

- Test específico de safe areas: **PASS**.
- Suite completa RC4–RC10 y recuperación 023: **PASS**.
- Build compartido: **PASS**, 44 archivos y paridad `web = dist = Android`.
- Compilación Gradle: pendiente; el ZIP limpio no incluye wrapper `gradlew`.
- Validación Pixel 8: pendiente para la APK candidata conjunta.

## Release C — Firebase seguro y permiso Android

- Test de inicialización segura, token, permiso y Ajustes: **PASS**.
- Suite completa y build compartido: **PASS**.
- Firebase ausente/fallido queda degradado sin dependencia de arranque.
- APK, token real y push abierta/segundo plano/cerrada: pendientes antes del despliegue final.

## Release D — permiso global y avisos de cobro

- Test específico de experiencia, Edge Functions, tokens inválidos y cinco avisos: **PASS**.
- Suite completa RC4–RC10, recuperación 023 y Releases B–D: **PASS**.
- Build compartido: **PASS**, 44 archivos y paridad `web = dist = Android`.
- Migración SQL: no requerida; las restricciones e idempotencia existentes se preservan.
- Deploy de Edge Functions, cron/logs, “Procesar hoy” real y push real: pendientes de la fase controlada de Supabase previa al despliegue web.

## Release E — finanzas anuales y portal familiar

- Test específico de migración, rollback, agregación, filtros, seguridad y experiencia: **PASS**.
- Suite completa y build compartido: **PASS**, 44 archivos y paridad `web = dist = Android`.
- Historial y métricas: migración 024 ejecutada en Supabase real; vistas detalle/mensual/anual **3/3 OK**.
- Pruebas CRUD/RLS por rol y comparación de cifras: pendientes de la fase Supabase previa al despliegue.

## Release F — materiales, deuda y avisos

- Test específico de estados, permisos, bloqueo de stock, idempotencia, cargo, avisos y rollback: **PASS**.
- Suite completa y build compartido: **PASS**, 44 archivos y paridad `web = dist = Android`.
- Migraciones 025–026 ejecutadas en Supabase real; material **2/2 OK** y motor anterior de avisos disponible para rollback.
- Aún pendientes: CRUD con alumno/familia/equipo, dos validaciones concurrentes, comprobación de stock/cargo/entrega y push real. Release F no está aprobada hasta superar esas pruebas.

## Release G — Comunidad paginada

- Test específico de índice, cursor doble, límite de 20 y carga progresiva: **PASS**.
- Suite completa y build compartido: **PASS**, 44 archivos y paridad `web = dist = Android`.
- Migración 027 ejecutada en Supabase real; índice de cursor verificado. Plan real y feed >20 pendientes.
- Pendientes antes de aprobar: feed real con más de 20 entradas, empate de fechas, scroll móvil y aislamiento entre dos clubes.

## Release H — imágenes optimizadas

- Migración 028 ejecutada en Supabase real; metadatos y rollback **2/2 OK**.

- Test específico de resolución, peso, WebP, fallback, memoria, metadatos y timeout: **PASS**.
- Suite completa y build compartido: **PASS**, 45 archivos y paridad `web = dist = Android`.
- Migración 028: preparada localmente; conserva el gateway anterior y no guarda binarios en PostgreSQL.
- Pendientes antes de aprobar: imagen real grande/vertical/transparente en web y Android, calidad visual y comprobación de metadatos en Supabase.

## Release I — vídeos y portadas

- Test específico de 50 MB, 15 s, 1080p, miniatura, carga diferida, permisos y limpieza: **PASS**.
- Suite completa y build compartido: **PASS**, 45 archivos y paridad `web = dist = Android`.
- Migración 029 y cambio de `notification-dispatch`: preparados localmente; no desplegados.
- Pendientes antes de aprobar: MP4 real, rechazo 4K, portada automática/manual, reproducción web/Pixel 8 y limpieza de Storage.

## Release J — multiclub, RLS y rendimiento

- Test específico de índices, políticas tenant, DML por gateway, rollback y matriz CRUD: **PASS**.
- Suite completa y build compartido: **PASS**, 45 archivos y paridad `web = dist = Android`.
- Migración 030: preparada localmente; incluye diagnóstico `app_multiclub_audit_v030()`.
- Pendientes antes de aprobar: ejecutar 030, confirmar todas las filas del diagnóstico y completar CRUD/cross-club con sesiones reales.

## Paquete previo a despliegue

- `npm test`: **PASS** después de añadir preflight/verificación 029–030 y auditoría 023–030.
- `npm run build`: **PASS**, 45 archivos y paridad `web = dist = Android`.
- `git diff --check`: **PASS**.
- SQL real 029/030: pendiente de ejecución guiada en Supabase; los verificadores no sustituyen esa prueba.
- Netlify, APK y fusión: no ejecutados.
