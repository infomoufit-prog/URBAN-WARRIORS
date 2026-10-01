# KOMBAX R116 — Golden Pilot Freeze Release Manifest

- Release: `2.0.0-rc.13-r116-golden-pilot-freeze`
- Build: `20169`
- Fecha: 2026-10-01
- Piloto: 2026-10-01 → 2026-11-15
- Baseline de rollback: R113 congelada
- SHA-256 baseline R113: `63f4ed73777179f8dcefcf84d6c3476e59e0b70eb6f7e1797459b790969ec2a8`

## Cambios acumulativos R114–R116

1. Lazy loading de módulos pesados fuera del arranque.
2. Owner Command Center: alertas, analytics por periodo, tablas, CSV e informe PDF privado.
3. Routing push global Owner corregido para notificaciones sin `club_id`.
4. Alertas Owner para verificaciones y ejecuciones de agentes fallidas/de riesgo alto.
5. Cuenta gratuita neutral: no se asigna automáticamente Espectador.
6. Ocho recorridos visibles: Espectador, Miembro/Familiar, Competidor, Club, Federación, Marca, Profesional y Media/Creador.
7. Miembro/Familiar reutiliza el flujo de vinculación existente; la autoridad de membresía continúa en el club.
8. Miembro/Practicante no puede activar/publicar Social sin `socios.estado=activo`, `kombax_acceso_estado=activo` y `miembros_club.rol=alumno` activo.
9. Competidor conserva la vía autónoma verificada y la evolución desde Miembro sin segunda cuenta.
10. Verificaciones/documentación existentes de Competidor, Club, Federación y Marca preservadas.
11. Precios públicos y contratación ocultos durante el piloto: `No disponible hasta lanzamiento`. El catálogo económico interno no se borra.
12. Web/PWA/Android alineados a build 20169.
13. Android `compileSdk 36`, `targetSdk 36`, `applicationId com.urbanwarriors.app`.

## Delta Supabase requerido

No usar `supabase db push` a ciegas en esta entrega: el archivo histórico local de migraciones no replica 1:1 los timestamps del historial remoto.

Aplicar exclusivamente y en este orden, desde SQL Editor del proyecto `poggsobhtutbuagjiydc`:

1. `supabase/deploy/KOMBAX_R116_SUPABASE_PREFLIGHT.sql` — lectura; debe confirmar dependencias.
2. `supabase/deploy/KOMBAX_R116_REQUIRED_PATCH.sql` — contiene solo los deltas R114 + R115 requeridos.
3. `supabase/deploy/KOMBAX_R116_SUPABASE_POSTFLIGHT.sql` — lectura; todos los campos deben devolver `true`.

Edge Functions requeridas después del SQL:

- `notification-dispatch` — routing Owner global + deduplicación/localización.
- `kombax-owner-report-r114` — PDF Owner privado.
- `health` — build 20169.

`supabase/config.toml` fija `verify_jwt=false` para `health` y `notification-dispatch`, y `verify_jwt=true` para `kombax-owner-report-r114`.

## QA ejecutado

- R115 onboarding/identidad: 11/11 PASS.
- R116 freeze: 12/12 PASS.
- Release Netlify gate: 60 PASS / 5 P2 I18N históricos / 0 fallos nuevos.
- Build determinista: 621 archivos idénticos entre `web`, `dist` y Android assets.
- Android preflight: 7/8.
- Java detectado: 21, compatible con Gradle 8.11.1.
- Firebase Android: `google-services.json` presente.
- API objetivo Android: 36.
- Firma Android release: pendiente fuera del ZIP.

## Validación remota en lectura

- Proyecto Supabase esperado: `poggsobhtutbuagjiydc`.
- Estado observado 2026-10-01: ACTIVE_HEALTHY.
- Dependencias SQL base para R114/R115: presentes.
- Las migraciones nuevas R114/R115 todavía no constan aplicadas en remoto al preparar esta entrega.
- Edge Function remota `notification-dispatch` sigue en la versión anterior sin el fix Owner global; requiere redeploy.
- `kombax-owner-report-r114` no estaba desplegada; requiere deploy.
- `health` remoto seguía declarando build 20156; requiere redeploy de la función local build 20169.

## Deuda/observaciones no introducidas por R116

Los Advisors remotos señalan avisos históricos de `SECURITY DEFINER` ejecutables por roles API, protección de contraseñas filtradas desactivada y un índice duplicado. No se han modificado masivamente en esta fase porque una revocación indiscriminada puede romper RPCs existentes; requieren revisión separada post-piloto o una corrección específica con QA.

## Android / Google Play

La fuente está lista para generar AAB/APK, pero la release firmada exige la upload key registrada para `com.urbanwarriors.app`. La clave no se incluye en el ZIP. Configurar `android/keystore.properties` o las variables `UW_*` y ejecutar `KOMBAX_R116_BUILD_ANDROID_PLAY.cmd`.

## Rollback

- Frontend: volver al deploy/ZIP anterior.
- Edge Functions: redeploy de la versión previa conservada.
- DB: rollback mediante migración explícita; no borrar datos manualmente.
- Baseline última íntegra anterior: R113 congelada con hash indicado arriba.

## SHA-256

El hash del ZIP final se calcula tras el empaquetado y se entrega en un sidecar `.sha256`.
