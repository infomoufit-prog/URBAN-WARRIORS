# QA Validation · KOMBAX 20.101 R8

## Resultado automatizado
- `node scripts/test-kombax-20101-urban-warriors-jiujitsu-r8.mjs`: PASS
- batería completa `npm test`: PASS
- `node scripts/build.mjs`: PASS
- build determinista: 148 archivos · `web = dist = Android`

## Supabase
- Urban Warriors localizado de forma única: PASS
- entitlement `events.public.organize`: activo
- Owner actual también tiene rol de gestión compatible en Urban Warriors: PASS
- migración `kombax_events_urban_warriors_jiujitsu_demo_20101_r8`: aplicada
- RPC R8 presente: PASS
- evento no se prepublica en la build desplegada anterior: intencional, evita URLs de assets no desplegados.

## Multimedia
- 15/15 assets presentes
- todos WEBP
- ningún vídeo
- cada asset < 450 KB
- total aprox. 2.64 MB

## Android
El código y assets R8 están sincronizados en `android/app/src/main/assets/www`.
El JKS local original sigue presente y su SHA-256 coincide con la transferencia certificada. El preflight marca `keystore.properties` como pendiente porque las contraseñas no se incluyen deliberadamente en el ZIP; debe restaurarse localmente con `LOCAL_RELEASE_SIGNING/RESTORE_SIGNING_WINDOWS.cmd` antes de firmar una nueva release.
