# Firebase y APK — cierre final Urban Warriors 1.5.0

## Preparado en el código

- Firebase Cloud Messaging para PWA y Android nativo.
- Registro y renovación de tokens en `dispositivos_push`.
- Canal Android `urban_warriors_alerts`.
- Apertura de la app desde una notificación mediante el campo `route`.
- Edge Function `notification-dispatch` con FCM HTTP v1.
- Cinco avisos de cobro configurables y detención al pagar/validar/pausar.
- Firma release mediante variables de entorno, sin secretos en GitHub.

## Datos externos que debe aportar el propietario

1. Crear un proyecto Firebase.
2. Registrar app web y app Android `com.urbanwarriors.app`.
3. Copiar `google-services.json` a `android/app/google-services.json`.
4. Completar `web/config.js` con la configuración web y VAPID.
5. Guardar en Supabase Edge Functions el secreto `FIREBASE_SERVICE_ACCOUNT_JSON`.
6. Crear un keystore privado y definir:
   - `UW_KEYSTORE_PATH`
   - `UW_KEYSTORE_PASSWORD`
   - `UW_KEY_ALIAS`
   - `UW_KEY_PASSWORD`

Nunca subir `google-services.json`, la cuenta de servicio, el keystore ni contraseñas a un repositorio público.
