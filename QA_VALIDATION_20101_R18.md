# QA Validation · KOMBAX 20.101 R18

## Incidencias cerradas en código
1. Noche de Impacto BCN: las fotos demo ya no dependen del despliegue `kombax.es`; las rutas `/assets/demo-events/...` se resuelven contra los assets empaquetados en web/Android.
2. Urban Warriors: un único Main Event. Se endurece backend y renderer.

## Evidencia backend Urban Warriors
- RPC real: 6 combates.
- Seed idempotente ejecutado con contexto Owner: PASS.
- Resultado seed: `fight_count=6`, `participant_count=12`, `fighter_photo_count=12`, `main_event_count=1`, `single_main_event=true`.
- Lectura posterior: solo Malik Benítez vs Bruno Sato tiene `destacado=true`.

## Evidencia frontend
- `strictFlag()` evita tratar el texto `"false"` como verdadero.
- `fightCard()` usa flag estricto tanto para clase `featured` como para etiqueta `MAIN EVENT`.
- `pickMainFight()` usa el mismo criterio estricto.
- Resolver demo convierte rutas `kombax.es/assets/demo-events/...` a assets locales empaquetados sin tocar URLs HTTPS reales fuera del namespace demo.

## Tests
- R18 Demo Event Image Routing: PASS.
- R18 Single Main Event Hardening: PASS.
- Regresión completa: PASS.
- Build: `OK build 152 archivos · web = dist = Android`.

## Criterio de cierre final en dispositivo
No se considera validación visual completa hasta instalar una APK construida desde R18 y confirmar:
- BCN: 6 Fight Cards sin imágenes rotas.
- Urban: 6 Fight Cards diferentes y solo una etiqueta MAIN EVENT.
