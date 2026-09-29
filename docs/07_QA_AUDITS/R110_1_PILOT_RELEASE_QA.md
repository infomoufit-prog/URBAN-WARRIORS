# QA R110.1 · build 20164

- R110 Pilot Club Activation: 32/32 PASS.
- R110.1 release identity/gate: 11/11 PASS.
- Netlify release build: PASS (exit 0).
- KOMBAX legal gate: PASS.
- Netlify pilot gate: 52 PASS / 7 P2 históricos / 0 nuevos.
- R79 unresolved: 255, baseline R110 = 255, no regresión.
- Runtime-copy unresolved: 242, baseline R110 = 242, no regresión.
- build.mjs: 619 archivos; web/dist/Android parity PASS.
- Android preflight: 7/8 PASS; falta firma release en este entorno.
- Firebase Android: presente.
- Android wrapper: ejecutable.
- Compilación/firma APK+AAB: EXTERNAL VALIDATION PENDING por ausencia de keystore y falta de acceso a Gradle 8.11.1 desde este entorno.
