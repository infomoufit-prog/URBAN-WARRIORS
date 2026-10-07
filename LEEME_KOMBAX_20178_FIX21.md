# FIX21 acumulativo: Meta configurado y conexión Instagram visible

7 de octubre de 2026. Basado en FIX20 completo, que se conserva intacto. FIX21 es el nombre del paquete; no incrementa el versionCode Android 20178. No contiene APK/AAB compiladas.

## Cambio de frontend

web/config.js habilita integrations.instagram.enabled para permitir la conexión desde la identidad social autorizada. Build sincroniza dist y los recursos Android. No añade permisos comerciales ni modifica clubes piloto. La autorización efectiva continúa validándose en Supabase y Meta. La app Meta sigue sin publicar: para ensayar OAuth se necesita una cuenta autorizada en los roles de la app y profesional vinculada a una Página.

## Estado real del backend y Meta

Las cuatro funciones Meta/Instagram están ACTIVE en Supabase. Migración principal y complemento de índices aplicados. Secrets configurados por el usuario; comprobación HTTP posterior: control sin JWT 401, callback sin estado 303, desautorización inválida 400 y confirmación de borrado inexistente 404. Estas respuestas validan configuración y rechazos; no acreditan OAuth real ni que los permisos avanzados estén aprobados.

Se guardaron en Meta las siguientes URLs. La de eliminación está configurada como callback, no como página de instrucciones:

- OAuth: https://poggsobhtutbuagjiydc.supabase.co/functions/v1/meta-instagram-callback
- Desautorización: https://poggsobhtutbuagjiydc.supabase.co/functions/v1/meta-instagram-deauthorize
- Eliminación: https://poggsobhtutbuagjiydc.supabase.co/functions/v1/meta-instagram-data-deletion

Meta confirmó «Se guardaron los cambios» y su validador indicó «URI de redireccionamiento válido para esta app». La configuración existente usa Graph v26.0; se configuró esa versión en Supabase. No se cambiaron permisos, roles ni se publicó la app Meta.

## Actualización manual

1. Reunir los cuatro fragmentos FIX21 con su reunificador; verificar SHA-256 y extraer.
2. Actualizar manualmente el repositorio conservando configuración local y credenciales privadas. No subir node_modules, .env, claves ni archivos de firma Android.
3. Desplegar el frontend en Netlify con el proceso habitual. Verificar que https://kombax.es/meta-instagram.html sirve el retorno actualizado y que la identidad autorizada muestra Conectar Instagram.
4. Probar OAuth con cuenta profesional vinculada a Página de Facebook, incluida en los roles de la app Meta mientras siga sin publicar. Comprobar estado y cuenta seleccionada.
5. No publicar contenido hasta autorizar expresamente cuenta y publicación. Después ensayar desconexión y eliminación sobre la conexión de prueba.

No ejecutar db push masivo sobre la base existente: las migraciones Instagram ya se aplicaron mediante conector y sus versiones registradas difieren de los archivos locales; consultar docs/qa/ACTIVACION_SUPABASE_INSTAGRAM_FIX20.md. La migración de antigüedad y finanzas históricas de FIX20 permanece empaquetada, no aplicada en esta intervención.

Los informes FIX20 describen el estado previo a la activación. Para el estado actual prevalecen este LEEME y el informe de activación. No se ha hecho commit/push/merge/PR, deploy Netlify ni publicación real en Instagram. OAuth, publicación y borrado de conexión reales siguen pendientes. App Review/Advanced Access no solicitados ni confirmados.

## Verificación de entrega

Build y regresiones finalizados: 109 PASS, tres P2 conocidos de traducción y cero fallos nuevos. Legal gate PASS. 648 archivos generados, 381 JavaScript y 926 imports locales compatibles con Linux; web/dist/Android idénticos. 32 comprobaciones de navegador aisladas con transportes simulados correctas. El primer arranque del navegador dentro del sandbox falló; al repetir fuera del sandbox pasó, sin cambiar el producto para ocultar el fallo de entorno. Consultar docs/qa/BUILD_FIX21.log. No se amplía la lista de excepciones. La integridad de los fragmentos y la ejecución real del reunificador se documentan en COMPROBACION_ZIP_FIX21.json junto al paquete.
