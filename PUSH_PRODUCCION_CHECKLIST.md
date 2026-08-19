# Checklist Push · Urban Warriors RC10

> **HISTÓRICO / NO CERTIFICA BUILD 20025.** Usar `ANDROID_STUDIO_KOMBAX_RC13_BUILD_20025.md`; FCM real sigue siendo una puerta externa.

## Seguridad Android previa

- Firebase se inicializa de forma explícita y tolerante a ausencia de configuración.
- La aplicación puede arrancar y usarse aunque FCM falle.
- El token se obtiene de forma asíncrona después de inicializar Firebase.
- El usuario concede el permiso mediante el diálogo oficial de Android.
- Si Android no vuelve a mostrar el diálogo, la app abre los ajustes de notificaciones.
- La renovación queda en preferencias locales y se registra al volver a la interfaz autenticada.

## Lo que ya aporta el código

- Registro de dispositivos/token push.
- Resincronización del token almacenado al iniciar sesión.
- Preferencias: general, finanzas, sesiones y Comunidad.
- `notification-dispatch` con Firebase Cloud Messaging.
- `payment-reminders` limitado a notificaciones financieras.
- Ruta/deep-link conservada al tocar una notificación Android.
- Desactivación de tokens que Firebase identifica como inválidos.
- Registro de intentos/errores de push en el backend existente.

## Lo que debe configurarse en producción

1. Proyecto Firebase correspondiente a la app Android definitiva.
2. Archivo real `android/app/google-services.json`.
3. Secreto Supabase `FIREBASE_SERVICE_ACCOUNT_JSON` con la credencial de servicio Firebase.
4. Secreto `UW_CRON_SECRET` para proteger las invocaciones programadas.
5. Desplegar las Edge Functions `notification-dispatch` y `payment-reminders`.
6. Programar su invocación periódica con el secreto correcto.
7. Conceder permiso de notificaciones en Android 13+ cuando el sistema lo solicite.

## Certificación mínima en teléfono físico

Con la aplicación cerrada, verificar:
- publicación oficial → llega push y abre Comunicaciones;
- cancelación/cambio de sesión → llega push y abre Sesiones;
- cuota/aviso de cobro → llega push y abre Finanzas;
- preferencia desactivada → no se envía la categoría desactivada;
- token nuevo tras reinstalación/login → queda sincronizado.

## No confundir

Una notificación guardada en Supabase y visible al abrir la app es **in-app**. El MVP solo debe declararse con push certificado cuando la notificación aparece en el dispositivo con la aplicación cerrada.
