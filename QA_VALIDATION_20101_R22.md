# QA · KOMBAX 20.101 R22

## Estado de cierre técnico
IMPLEMENTADO + BACKEND APLICADO + REGRESIÓN PASS + BUILD PASS.
Validación visual física en Chrome/dispositivo y APK Signed: PENDIENTE del usuario.

## Test específico R22
Comando: `node scripts/test-kombax-20101-performance-scale-r22.mjs`
Resultado: PASS 30/30.
Evidencia: `QA_EVIDENCE_R22/test_r22.log`.

Cobertura principal:
- primer viewport 24;
- no carga inicial 100+120;
- no auto-installer en render;
- caché detalle;
- lazy media;
- Main Event antes de undercard;
- Co-Main;
- 30 combates;
- 30 fotos de álbum;
- bundle;
- placeholder no negro;
- keyset real;
- append por cursor;
- filtros server-side;
- page size bounded;
- `foto_referencia`;
- ausencia de duplicación binaria;
- unicidad de referencia;
- cuota lógica;
- UI reutilización de assets;
- acciones para participante/cartel/banner;
- responsive de panel de reutilización.

## Regresión global
Comando: `npm test`
Resultado: PASS · EXIT_CODE=0.
Evidencia: `QA_EVIDENCE_R22/npm_test_full.log`.

Los tests históricos que codificaban versiones/limites antiguos fueron future-proofed para aceptar implementaciones posteriores sin eliminar sus comprobaciones funcionales.

## Build
Comando: `npm run build`
Resultado: PASS · EXIT_CODE=0.
Salida: `OK build 171 archivos · web = dist = Android`.
Evidencia: `QA_EVIDENCE_R22/npm_build.log`.

## Paridad
Comparación SHA-256 archivo por archivo:
- web: 171
- dist: 171
- android/app/src/main/assets/www: 171
- faltantes: 0
- extra: 0
- diferentes: 0
Resultado: PASS.
Evidencia: `QA_EVIDENCE_R22/web_dist_android_parity.json`.

## Android
- applicationId: `com.urbanwarriors.app` · PASS
- versionCode: `20101` · PASS
- assets/www: PASS
- Firebase: PASS
- signing: PENDIENTE por ausencia intencional de `android/keystore.properties`
Resultado preflight: 4/5.
Evidencia: `QA_EVIDENCE_R22/android_preflight.log`.
No existe APK/AAB Signed R22 generada por esta entrega.

## Backend real
Proyecto principal verificado.
Migraciones R22 presentes:
- `kombax_events_performance_scale_fightcard_media_20101_r22`
- `kombax_events_bundle_roles_20101_r22`
- `kombax_events_keyset_asset_reuse_20101_r22`

Keyset E2E de backend verificado con dos páginas: sin solapamiento entre primera y segunda página.
Permisos finales verificados:
- anon `app_kombax_eventos_publicos_page_v191`: EXECUTE permitido (discovery público)
- anon `app_kombax_eventos_mutate_v191`: EXECUTE denegado
- authenticated `app_kombax_eventos_mutate_v191`: EXECUTE permitido, sujeto a guards de gestión/workspace internos

## Preservación seed / multiclub
Verificación final en backend:
- R19 productos: 3
- R19 slugs únicos: 3
- R19 Urban Warriors: 3
- R19 foreign club: 0
- R20 seminario: 1
- R20 seminario Urban Warriors: 1
- R20 foreign club: 0
- R20 publicaciones internas: 2
- R20 publicaciones Urban Warriors: 2
- R20 publicaciones foreign club: 0

## Advisors Supabase
Security Advisor: EJECUTADO.
No se declara el proyecto "security clean". Siguen advertencias globales/heredadas relacionadas con arquitectura RLS/RPC/SECURITY DEFINER y configuración, incluida protección de contraseñas filtradas deshabilitada. Los RPC R22 `SECURITY DEFINER` aparecen también en el advisor: el reader v191 está deliberadamente restringido a datos públicos y el mutador v191 mantiene autenticación/guards de gestión.

Performance Advisor: EJECUTADO.
Persisten avisos históricos de foreign keys sin índice, índices no utilizados y el índice financiero duplicado. El índice `idx_kombax_eventos_publicos_discovery_r22` aparece todavía como unused inmediatamente después del despliegue; esto no prueba que sea innecesario a escala y debe reevaluarse con volumen/carga representativos.

Referencias de remediación de Supabase:
- https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys
- https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index
- https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index

## No validado todavía
- percepción visual real de fluidez en Chrome/PC;
- ausencia perceptual de flashes en el dispositivo concreto del usuario;
- responsive físico en todos los tamaños;
- APK Signed R22 instalada;
- benchmark/load test con decenas de miles de usuarios concurrentes o dataset equivalente.

R22 mejora la arquitectura para escala, pero no se afirma capacidad de carga masiva demostrada sin un load test específico.
