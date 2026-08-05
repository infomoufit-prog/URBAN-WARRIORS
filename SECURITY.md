# Seguridad

## Aplicado en el código

- `club_id` en los datos de negocio y relaciones compuestas para impedir cruces entre clubes.
- RLS en las tablas principales.
- Funciones `security definer` con `search_path` fijo.
- Operaciones de cobro sensibles mediante RPC.
- Justificantes en un bucket privado, con rutas `club_id/socio_id/archivo` y URL firmada temporal.
- Historial idempotente de avisos.
- Dirección, secretaría y economía pueden gestionar cobros; monitores no.
- La familia solo comunica pagos de socios vinculados.
- La `service_role` y el service account de Firebase permanecen en servidor.

## Obligatorio antes de datos reales

- Ejecutar las migraciones en un proyecto de prueba y verificar su sintaxis real.
- Probar RLS con usuarios de clubes distintos.
- Revisar permisos de Storage con archivos reales.
- Configurar recuperación de contraseña, confirmación de correo y rate limiting/CAPTCHA.
- Sustituir textos legales provisionales.
- Crear copias de seguridad y política de retención.
- Realizar revisión jurídica de privacidad, menores y derechos de imagen.
