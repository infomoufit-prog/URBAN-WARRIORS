# QA Validation · KOMBAX 20.101 R35

## Tests específicos y regresión de continuidad

- R35 Event-Centric Preparation: **39/39 PASS**
- R34 Assist + Preparation: **33/33 PASS**
- R33.1 Federation UX: **27/27 PASS**
- R33 Federation/Licenses: **52/52 PASS**
- R32 Profile Matrix: **36/36 PASS**

## Build global

`npm run build`:
- exit code: **0**
- líneas FAIL/Error detectadas en log final: **0**
- build final: **OK build 186 archivos · web = dist = Android**

Comparación SHA-256 independiente:
- web: 186
- dist: 186
- Android assets/www: 186
- missing: 0
- extra: 0
- diferencias: 0
- SHA-256 agregado árbol web: `f1eab105ee85c52e8d7c88c7fc34b787a7582a53485a298d9d0e96dc44f941d3`

## Android

- applicationId: `com.urbanwarriors.app`
- versionCode: `20101`
- versionName: `2.0.0-rc.13`
- Firebase: presente
- assets/www: sincronizado
- preflight: **4/5**
- único pendiente: `android/keystore.properties` / JKS local privada

No se declara APK/AAB signed generado.

## Secret scan

Hallazgos en paquete fuente R35:
- `*.jks`: 0
- `*.keystore`: 0
- `keystore.properties` real: 0
- `.env*`: 0
- claves PEM/KEY/P12/PFX: 0
