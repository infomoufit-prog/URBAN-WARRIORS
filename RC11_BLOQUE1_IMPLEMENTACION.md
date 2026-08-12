# Urban Warriors RC11 · Bloque 1 Android

Implementado sobre RC10 sin modificar `web/`, `dist/` ni Supabase.

## Cambios
- Safe area superior Android en la cabecera móvil.
- Safe area inferior reforzada para contenido, navegación y menú lateral.
- Flujo guiado de permiso push Android.
- Botón para abrir ajustes si las notificaciones están bloqueadas/denegadas.
- Registro/renovación del token FCM al conceder permiso.
- Preferencias push personales ocultas en la APK.
- En APK, las cuatro categorías push se fuerzan activas para el perfil autenticado.
- Versionado Android a `2.0.0-rc.11` / `versionCode 20011`.
- Se mantiene el workaround de lint de release ya usado en la generación anterior.

## No modificado
- `web/` y `dist/` (Netlify/PWA RC10 permanecen intactos).
- Esquema, migraciones y funciones Supabase.
- Firebase Messaging Service y contrato de `push.registrar`.

## Prueba obligatoria antes de dar RC11 por cerrada
1. Instalar la APK RC11 encima de RC10.
2. Iniciar sesión con notificaciones sin conceder.
3. Confirmar que aparece el aviso guiado.
4. Pulsar Activar y aceptar el permiso de Android.
5. Verificar que el token aparece en `dispositivos_push`.
6. Enviar un push real con la app en segundo plano/cerrada.
7. Confirmar visualmente cabecera y parte inferior en Pixel 8.
