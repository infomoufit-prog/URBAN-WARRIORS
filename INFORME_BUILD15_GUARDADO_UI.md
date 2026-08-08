# Urban Warriors 1.6.0 build 15 · Corrección del flujo de guardado UI

## Incidencia observada en producción

Tras certificar Supabase (9/9 controles OK) y comprobar desde el navegador que `window.UW_STORE.runFinalDiagnostic()` devolvía `ok: true`, al pulsar Guardar en formularios modales no aparecía ninguna petición `app_mutate_v160` en Network. Por tanto, el fallo estaba antes del backend: la interfaz no estaba entrando de forma fiable en el flujo de submit.

## Corrección aplicada

Se ha sustituido el submit implícito de los modales por una ruta explícita:

1. El botón principal de cada modal pasa de `type="submit"` a `type="button" data-action="submit-modal-form"`.
2. El despachador global de clics captura `submit-modal-form`.
3. Se localiza el formulario padre.
4. Se ejecuta `form.reportValidity()` para mantener la validación HTML nativa.
5. Si el formulario es válido, se llama explícitamente a `handleSubmit()`.
6. `handleSubmit()` conserva toda la lógica existente: bloqueo visual, llamadas `store.*`, mensajes de error, `finishMutation()`, recarga y toast de éxito.

No se ha modificado Supabase, migraciones, RPC, RLS, `data-store.js`, contrato 1.6.0 ni arquitectura de persistencia.

## Archivos funcionales modificados

- `web/js/app.js`
- `scripts/test-governance-v160.mjs`

## Bump de build

- `web/config.js`: build 15
- `web/index.html`: cache-bust b15
- `web/service-worker.js`: cache build15 / b15
- `android/app/build.gradle`: versionCode 15
- `scripts/test-production-v160.mjs`
- `scripts/test-receipts-v160.mjs`
- assets Android regenerados desde `web/`

## Controles antirregresión añadidos

- El botón de guardado modal debe usar `data-action="submit-modal-form"`.
- El despachador debe ejecutar `reportValidity()` y después `handleSubmit()`.

La suite de gobernanza pasa de 31 a 33 controles.

## Validación ejecutada

- `node --check web/js/app.js`: OK
- `npm test`: OK (33 controles de gobernanza y resto de suites; la prueba SQL real se omite en este entorno si no existe PGlite, con aviso explícito)
- `npm run build`: OK
- `web ↔ dist ↔ Android`: 23 archivos idénticos

## Alcance

Este build corrige específicamente el fallo de activación de guardado observado en la UI. La certificación final sigue siendo una prueba funcional en producción: abrir un modal, guardar una disciplina y comprobar que aparece `app_mutate_v160` y que el registro permanece tras recargar.
