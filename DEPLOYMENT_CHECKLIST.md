# Urban Warriors · Lista de despliegue inicial

1. Editar `web/config.js`: desactivar demo y añadir URL/clave pública de Supabase y URL de Netlify.
2. Ejecutar en Supabase SQL Editor, por separado y en orden, las migraciones `001` a `005`.
3. Ejecutar `supabase/setup/bootstrap_urban_warriors_club.sql`.
4. Crear el bucket privado `justificantes-pago`.
5. Configurar Supabase Auth y crear la primera cuenta de dirección.
6. Publicar una rama de preproducción en Netlify y probar los permisos RLS.
7. Desplegar la Edge Function `payment-reminders`, añadir `UW_CRON_SECRET` y programar Cron.
8. Solo después de validar seguridad y alarmas, desplegar producción.
9. Configurar Firebase y generar APK firmado en una fase posterior.

No ejecutar `supabase/seed.sql` en producción ni los archivos de `docs/reference/`.
