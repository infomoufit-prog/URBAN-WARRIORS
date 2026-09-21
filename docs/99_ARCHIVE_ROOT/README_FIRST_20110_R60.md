# LEER PRIMERO — KOMBAX 20.110 R60

## Entrega

**KOMBAX 20.110 R60 — MIGRATIONS GUIDE + HISTORY QA**

Base: KOMBAX 20.109 R59  
Build Web/PWA: `20110`  
Android `versionCode`: `20110`  
Android `versionName`: `2.0.0-rc.13-r60-migrations-guide-history`

Esta entrega es una **candidata de estabilización**, preparada para continuar QA, Netlify, Android, Google Play Internal y piloto. **No se declara production-ready** todavía.

## Qué incorpora R60

- Guía profesional/comercial KOMBAX para migraciones, exclusiva de Club y Federación.
- PDF protegido con branding KOMBAX, ejemplos, FAQ, checklist y soporte.
- Acceso organizativo exacto Club/Federación a la guía y al historial.
- Eliminación individual de conversación y borrado de historial para Assist/Migrations.
- Eliminación física de archivos de Storage + metadatos/análisis asociados.
- Conservación de metering/consumo: borrar historial **no devuelve cupos**.
- Aislamiento por usuario + organización/tenant.
- Reglas R59 preservadas: adulto 16+, menor/tutor, adulto histórico sin email, ficha existente, reclamación de membresía y multiclub.
- Scripts Android actualizados a nombres R60/20110 para APK/AAB.

## Certificación local del ZIP

- QA focal R60: **32/32 PASS**.
- Regresión `npm test`: **PASS**.
- Legal gate: **9/9 PASS**.
- Build determinista: **191 archivos · `web = dist = Android`**.
- Android preflight: **4/5**; único pendiente: firma release local.
- PDF: 10 páginas A4 inspeccionadas visualmente; el payload de la Edge Function coincide byte a byte con el PDF protegido.

Evidencias: `R60_FINAL_EVIDENCE/`.

## Estado Supabase conocido al empaquetar

Ya activo/aplicado:

- migración `kombax_r60_migrations_guide_history`;
- migración `kombax_r60_history_performance_hardening`;
- Edge Function `kombax-history-delete-r60` con JWT obligatorio.

Incluido pero **pendiente de despliegue explícito**:

- `supabase/functions/migration-guide-r60/`.

Antes de usar la descarga real de la guía en el piloto, desplegar esa función con `verify_jwt=true` y probarla con sesiones autenticadas de Club/Federación y perfiles denegados.

## Netlify

El proyecto ya contiene `netlify.toml`:

- comando de build: `npm run release:build`;
- carpeta de publicación: `dist`;
- Node 22;
- headers de seguridad y redirects incluidos.

Antes de producción:

1. ejecutar `npm run release:build` local/CI;
2. desplegar primero en entorno de QA/preview si se desea;
3. validar login, Club, Federación, Social, Showcase, Events, Finance, Migrations y Assist;
4. publicar a producción solo con autorización explícita.

No se ha realizado despliegue Netlify R60 durante este empaquetado.

## Android / APK / AAB / Google Play

Leer `ANDROID.md`.

1. Restaurar **la misma clave de firma ya existente** fuera del ZIP.
2. Ejecutar `npm run android:preflight` y exigir **5/5**.
3. APK QA: `npm run android:debug:qa`.
4. AAB Play: `npm run android:aab:play`.
5. Subir primero a **Google Play · Prueba interna**.
6. Instalar desde Play y hacer smoke test autenticado.
7. Solo después valorar piloto oficial / promoción de pista.

El entorno de empaquetado no pudo descargar Gradle 8.11.1 desde `services.gradle.org`, por lo que **no se afirma que este ZIP contenga un APK/AAB R60 compilado**. El código, versionado y pipeline sí están preparados.

## Gate mínimo antes del piloto oficial

- Edge `migration-guide-r60` desplegada y probada con JWT.
- QA autenticada real Club/Federación + perfiles denegados.
- Prueba real de borrado con archivo Storage y confirmación de no devolución de cupos.
- Revisión/cierre de advisors R60 y clasificación del backlog histórico.
- Android preflight 5/5 con la firma existente.
- APK/AAB generado y probado; AAB validado en Play Internal.
- Netlify R60 validado.
- Smoke test móvil/PWA con cuentas reales de piloto.

## Archivos clave

- `CHANGELOG_20110_R60.md`
- `QA_HANDOFF_20110_R60.md`
- `SUPABASE_ADVISORS_20110_R60.md`
- `ANDROID.md`
- `RELEASE_IDENTITY_20110_R60.txt`
- `MANIFEST_SHA256_20110_R60.txt`
- `docs/protected/KOMBAX_GUIA_MIGRACIONES_CLUB_FEDERACION_R60.pdf`
