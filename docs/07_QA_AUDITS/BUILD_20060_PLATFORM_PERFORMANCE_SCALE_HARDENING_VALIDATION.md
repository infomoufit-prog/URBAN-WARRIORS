# KOMBAX 20.060 · PLATFORM PERFORMANCE & SCALE HARDENING

Estado: **CANDIDATA TÉCNICA VALIDADA — NO FREEZE FINAL**  
Fecha: 2026-08-20  
Supabase project: `poggsobhtutbuagjiydc`

## 1. Objetivo

Endurecimiento transversal de rendimiento y carga para navegador, PWA, Android y Supabase sin alterar el modelo funcional validado en 20.059. La intervención se concentra en reducir trabajo periódico innecesario, evitar lecturas duplicadas, limitar overfetch por pantalla y mantener baja latencia percibida con degradación controlada cuando la red empeora.

## 2. Medición previa real en Supabase

Se utilizó `pg_stat_statements` en producción para priorizar por evidencia, no por intuición. Principales RPC históricos por tiempo acumulado observado antes de la intervención:

| RPC | llamadas | media | máximo | total |
|---|---:|---:|---:|---:|
| `app_notificaciones_centro_v037` | 1099 | 27.93 ms | 286.06 ms | 30696.44 ms |
| `app_notificaciones_accionables_v034` | 506 | 33.34 ms | 162.76 ms | 16872.22 ms |
| `app_mutate_v160` | 445 | 26.28 ms | 184.71 ms | 11695.39 ms |
| `app_runtime_contract_v160` | 750 | 6.39 ms | 94.65 ms | 4792.16 ms |
| `app_generar_sesiones_recurrentes` | 619 | 7.39 ms | 43.56 ms | 4574.31 ms |
| `app_kombax_social_mis_perfiles_v051` | 198 | 17.32 ms | 136.75 ms | 3429.34 ms |
| `app_kombax_social_feed_v085` | 32 | 26.17 ms | 97.15 ms | 837.37 ms |
| `app_kombax_showcase_list_v054` | 56 | 4.22 ms | 12.74 ms | 236.48 ms |

Conclusión: el polling histórico de notificaciones del Club era la primera ruta a reducir; Social y Showcase no justificaban una reescritura agresiva en esta fase.

## 3. Cambios implementados

### 3.1 Cabecera: resumen agregado de bajo payload

Nueva migración 105: `kombax_platform_performance_20060`.

Nuevo RPC `app_kombax_header_summary_v105(uuid)`:
- una fila con contadores Club/KOMBAX/Mensajes y metadatos del último aviso;
- evita descargar hasta 1000 objetos completos para pintar badges;
- conserva la clasificación de grupos del centro de notificaciones;
- `SECURITY DEFINER` con `search_path` fijo;
- acceso `authenticated` únicamente; `anon` revocado;
- valida autenticación y pertenencia al Club.

Índice parcial añadido:
`idx_notificaciones_club_active_feed_v105 (club_id, creado_en desc, id desc) WHERE ciclo_estado='activo'`.

### 3.2 Scheduler adaptativo compartido

Nuevo módulo `web/js/core/adaptive-poller.js`:
- `setTimeout` adaptativo en lugar de intervalos rígidos;
- pausa/reducción en segundo plano;
- recuperación al volver a primer plano o recuperar Internet;
- backoff exponencial ante fallos;
- jitter para evitar sincronización masiva de clientes.

Cabecera:
- 45 s en primer plano;
- 180 s oculta;
- backoff hasta 600 s;
- jitter 15 %.

Chat:
- ~2.5 s mientras la conversación está visible;
- polling completamente pausado si la app/pestaña queda oculta;
- backoff hasta 20 s con fallo de red;
- jitter 10 %;
- resincronización al volver.

### 3.3 Coalescing de lecturas simultáneas

`web/js/core/backend.js` coalesce lecturas idénticas en vuelo por usuario + Club + RPC/consulta + argumentos. No existe caché cruzada entre usuarios ni se deduplican mutaciones.

### 3.4 Dashboard

- snapshot corto de 30 s por tenant;
- retiradas consultas de disciplinas y asistencia que el render del dashboard no consumía;
- ya no carga el centro completo de notificaciones;
- usa el resumen v105.

### 3.5 Portal de miembro

El antiguo loader monolítico se divide por pantalla:
- base;
- dashboard;
- horario;
- perfil.

Cada vista solicita únicamente sus dominios necesarios. Se evita cargar cuotas, documentos, sesiones, seguimiento y otros conjuntos cuando no son consumidos por la pantalla actual.

### 3.6 Paginación y límites existentes preservados

No se degradan los contratos ya correctos:
- Social feed keyset/cursor;
- Showcase paginado;
- chat por ordinal/cursor y carga progresiva;
- comentarios y otros listados permanecen acotados por sus contratos actuales.

## 4. Verificación Supabase live

Registro live:
`20260820022939 · kombax_platform_performance_20060`.

Seguridad verificada:
- RPC presente: PASS
- índice presente: PASS
- `authenticated EXECUTE`: PASS
- `anon EXECUTE`: **false**
- `SECURITY DEFINER`: PASS
- `search_path`: fijado a `public, auth`

### Equivalencia funcional

Perfil QA real: `f68fe22f-eefa-43f1-ba9e-329f621cec74`  
Club: `11111111-1111-4111-8111-111111111111`

Comparación v105 vs `app_notificaciones_centro_v037`:
- no leídas: **5 = 5**
- grupos no leídos: **3 = 3**
- último aviso: **mismo ID**
- KOMBAX pendientes: 1
- solicitudes de relación: 0
- solicitudes de contacto: 1
- mensajes no leídos: 0

Resultado: **equivalencia PASS**.

### Medición v105

`EXPLAIN (ANALYZE, BUFFERS)` de una llamada real: ~29.5 ms.  
Muestra pequeña de `pg_stat_statements`: media agregada aproximada ~30.5 ms; máximo observado 92.67 ms.

Esta intervención no se vende como una reducción radical del tiempo interno del SQL: la ganancia principal es arquitectónica —una fila de resumen en lugar de un centro completo, menos overfetch, menos trabajo en background y backoff bajo fallo—. La muestra actual no permite afirmar p95/p99 de producción a escala.

## 5. Supabase Advisors

### Security Advisor

No se introdujo una nueva exposición anónima. El nuevo v105 aparece dentro de la categoría general de funciones `SECURITY DEFINER` ejecutables por usuarios autenticados, coherente con la arquitectura RPC de KOMBAX; se verificó explícitamente que `anon` no puede ejecutarlo.

Persisten avisos previamente conocidos:
- tablas RLS sin policy deliberadamente cerradas (`deny by default`);
- cinco endpoints públicos anon intencionales ya clasificados;
- funciones cliente `SECURITY DEFINER` autenticadas;
- **Leaked Password Protection Disabled**, pendiente en Auth.

Remediación oficial de RLS-no-policy: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy  
Remediación SECURITY DEFINER autenticado: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable  
Protección de contraseñas filtradas: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

### Performance Advisor

No reaparecen categorías graves ya corregidas en 20.057. Persisten INFO históricos de FKs actor/auditoría sin índice dedicado e índices sin uso por bajo tráfico. No se eliminan ni añaden índices indiscriminadamente sin evidencia de consultas.

Remediación oficial FK sin índice: https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys  
Remediación oficial índice sin uso: https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index

## 6. Validación de código/build

- `npm test`: **PASS**
- `npm run build`: **PASS** (incluye la suite completa)
- test específico `test-kombax-20060-performance-scale.mjs`: **PASS**
- web: 66 archivos
- dist: 66 archivos
- Android assets: 66 archivos
- faltantes: 0
- extras: 0
- diferencias SHA por archivo: 0
- web tree SHA-256: `74c5065ac078917fbe3f0615ee5ab686556eec412089ee262237b1db08409f4e`

Android preflight:
- identidad estable: PASS
- versionCode 20060: PASS
- assets/www: PASS
- Firebase: PASS
- firma local: PENDIENTE
- resultado: **4/5**, igual que el baseline de release; el keystore no debe empaquetarse.

## 7. Secret audit

- JKS/keystore/P12/PFX/PEM empaquetados: **0**
- bloques de clave privada: **0**
- valores con patrón service-role: **0**

## 8. Delta frente a 20.059 CHAT READ RECEIPTS

Cambios funcionales fuente principales:
- nuevo `web/js/core/adaptive-poller.js`;
- `web/js/core/backend.js`;
- `web/js/core/repositories.js`;
- `web/js/app.js`;
- `web/js/modules/kombax-social.js`;
- `web/js/modules/portal.js`;
- `web/js/modules/dashboard-catalog.js`;
- build/cache version 20060;
- migración/rollback/verificación 105;
- test 20.060;
- presupuesto `PLATFORM_PERFORMANCE_BUDGET_20060.md`.

No se eliminó ningún archivo de 20.059. Las copias `dist` y Android reflejan el mismo delta generado por build.

## 9. Presupuesto y escalado

Objetivos de release documentados en `PLATFORM_PERFORMANCE_BUDGET_20060.md`:
- resumen cabecera: objetivo p95 <100 ms con dataset normal de lanzamiento;
- feed/Showcase: objetivo p95 <200 ms en dataset de lanzamiento;
- cero polling de chat con app oculta;
- cero descarga de hasta 1000 notificaciones para pintar badges;
- ninguna ruta nueva Social/Showcase/chat sin paginar;
- carga de staging escalonada prevista: 50 → 100 → 250 → 500 → 1000 sesiones concurrentes.

**No se ejecuta una prueba destructiva de cientos/miles de usuarios contra producción.** Esa fase debe hacerse con staging/dataset sintético controlado.

## 10. Pendientes antes del freeze final

1. Prueba manual navegador/PWA/APK con navegación real y cambio de Club.
2. Prueba dual de chat A↔B y recibos leído.
3. Prueba manual de pérdida/recuperación de red observando backoff/reconexión.
4. Firma Android local para pasar preflight 5/5 al generar release firmada.
5. Resolver/aceptar explícitamente `Leaked Password Protection` antes del freeze estricto.
6. Load test en staging a 50/100/250/500/1000 sesiones y registrar p50/p95/p99, errores y consumo.
7. Realtime/Broadcast privado sigue siendo evolución posterior; el chat actual utiliza autosync adaptativo y seguro, no WebSocket.

## Resultado

**20.060 PLATFORM PERFORMANCE & SCALE HARDENING: PASS técnico para candidata.**  
No se declara freeze final hasta completar los pendientes manuales y de carga indicados arriba.
