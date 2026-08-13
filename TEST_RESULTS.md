# Resultados de pruebas

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
- Incidencia observada: una imagen PNG de mayor peso permaneció más de un minuto en subida y terminó con `Failed to fetch`. No se creó el material ni hubo duplicado. Una imagen ligera posterior se guardó correctamente.
