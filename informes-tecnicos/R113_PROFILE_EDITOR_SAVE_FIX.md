# KOMBAX R113 · build 20166 · Profile editor save fix

## Incidencia reproducida

En la APK build 20164, al pulsar **Guardar borrador** en `Preparar solicitud Competidor`, la interfaz mostraba `No se ha podido completar la operación. Inténtalo de nuevo.` y no se creaba el perfil.

## Evidencia

- La cuenta estaba autenticada y las lecturas Supabase devolvían HTTP 200.
- En la ventana del fallo no existía ningún `POST` a `app_kombax_perfil_mutate_r58` ni `app_kombax_perfil_mutate_v196`.
- El backend R111/R112 aceptaba la misma operación cuando se reproducía directamente en una transacción de prueba.
- El frontend `web/js/modules/gateway.js` construía el objeto con el shorthand JavaScript `tipo` aunque el parámetro de la función se llama `type`. Esto provocaba `ReferenceError: tipo is not defined` antes de alcanzar el repositorio/RPC.

## Corrección

Se cambia:

```js
saveProfile({ ..., tipo, ... })
```

por:

```js
saveProfile({ ..., tipo: type, ... })
```

La corrección afecta al editor común de perfiles directos, por lo que evita el mismo fallo inicial en Competidor, Marca, Federación, Profesional y Media / Creator cuando pasan por este editor.

## QA

- R113 profile editor save QA: 12/12 PASS.
- R112 release QA: 12/12 PASS.
- Netlify pilot release gate: 55 PASS, 7 P2 históricos, 0 fallos nuevos.
- Build: 619 archivos; `web = dist = Android`.
- `gateway.js` corregido es idéntico en web, dist y `android/app/src/main/assets/www`.
- Android preflight: 7/8; pendiente únicamente firma local.

## Android

R113 usa `versionCode 20166` y `versionName 2.0.0-rc.13-r113-profile-editor-save-fix`. La APK instalada build 20164 contiene assets locales y no puede recibir este hotfix desde Supabase o Netlify; debe generarse e instalarse una APK/AAB nueva para que el cambio llegue a Android.

## Supabase

No requiere una nueva migración: R111 y R112 ya están aplicadas en el proyecto activo.
