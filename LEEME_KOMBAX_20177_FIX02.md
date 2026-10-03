# KOMBAX 20177 R118 FIX02

Esta entrega sustituye FIX01 y conserva la base GitHub main 7dd7c7ed39df13bb67880685c7c2df875b43f267, build 20177. No cambia a una versión 20178 inexistente en esa base. La guía FIX01 se conserva como historial; su indicación de Supabase pendiente ya está superada para el proyecto poggsobhtutbuagjiydc.

## Reunir y utilizar el proyecto

1. Descarga las cuatro partes KOMBAX_20177_R118_FIX02.zip.001 a .004 y UNIR_KOMBAX_20177_FIX02.cmd en la misma carpeta de tu escritorio.
2. Ejecuta el CMD. Reúne el ZIP y verifica su SHA-256; después extrae el ZIP completo. No extraigas las partes por separado.
3. Haz copia de seguridad de tu carpeta GitHub. Conserva su .git y tus archivos privados de Firebase y firma Android. Copia el contenido del proyecto extraído a tu carpeta de trabajo; elimina el antiguo pnpm-lock.yaml si sigue allí.
4. Con Node 22 y npm 10 ejecuta KOMBAX_20177_VERIFY_LOCAL.cmd. Cuando termine puedes revisar los cambios y hacer tu propio push a origin. Netlify utilizará npm y netlify.toml. No se ha realizado ningún push ni despliegue web por el agente.

## Supabase ya activado

Se han aplicado la reparación de verificación Owner R118, el planificador cada minuto, el disparador de identidad corregido y la preferencia de idioma. Las funciones Owner v7, worker v2 y health v41 están activas. No repitas la activación en este proyecto; los SQL se entregan para trazabilidad o para otro entorno.

La IA puede aprobar evidencia legible y elegible de adultos con riesgo bajo y suficiente confianza. Los documentos dudosos, incompletos, caducados, no legibles o fuera del alcance se derivan a Owner. Owner conserva la revisión manual. Los archivos permanecen privados. Activar el procesador no equivale a haber probado una aprobación con documentos de usuarios reales.

## Alta de los cuatro clubes

La cuenta personal es gratuita; el alta del Club no requiere tarjeta ni pago. Requiere correo confirmado, nombre del Club y declaración. Concede Premium temporal del piloto. El límite de cuatro Clubs se comprobó en la base real; hay uno registrado y tres plazas libres después de deshacer las pruebas. El registro está abierto hasta ocuparlas: el Owner da la autorización verbal, no existe una lista de correos ni código de invitación.

La ventana de alta cierra el 16/11/2026 a las 00:00 de Madrid. La configuración marca operaciones del piloto desde el 05/10/2026 a las 00:00 de Madrid. El Club se conserva después; el beneficio Premium temporal tiene su propio vencimiento.

## Pendientes concretos

Stripe: la cuenta conectada figura con action_required y charges_enabled/payouts_enabled false. El titular debe completar datos de negocio y representante, cuenta bancaria, términos y comprobaciones de identidad en el alta alojada por Stripe, desde el Centro de pagos. No se sustituyen ni inventan esos datos. Faltan una compra de prueba, confirmación de webhook, recibo y reembolso de prueba.

El envío comercial por correo figura sin configurar en las ejecuciones del despachador. Las notificaciones internas y push son canales diferentes. Falta comprobar recepción de invitaciones, confirmación y recuperación de correo con una cuenta real de prueba autorizada.

Android: conserva google-services.json y tu firma privada. Usa KOMBAX_20177_ANDROID_QA.cmd y KOMBAX_20177_ANDROID_PLAY.cmd. Esta entrega no incluye APK/AAB compiladas ni confirma su compilación nativa; siguen siendo necesarias la configuración Firebase, firma y pruebas en dispositivo.

Consulta ESTABILIZACION_PILOTO_FIX02.md antes de considerar certificado el piloto completo. Las tres incidencias de traducción heredadas están documentadas; npm test estricto todavía las detecta.
