# KOMBAX 20.061 · 10K CONCURRENT SCALE READINESS

Estado: **CANDIDATA TÉCNICA PREPARADA PARA ENSAYO DE ALTA CONCURRENCIA — NO CERTIFICADA 10K / NO FREEZE FINAL**  
Fecha: 2026-08-20  
Supabase project: `poggsobhtutbuagjiydc`

## 1. Objetivo

Endurecer KOMBAX para que la arquitectura pueda someterse de forma controlada a un objetivo de hasta **10.000 sesiones concurrentes** sin alterar el modelo funcional validado, la seguridad, el aislamiento multiclub ni las reglas de producto.

Esta intervención **no afirma que 10.000 concurrentes hayan sido certificados en producción**. La certificación requiere el ensayo progresivo en QA/staging documentado en `LOAD_TEST_RUNBOOK_10K_CONCURRENT_20061.md` y conservación de métricas p50/p95/p99, error rate, CPU/IO, pool/conexiones y egress por peldaño.

## 2. Principios aplicados

- reducir trabajo periódico inútil antes de escalar infraestructura;
- mantener consultas paginadas/acotadas;
- evitar amplificación de helpers de autorización por fila;
- pausar polling cuando la app está oculta;
- backoff + jitter + idle backoff para evitar thundering herd;
- limitar concurrencia de lecturas por cliente;
- coalescer lecturas idénticas en vuelo;
- cachear durante una ventana corta el contrato de runtime por usuario/Club;
- preservar contratos anteriores como rollback lógico mientras se valida v106;
- no introducir dependencias remotas/CDN nuevas en fase final;
- no ejecutar una carga destructiva de miles de usuarios contra producción.

## 3. Cambios frontend

### 3.1 Scheduler adaptativo 20.061

`web/js/core/adaptive-poller.js` amplía el scheduler 20.060:

- distingue actividad real de ciclos `idle`;
- `idleStreak` y `idleMaxMs` permiten reducir frecuencia cuando no cambia nada;
- `markActive()` vuelve inmediatamente a la ruta rápida cuando el usuario interactúa;
- sigue respetando visibilidad, online/offline, backoff de error y jitter.

Cabecera:
- ciclo normal de 45 s;
- **0 polling en background**;
- después de reposo, backoff de éxito hasta 300 s;
- errores con backoff hasta 600 s;
- jitter 20 %.

Chat abierto:
- ruta caliente de ~2,5 s cuando hay actividad;
- después de ciclos sin cambios, backoff progresivo hasta 30 s;
- **0 polling con la app/pestaña oculta**;
- reactivación inmediata tras enviar/interactuar/volver al primer plano;
- actualización de metadatos/read receipts desacoplada y acotada (~12 s salvo fuerza).

### 3.2 Control de burst por cliente

`web/js/core/backend.js`:

- máximo de **6 lecturas simultáneas** por cliente antes de encolar;
- coalescing de lecturas idénticas en vuelo;
- caché del runtime contract por usuario + Club durante 5 minutos;
- coalescing de verificaciones de contrato concurrentes;
- invalidación al cambiar Club o cerrar sesión;
- las mutaciones no se deduplican ni se cachean.

Objetivo: evitar que una navegación rápida, un reconnect o varias vistas disparen ráfagas redundantes por sesión.

### 3.3 Límites explícitos en listados operativos

Se añaden máximos explícitos en repositorios de rutas que podían crecer con el SaaS:

- miembros: 500;
- miembros visibles portal: 500;
- inscripciones portal: 1000;
- series de sesiones: 500;
- catálogo material: 500;
- variantes: 2000.

Los dominios ya preparados mantienen sus contratos actuales:

- Social feed: cursor/keyset;
- posts de perfil: cursor/keyset;
- Showcase: cursor/keyset;
- chat: ordinal/cursor con página máxima 50 en v106.

## 4. Supabase v106

Migración aplicada en producción:

`20260820034225 · kombax_10k_concurrent_scale_20061`

Archivo fuente:
`supabase/migrations/106_kombax_10k_concurrent_scale_20061.sql`

Rollback y verificación:
- `supabase/rollbacks/106_kombax_10k_concurrent_scale_20061_rollback.sql`
- `supabase/verification/106_kombax_10k_concurrent_scale_20061_verification.sql`

### 4.1 Scope Social del actor

Nuevo helper interno `app_kombax_my_social_actor_ids_v106()`:

- calcula una vez las identidades Social que puede controlar el usuario;
- Miembro: propietario natural;
- Club: pertenencia activa al Club;
- perfil directo: propietario/gestor autorizado;
- mantiene la validación canónica `app_kombax_social_puede_actuar_v051`;
- **no es ejecutable por `anon` ni por `authenticated` desde el cliente**.

Esto evita reevaluar helpers completos repetidamente para cada mensaje/contacto en rutas calientes.

### 4.2 Cabecera

- `app_kombax_header_activity_v106()`
- `app_kombax_header_summary_v106(uuid)`

La actividad KOMBAX calcula el conjunto de actores una vez y usa ese scope para solicitudes/red/mensajes no leídos. El resumen Club conserva el comportamiento de v105 y sustituye únicamente la parte KOMBAX por v106.

### 4.3 Bandeja y chat

- `app_kombax_contactos_v106()`
- `app_kombax_contact_mensajes_v106(uuid, integer, integer, integer)`
- `app_kombax_contact_mark_read_v106(uuid)`

Propiedades relevantes:

- bandeja limitada a 200 conversaciones;
- historial limitado a 50 por página;
- navegación incremental por ordinal;
- actor scope evaluado una vez por llamada;
- índice nuevo para remitente/estado/fecha:
  `idx_kombax_social_contacto_remitente_v106`;
- Contact Gate y bloqueos/contactabilidad permanecen activos;
- `anon` revocado en los endpoints cliente;
- `search_path` fijo `public, auth`.

Los contratos v104/v105 anteriores no se eliminaron, lo que permite rollback de frontend sin pérdida de datos durante la fase de validación.

## 5. Seguridad live v106

Verificación directa tras la migración:

- `app_kombax_header_summary_v106`: presente;
- `app_kombax_header_activity_v106`: presente;
- `app_kombax_contactos_v106`: presente;
- `app_kombax_contact_mensajes_v106`: presente;
- `app_kombax_contact_mark_read_v106`: presente;
- índice remitente v106: presente;
- `authenticated` puede ejecutar endpoints cliente: PASS;
- `anon` no puede ejecutar header/mensajes v106: PASS;
- helper interno de actores no es ejecutable por cliente: PASS;
- endpoints v106 verificados como `SECURITY DEFINER`: PASS;
- `search_path` fijo: PASS.

No se debilitó RLS ni se expusieron tablas directas para conseguir rendimiento.

## 6. Equivalencia funcional live

Perfil de prueba real autenticado:
`f68fe22f-eefa-43f1-ba9e-329f621cec74`

Club:
`11111111-1111-4111-8111-111111111111`

Identidad Social:
`b6503c0c-d47c-45f7-beaa-f325211ed70b`

### Cabecera

Comparación `v105` ↔ `v106`: **MATCH**

- avisos Club sin leer: 5 = 5;
- grupos Club sin leer: 3 = 3;
- mismo último aviso;
- KOMBAX pendientes: 1 = 1;
- solicitudes de red: 0 = 0;
- solicitudes de contacto: 1 = 1;
- mensajes no leídos: 0 = 0.

### Actividad KOMBAX

Comparación `v103` ↔ `v106`: **MATCH**.

### Bandeja Contactos

Comparación `v104` ↔ `v106`: **MATCH** para las 3 conversaciones visibles del usuario:

- mismos IDs;
- mismos estados;
- misma dirección recibida/enviada;
- mismos no leídos;
- mismos flags `puede_chat` / `puede_cerrar`.

### Historial de chat

Conversación aceptada QA:
`ae8ab87a-78de-44f7-8a91-0a21f9b027a9`

Comparación `v104` ↔ `v106`:

- 2 = 2 mensajes;
- mismos IDs: PASS;
- mismo estado `propio`: PASS;
- mismo estado de lectura: PASS.

La herramienta de conexión bloqueó un nuevo ensayo que invocaba el RPC de escritura `mark_read_v106`; no se forzó la mutación en producción. El write-path de `leido_en` ya fue probado transaccionalmente en 20.059. Antes del freeze sigue siendo obligatorio repetir el E2E A↔B con dos cuentas reales sobre v106.

## 7. Muestras de latencia live

Se ejecutaron muestras puntuales con `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` y contexto autenticado real. El dataset actual es pequeño; estas cifras sirven para detectar regresiones, **no para derivar capacidad 10K ni p95/p99**.

| Ruta | versión anterior | v106 |
|---|---:|---:|
| resumen cabecera | ~27.45 ms (`v105`) | ~20.97 ms |
| bandeja contactos | ~27.39 ms (`v104`) | ~17.38 ms |
| historial chat | — | ~4.61 ms |

La muestra v106 resulta orientativamente menor en cabecera/bandeja, pero no se presenta como benchmark estadístico.

## 8. Guardarraíles de carga 10K

### Harness

`load/k6-kombax-10k-concurrent.js`

Peldaños soportados:

`100 → 250 → 500 → 1.000 → 2.500 → 5.000 → 7.500 → 10.000 VU`

Mezcla read-only:

- directorio;
- Social feed v085;
- resumen de cabecera v106;
- Showcase v054;
- contactos v106;
- historial chat v106 cuando el fixture aporta conversación.

Umbrales iniciales del harness:

- error rate <1 %;
- header p95 <600 ms;
- feed p95 <900 ms;
- Showcase p95 <700 ms;
- contactos p95 <800 ms;
- chat p95 <600 ms.

El escenario introduce pausas aleatorias y no escribe por defecto.

### Dataset sintético

`scripts/generate-kombax-load-fixture.mjs`

- 10–500 clubes;
- 20–200 miembros por Club;
- tope 50.000 miembros sintéticos;
- escenario de referencia: 200 clubes × 100 miembros = 20.000 miembros;
- genera datos de Club, grupos, cuotas, sesiones, asistencia y notificaciones;
- exige activar explícitamente `app.kombax_load_fixture_enabled='on'`;
- no crea usuarios reales ni tokens de Auth.

## 9. Validación de código y build

Cierre 20.061 ejecutado de nuevo después de la migración:

- `npm test`: **PASS**;
- `npm run build`: **PASS**;
- test específico `test-kombax-20061-10k-scale.mjs`: **PASS**;
- build reporta: `OK build 66 archivos · web = dist = Android`.

Comprobación independiente:

- web: 66 archivos;
- dist: 66 archivos;
- Android `assets/www`: 66 archivos;
- faltantes: 0;
- extras: 0;
- diferencias SHA archivo por archivo: 0;
- web tree SHA-256: `9af6184a567996f29d0aca0f758e4c07a7b0efec127b0e0328e86dd6c5f0d3a5`.

## 10. Android y secretos

Android release preflight:

- applicationId `com.urbanwarriors.app`: PASS;
- versionCode `20061`: PASS;
- `assets/www`: PASS;
- Firebase: PASS;
- firma local: **PENDIENTE**;
- resultado: **4/5**.

El estado 4/5 no es una regresión: `android/keystore.properties` y material de firma deben permanecer fuera del ZIP.

Secret audit:

- JKS/keystore/P12/PFX/PEM: 0;
- bloques de private key: 0;
- valores `service_role`: 0.

## 11. Supabase Advisors tras v106

### Security Advisor

No aparece una nueva exposición anónima v106. Los endpoints v106 sí aparecen en la categoría genérica de `SECURITY DEFINER` ejecutable por autenticados, coherente con la API RPC de KOMBAX; los privilegios `anon` se verificaron aparte.

Persisten avisos históricos conocidos:

- tablas RLS sin policy deliberadamente cerradas;
- cinco endpoints públicos anon intencionales previamente clasificados;
- funciones cliente `SECURITY DEFINER` autenticadas;
- **Leaked Password Protection Disabled**, todavía pendiente en Auth.

Referencias de remediación del Advisor:
- https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

### Performance Advisor

No aparece una nueva categoría HIGH/BLOCKER. Persisten:

- INFO históricos de FKs actor/auditoría sin índice dedicado;
- INFO de índices sin uso por el bajo volumen actual.

El índice `idx_kombax_social_contacto_remitente_v106` también aparece inicialmente como `unused_index`; con solo 4 conversaciones en el dataset actual el planner puede preferir secuencial. No se elimina por ese aviso inicial: su utilidad se evalúa con el dataset sintético de escala.

Referencias de remediación:
- https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys
- https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index

## 12. Qué significa “10K ready” en esta build

20.061 deja preparada la aplicación y el backend para una **campaña reproducible de validación hasta 10.000 concurrentes**, con reducción de amplificación, límites, backoff, jitter, pausa en background, read gating, actor-scope precomputado y herramientas de carga.

**No significa:**

- que 10.000 conexiones se hayan abierto contra producción;
- que el plan/compute actual de Supabase garantice 10.000 concurrentes;
- que exista ya una cifra certificada de p95/p99 a 10K;
- que Realtime/Broadcast sea necesario de antemano.

El siguiente cuello de botella debe decidirse por la campaña de staging. Si el autosync de chat domina el coste a gran concurrencia, el siguiente paso será validar Broadcast privado con fallback incremental; no se introduce esa dependencia tardíamente sin medirla.

## 13. Criterio de certificación pendiente

Ejecutar en staging, sin saltos:

`100 → 250 → 500 → 1.000 → 2.500 → 5.000 → 7.500 → 10.000 concurrentes`

Para cada nivel guardar:

- HTTP p50/p95/p99 por ruta;
- error rate;
- `pg_stat_statements` calls/mean/max/total;
- CPU/IO/memoria;
- conexiones y pool;
- locks/timeouts;
- egress;
- comportamiento de reconexión;
- aislamiento multiclub;
- campaña separada de escrituras idempotentes.

A partir de 2.500 VU utilizar generación de carga distribuida/dedicada para evitar que el generador sea el cuello de botella.

## 14. Pendientes antes del freeze final

1. Campaña staging completa hasta el límite que la infraestructura soporte de forma estable.
2. E2E chat A↔B sobre v106, incluido `✓ Enviado → ✓✓ Leído`.
3. Prueba PWA/APK de background, reconexión y thundering-herd controlado.
4. Firma Android local para preflight 5/5.
5. Resolver/aceptar explícitamente `Leaked Password Protection`.
6. Si una métrica demuestra que polling/chat es el cuello de botella, validar Broadcast privado antes de cambiar arquitectura de producción.

## 15. Conclusión

**20.061 PASS como candidata técnica de 10K scale readiness.**

La intervención reduce trabajo inútil por cliente y amplificación backend sin modificar permisos, visibilidad, Contact Gate, historial, recibos de lectura ni aislamiento multiclub. La afirmación de “soporta 10.000 simultáneos” queda deliberadamente reservada para la campaña de carga staging con evidencia.
