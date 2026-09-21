# KOMBAX 20.101 R52.1 — Android build fix

## Fallo reproducido
El paquete R52 Android QA podía detenerse después de sincronizar `web -> dist -> Android` al intentar ejecutar el wrapper Gradle directamente. En Unix se reprodujo `spawnSync ./gradlew EACCES`; en Windows el `.bat` tampoco debe depender de ejecución directa desde Node.

## Corrección
- Windows: `gradlew.bat` se ejecuta mediante `cmd.exe /d /s /c call gradlew.bat ...`.
- Linux/macOS: `sh ./gradlew ...`, independiente del bit ejecutable del ZIP.
- El modo debug solo termina en PASS si existe realmente el APK.
- El modo Google Play solo continúa si el preflight de firma/Firebase/assets está completo y exige un AAB real.
- `BuildConfig.DEBUG` se sustituye por `ApplicationInfo.FLAG_DEBUGGABLE` para evitar dependencia de BuildConfig generado.
- Se preserva el versionado base del proyecto: `versionCode 20101`, `versionName 2.0.0-rc.13`, manteniendo las regresiones históricas.
- Los artefactos se copian con nombres inequívocos de R52.1.

## Web/PWA
`npm run dev`

## APK debug
`npm run android:debug:qa`

Artefacto final:
`artifacts/KOMBAX_20101_R52_1_BUILD_FIX_DEBUG.apk`

## Google Play / AAB
Configurar primero `android/keystore.properties` y ejecutar:
`npm run android:aab:play`

Artefacto final:
`artifacts/KOMBAX_20101_R52_1_GOOGLE_PLAY.aab`
