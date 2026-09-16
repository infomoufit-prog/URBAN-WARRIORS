# Android Preflight · KOMBAX 20.101 R32

Resultado automatizado: **4/5**.

El único elemento pendiente es intencional: la firma release no se guarda en el ZIP.

## Preparación local
1. Copiar `android/keystore.properties.example` a `android/keystore.properties`.
2. Editar SOLO localmente:
   - `storeFile`
   - `storePassword`
   - `keyAlias`
   - `keyPassword`
3. No subir `keystore.properties` ni `.jks/.keystore` a GitHub.
4. Ejecutar desde Windows:
   - `android\\gradlew.bat signingStatus`
   - `android\\gradlew.bat assembleRelease`
   - `android\\gradlew.bat bundleRelease`
5. Alternativamente usar Android Studio → Generate Signed Bundle / APK con la misma upload key ya validada.

## Outputs esperados
- APK: `android/app/build/outputs/apk/release/app-release.apk`
- AAB: `android/app/build/outputs/bundle/release/app-release.aab`

Consultar también `ANDROID_PREFLIGHT_20101_R32.txt` y `LOCAL_PILOT_CHECKLIST_20101_R32.md`.
