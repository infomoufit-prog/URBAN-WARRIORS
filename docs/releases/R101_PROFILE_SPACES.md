# R101 · Espacios por perfil

## Cambios

- Media / Creador abre **Mi contenido**. El centro muestra sus publicaciones recientes de Social y su álbum, con accesos para publicar, ver el perfil público y abrir Showcase. El contenido se obtiene de los RPC existentes del propietario.
- Social distingue expresamente **Miembro** (participación y afiliación al club) de **Competidor** (identidad deportiva, verificación y Discovery). El directorio identifica a Media / Creador por su propio tipo.
- La cuenta Miembro se detecta desde la membresía activa aunque aún no haya activado Social. Solo puede solicitar Competidor, sin cambiar el tipo de la cuenta.
- El Competidor verificado con capacidad `showcase.publish` puede abrir **Mi Showcase · vendedor**, completar una solicitud de vendedor y continuar con políticas y Stripe. La identidad deportiva, la verificación de vendedor y el derecho a cobrar por Commerce siguen siendo pasos distintos.
- El centro privado de Showcase admite perfiles directos sin `club_id`. La migración 273 conserva el alcance multiclub y añade Media / Creador al selector de proveedores autorizado.

## Verificación

- Prueba de política de cuentas: 15 escenarios.
- Pruebas de hubs R29 y matriz R32.
- Comprobación sintáctica de los módulos JavaScript modificados y build web/Android.

## Límite operativo

La migración `273_kombax_media_content_member_showcase_r101.sql` se aplicó al proyecto Supabase conectado el 26 de septiembre de 2026. Debe aplicarse también en otras instalaciones antes de validar cuentas reales nuevas. R101 no activa Commerce ni Stripe por sí misma: el vendedor debe completar su verificación y disponer de la capacidad comercial correspondiente.
