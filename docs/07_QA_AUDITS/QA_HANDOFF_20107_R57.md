# QA HANDOFF · KOMBAX 20.107 R57

## Objetivo

Baseline candidata para estabilización QA/Work con un único ajuste frontend en KOMBAX Social: identidad y normas extensas fuera del flujo principal.

## Validación manual prioritaria

1. Entrar en KOMBAX Social en móvil y desktop.
2. Confirmar que no aparece `ACTUAR COMO` como tarjeta entre cabecera y tabs/feed.
3. Confirmar que no aparecen los paneles grandes de política temática y `Cómo funciona KOMBAX Social` antes del feed.
4. Confirmar que el icono de información es visible y accesible.
5. Abrir Información y comprobar identidad activa, cambio de identidad (si hay varias), política temática y normas completas.
6. Cambiar identidad desde el panel y comprobar que Social se renderiza con la nueva identidad.
7. Confirmar que `+ Publicar con multimedia` sigue abriendo el editor.
8. Confirmar que el compositor muestra la identidad con la que se publicará.
9. Confirmar que permanece `Solo contenido de combate` dentro del compositor.
10. Crear texto, foto y vídeo; validar publicación, portada, audiencia, feed y apertura de perfil.
11. Revisar Perfiles, Guardados, Mi red, Mensajes y Seguridad; el botón de información debe seguir accesible.
12. Ejecutar pruebas en PWA y APK físico con la misma cuenta.

## Automatización

- R47 Social visibility/media: PASS
- R49 Social+Events: PASS
- R53 network/profile/events: PASS
- R56 profile UX: PASS
- R57 focal: 25/25 PASS
- `npm test`: EXIT 0
- `npm run release:build`: EXIT 0
- Web/Dist/Android: 191/191/191, 0 faltantes, 0 extras, 0 diferencias SHA.

## Android / Play

- applicationId: `com.urbanwarriors.app`
- versionCode: 20107
- versionName: `2.0.0-rc.13-r57-qa-freeze`
- Debug expected: `artifacts/KOMBAX_20107_R57_QA_FREEZE_DEBUG.apk`
- Play expected: `artifacts/KOMBAX_20107_R57_QA_FREEZE_GOOGLE_PLAY.aab`
- APK binary no compilado en el sandbox: Gradle wrapper queda bloqueado por DNS a `services.gradle.org`.
- Play preflight: 4/5; pendiente `android/keystore.properties` local.

## Netlify

- `netlify.toml` conserva `npm run release:build` y `publish = "dist"`.
- `release:build`: PASS.
- No se ha desplegado Netlify desde esta entrega.

## Backend

No hay migración de DB R57. El Edge Function `health` se ha actualizado a build 20107 (v19). No se han modificado Events, Showcase, perfiles públicos ni repositorios.
