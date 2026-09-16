# QA_VALIDATION_20101_R40.md

## QA específico
- R40: PASS 74/74.

## Regresión dirigida
- R39: 30/30
- R38: 67/67
- R37: 62/62
- R36: 49/49
- R35: 39/39
- R34: 33/33
- R33.1: 27/27
- R33: 52/52
- R32: 36/36

## Regresión completa
`npm test`: exit 0.

## Build
`npm run build`: exit 0.
Builder: `OK build 189 archivos · web = dist = Android`.

Verificación independiente:
- web: 189
- dist: 189
- Android assets/www: 189
- missing: 0
- extra: 0
- hash diff: 0
- SHA-256 agregado árbol web: `f521ad79f48d85700d0b3896f6577fcd8076e7e91c4a2cef33ff021aef52d003`

## Android
Preflight: 4/5.
- OK applicationId `com.urbanwarriors.app`
- OK versionCode `20101`
- OK assets/www
- OK Firebase
- PENDIENTE firma local `android/keystore.properties`

La configuración de firma y la JKS quedan deliberadamente fuera del paquete.

## Extracción limpia
ZIP candidato validado antes del cierre final:
- raíz única `KOMBAX_20101_R40_CONTINUITY_SOURCE/`;
- `testzip`: sin errores;
- manifiesto: 0 faltantes, 0 extras, 0 hashes distintos;
- R40 desde extracción: PASS 74/74;
- R39 desde extracción: PASS 30/30;
- `npm run build` desde extracción: exit 0, `OK build 189 archivos · web = dist = Android`.
