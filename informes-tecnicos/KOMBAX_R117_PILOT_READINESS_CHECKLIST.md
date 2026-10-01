# KOMBAX R117 — Pilot Readiness Checklist

Fecha: 2026-10-01 · build 20170 · piloto 01/10/2026–15/11/2026

| Estado | Área | Resultado |
|---|---|---|
| GREEN | R117 exact QA | 10/10 PASS |
| GREEN | Netlify release gate | 61 PASS / 5 P2 históricos / 0 fallos nuevos |
| GREEN | Build web/PWA/Android assets | 621 archivos alineados |
| GREEN | Netlify sin google-services.json | Simulación GitHub/CI PASS |
| GREEN | Firebase Android local | google-services.json presente y package correcto |
| GREEN | Android package | com.urbanwarriors.app |
| GREEN | API Android | compileSdk 36 / targetSdk 36 |
| GREEN | Android versionCode | 20170 |
| GREEN | Cuenta gratuita / 8 recorridos | Preservado |
| GREEN | Miembro/Practicante Social | Requiere club confirmado |
| GREEN | Competidor | Solicitud directa/evolución + verificación |
| GREEN | Precios piloto | Ocultos públicamente |
| AMBER | Firma Google Play | upload key externa requerida |
| AMBER | Gradle compile en este entorno | No validado por bloqueo de red del contenedor |
| AMBER | Supabase delta R116 | aplicar preflight/patch/postflight antes del piloto remoto |
| AMBER | Edge functions | desplegar/validar health, push e informe Owner |
