# KOMBAX RC13 build 20066 · Validación QA de registro y solicitud de Club

## Correcciones

- El acceso “Formo parte del equipo” abre el selector de invitación existente y deja de llamar a una función inexistente.
- Una solicitud nueva exige seleccionar el documento acreditativo que la validación de Supabase ya requiere.
- Si el borrador se guarda pero falla el envío, el formulario permanece abierto, los datos se conservan y se informa de que existe un borrador.
- Los errores seguros de documento o campos obligatorios se traducen a mensajes concretos; el error original se conserva en consola para diagnóstico.
- No se amplían permisos, no se cambia RLS y no se añade ninguna migración de base de datos.

## Resultados

1. `test-kombax-20065-role-invitations.mjs`: PASS.
2. `test-kombax-20066-qa-fixes.mjs`: PASS.
3. `build.mjs`: PASS; 68 archivos sincronizados entre Web, distribución y Android.
4. Suite histórica completa: ejecutada hasta build 20040. Se detiene en un defecto previo de `test-kombax-20040-social-affiliation-contact.mjs`, que convierte incorrectamente una URL de archivo en ruta Windows y no localiza una migración que sí está incluida. No está relacionado con los cambios 20066.

## Criterio de aceptación

- `web`, `dist` y los assets Android quedan sincronizados en build 20066.
- Las regresiones 20065 y 20066 finalizan sin errores.

## Alcance operativo

No se ha desplegado el frontend ni se ha cambiado Supabase remoto. Para comprobar el flujo de extremo a extremo hay que publicar este build y repetir la solicitud con un documento QA no personal.
