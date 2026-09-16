# KOMBAX 20.101 R52 · Android QA Sync

Objetivo: evitar falsos positivos al probar cambios que sí aparecen con `npm run dev` pero no en un APK antiguo.

## Diferencia de fuentes
- `npm run dev` sirve `web/`.
- Android empaqueta `android/app/src/main/assets/www/`.
- `scripts/build.mjs` copia `web/` a `dist/` y a Android y verifica SHA.

## Identidad Android QA
- applicationId: `com.urbanwarriors.app`
- versionCode: `20102`
- versionName: `2.0.0-rc.13-r52qa`
- User-Agent: `KOMBAXApp/2.0.0-rc.13-r52qa/20102`

## Build recomendado
Desde la raíz en Windows:

```powershell
npm run android:debug:qa
```

Este comando ejecuta, en orden:
1. `node scripts/build.mjs`
2. `gradlew.bat clean assembleDebug`

Salida:
`android/app/build/outputs/apk/debug/app-debug.apk`

En builds debug, WebView usa `LOAD_NO_CACHE` y limpia su caché al arrancar. No se borran `localStorage` ni los datos de sesión mediante `WebStorage.deleteAllData`.

No despliega Netlify, no hace push a GitHub y no publica Google Play.
