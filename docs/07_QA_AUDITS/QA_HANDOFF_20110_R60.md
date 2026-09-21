# QA HANDOFF — KOMBAX 20.110 R60

## Estado

**Candidata de estabilización QA. No production-ready todavía.**

Base: KOMBAX 20.109 R59.

## Evidencia final de paquete

- `node --check` en scripts modificados: **PASS**.
- QA focal R60: **32/32 PASS**.
- Regresión completa `npm test`: **PASS**.
- Legal gate: **9/9 PASS**.
- Build/paridad: **191 archivos · `web = dist = Android`**.
- Android preflight: **4/5**.
  - OK `applicationId`.
  - OK `versionCode 20110`.
  - OK assets Android.
  - OK Firebase.
  - PENDIENTE firma release local.
- Intento Gradle `assembleDebug + bundleRelease`: bloqueado por red del entorno al intentar descargar Gradle 8.11.1 desde `services.gradle.org`. No se presenta como fallo funcional ni se afirma APK/AAB compilado.

Logs exactos: `R60_FINAL_EVIDENCE/`.

## Guía profesional

- `docs/protected/KOMBAX_GUIA_MIGRACIONES_CLUB_FEDERACION_R60.pdf`
- 10 páginas A4.
- Branding KOMBAX, enfoque comercial y profesional.
- Casos de Excel/PDF, Club/Federación, finanzas, adulto 16+, menor/tutor, históricos sin email, multiclub, Assist vs Migrations, privacidad, borrado, FAQ y checklist.
- No se publica como asset estático dentro de `web`/`dist`/Android.
- El payload incluido en `migration-guide-r60` coincide byte a byte con el PDF protegido.

## Backend R60 — estado conocido

Aplicado/activo en Supabase:

- `251_kombax_migrations_guide_history_r60.sql`.
- `252_kombax_r60_history_performance_hardening.sql`.
- `kombax-history-delete-r60` con `verify_jwt=true`.

Incluido y validado localmente, pendiente de despliegue explícito:

- `migration-guide-r60` con PDF protegido.

Comprobaciones de privilegios realizadas:

- acceso guía/RPC para `authenticated`: disponible bajo autorización interna;
- `anon`: sin acceso;
- finalizador de borrado: no ejecutable por `authenticated`, reservado al servicio;
- tabla mínima de auditoría: sin DML para `authenticated`/`anon`.

## QA manual autenticada prioritaria

1. Dirección/Secretaría/Coordinación/Economía de Club: visualizar Guía de migración.
2. Federación: visualizar Guía de migración usando su `profile:<id>` exacto.
3. Competidor, Marca, Profesional, Media/Creador, Miembro y Espectador: guía invisible y backend denegado.
4. Cuenta con dos Clubes: A no lista ni borra contenido de B.
5. Federación + otros perfiles: aislamiento por perfil/tenant.
6. Subir archivo real a migración → eliminar conversación → confirmar Storage + mensajes + análisis + ticket eliminados.
7. Confirmar que borrar conversación/historial **no devuelve cupos**.
8. Repetir borrado completado: idempotencia.
9. Revalidar R59: adulto 16+, menor/tutor, adulto histórico sin email, ficha existente, claims y multiclub.
10. Descargar PDF real desde Edge desplegada y comprobar `Content-Type: application/pdf` bajo JWT válido.

## Advisors

Security/Performance Advisors contienen backlog histórico y avisos a revisar antes de producción. Ver `SUPABASE_ADVISORS_20110_R60.md`.

## Android

Los scripts operativos ya nombran los artefactos como R60:

- `KOMBAX_20110_R60_MIGRATIONS_GUIDE_HISTORY_QA_DEBUG.apk`
- `KOMBAX_20110_R60_MIGRATIONS_GUIDE_HISTORY_QA_GOOGLE_PLAY.aab`

Antes de generar release:

1. restaurar el JKS existente fuera del repositorio;
2. `npm run android:preflight` → exigir 5/5;
3. `npm run android:debug:qa`;
4. smoke test APK;
5. `npm run android:aab:play`;
6. Play Internal;
7. instalación desde Play y smoke test autenticado.

## Netlify

- `netlify.toml` usa `npm run release:build` y publica `dist`.
- R60 no se ha desplegado a Netlify durante este empaquetado.
- No realizar producción hasta completar QA autenticada y autorización explícita.

## Bloqueos antes de piloto oficial/producción

- Despliegue y QA real de `migration-guide-r60`.
- QA autenticada/RLS real.
- Validación real del borrado de Storage.
- Revisión/cierre de advisors R60 y clasificación del backlog histórico.
- Firma Android existente + preflight 5/5.
- APK/AAB R60 compilado, instalado y probado; AAB en Play Internal.
- Netlify R60 validado.
