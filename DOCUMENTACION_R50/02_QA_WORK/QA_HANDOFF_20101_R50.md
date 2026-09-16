# QA HANDOFF · KOMBAX 20.101 R50

## Estado
Candidata PRE-QA. Automatización local y backend R50 verificados; queda QA manual autenticada en dispositivo antes de declarar release de producción.

## Contratos a validar manualmente
1. KOMBAX Social: foto horizontal se presenta 16:9; vertical 9:16; cuadrada 1:1.
2. KOMBAX Social: vídeo horizontal/vertical/cuadrado respeta la misma geometría de presentación.
3. `Mostrar completo` no corta caras ni extremos; `Rellenar marco` permite recorte controlado y foco.
4. Tap/click abre el archivo original completo en visor fullscreen con `contain`.
5. Subida MP4 cercana a 60 s y HD funciona para identidad miembro, Club y Perfil Directo.
6. KOMBAX Events: multimedia mantiene 16:9 / 9:16 / 1:1 y fullscreen completo sin degradar Main Event, Co-Main ni Fight Card.
7. Eventos/publicaciones existentes siguen renderizando correctamente.

## Gates automatizados del cierre
- R44: 25/25 PASS.
- R47: 28/28 PASS.
- R48: 28/28 PASS.
- R49: 29/29 PASS.
- R50: 40/40 PASS.
- `npm test`: EXIT 0.
- build: 189 web = 189 dist = 189 Android.
- paridad runtime: 0 faltantes, 0 extras, 0 diferencias SHA.
- Android preflight: 4/5; firma local pendiente por ausencia deliberada de `android/keystore.properties`.

## Nomenclatura
El runtime activo usa **KOMBAX Social** y **KOMBAX Events**. No deben reintroducirse las denominaciones antiguas.

## HOLD
Datos personales reales y release firmada permanecen HOLD hasta QA manual + cierre de hardening global.
