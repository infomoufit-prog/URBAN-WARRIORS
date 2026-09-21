# KOMBAX 20.110 R62.8 — Android build status

## Estado certificado
- Código Android completo incluido en `android/`.
- `applicationId`: `com.urbanwarriors.app`.
- `versionCode`: `20110`.
- `versionName`: `2.0.0-rc.13-r62.8-pilot`.
- Assets web Android sincronizados con `web/` y `dist/`.
- `google-services.json` presente en el ZIP de entrega para el entorno piloto local.
- Suite completa y QA R62.8: PASS.

## APK / AAB en este entorno
No se ha podido producir un binario APK/AAB nuevo en este contenedor por dos condiciones externas al código:
1. Gradle Wrapper requiere `gradle-8.11.1-bin.zip` y el entorno no dispone de la distribución cacheada ni acceso de red a `services.gradle.org`.
2. La firma release privada (`android/keystore.properties` + keystore) no forma parte del repositorio/ZIP por seguridad.

El intento de build no falló por compilación de KOMBAX: se detuvo antes de compilar, al intentar resolver la distribución Gradle.

## Comandos de la estructura habitual
En un equipo con JDK/Android SDK y conexión o Gradle 8.11.1 cacheado:

- APK piloto/debug: `npm run android:debug:qa`
- Preflight release: `npm run android:preflight`
- AAB Google Play: `npm run android:aab:play`

Para release/Google Play debe restaurarse la configuración privada habitual de firma mediante `android/keystore.properties` o las variables `UW_*`; nunca debe subirse el keystore a GitHub.
