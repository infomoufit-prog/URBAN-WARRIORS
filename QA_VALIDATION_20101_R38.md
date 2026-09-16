# KOMBAX 20.101 R38 · QA Validation

## Targeted R38
- `npm run test:20101:r38`: **PASS 67/67**.

## Regresión dirigida de continuidad
- R37: **62/62**.
- R36: **49/49**.
- R35: **39/39**.
- R34: **33/33**.
- R33.1: **27/27**.
- R33: **52/52**.
- R32: **36/36**.
- Contrato histórico de allowances v213: **OK** tras el build.

Las aserciones históricas R34/R27/v213 se actualizaron únicamente donde R38 sustituye intencionadamente copy/rutas/RPC customer-side. Sus controles funcionales y de privacidad permanecen activos.

## Full regression + build
- `npm run build`: **exit 0**.
- El log completo contiene 752 líneas `PASS` además de gates `OK` de suites históricas.
- Resultado final del builder: `OK build 189 archivos · web = dist = Android`.

## Paridad independiente
- web: 189 archivos.
- dist: 189 archivos.
- Android `assets/www`: 189 archivos.
- missing: 0.
- extra: 0.
- diferencias SHA-256: 0.
- hash agregado del árbol web: `3a675dc81f60371ddaa7c08392c9c224d7c6ddc125bb5f57993eb16ddfe3ebd0`.

## Android
- Preflight: **4/5**.
- OK: applicationId estable.
- OK: versionCode 20101.
- OK: `assets/www` presente.
- OK: Firebase presente.
- Pendiente único: `android/keystore.properties` local + JKS autorizada.
- No se generó ni se reclama APK/AAB firmado.
