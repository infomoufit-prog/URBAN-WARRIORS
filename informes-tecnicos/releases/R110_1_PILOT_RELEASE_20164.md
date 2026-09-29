# KOMBAX R110.1 · build 20164 · Pilot release gate

Versión técnica: `2.0.0-rc.13-r1101-pilot-release`.

## Objetivo

Hotfix acumulativo sobre R110 para desbloquear Netlify sin ocultar ni aumentar la deuda histórica i18n y para endurecer la preparación Android del piloto.

## Netlify

- `release:legal-gate`: PASS.
- `release-netlify-r104-3.mjs` mantiene los audits estrictos en `npm test`.
- El release wrapper acepta únicamente la deuda histórica ya auditada de R110: 255 unresolved en R79 y 242 en runtime copy.
- Cualquier incremento sobre esos valores bloquea el deploy.
- `npm run release:build`: exit code 0.
- Resultado: 52 PASS, 7 P2 históricos conocidos, 0 fallos nuevos.
- `scripts/build.mjs`: 619 archivos · `web = dist = Android`.

## Android

- `versionCode 20164`.
- `versionName 2.0.0-rc.13-r1101-pilot-release`.
- `applicationId com.urbanwarriors.app` preservado.
- Java 21 compatible con Gradle 8.11.1.
- `google-services.json` presente.
- assets web embebidos sincronizados con build 20164.
- `android/gradlew` vuelve a estar marcado como ejecutable para Linux/CI.
- Nuevo comando `npm run android:pilot-release`: ejecuta preflight, `assembleRelease`, `bundleRelease`, verifica APK/AAB y calcula SHA-256.

### Validación externa pendiente

No se generó ni se firma una APK/AAB definitiva en este entorno porque la clave/keystore de subida de Google Play no está disponible aquí. No se genera una clave nueva para evitar romper la continuidad de firma de Google Play. Además, el entorno no puede descargar `gradle-8.11.1-bin.zip` desde `services.gradle.org`.

Por tanto, el código Android está preparado y los checks estáticos pasan 7/8; la certificación final exige ejecutar `npm run android:pilot-release` en el equipo que tenga la firma existente y acceso a Gradle. Solo debe marcarse Android `PASS PARA PILOTO` cuando ese comando produzca APK + AAB release firmados y ambas se validen/instalen correctamente.

## Supabase / piloto

R110 no cambia en esta hotfix. La migración `297_kombax_pilot_club_activation_owner_r110.sql` se conserva íntegramente y ya estaba aplicada en Supabase. Alta Club Piloto, cupo 4, Premium piloto, miembros y Owner tracking permanecen acumulativos.
