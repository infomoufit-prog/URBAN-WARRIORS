# Recuperación de contraseña KOMBAX · build 20049

La aplicación usa el flujo nativo de recuperación de Supabase Auth:

1. `POST /auth/v1/recover` solicita el correo de recuperación.
2. La plantilla **Reset password / Recovery** debe mostrar `{{ .Token }}`.
3. KOMBAX verifica el código con `POST /auth/v1/verify`, `type: recovery`.
4. La sesión temporal se usa únicamente para `PUT /auth/v1/user` con la nueva contraseña.
5. KOMBAX cierra la sesión temporal y devuelve al login.

En un proyecto Supabase alojado, la plantilla se configura en **Authentication → Email Templates → Reset password**. Copia el contenido de `recovery_otp_20049.html` y usa un asunto como `Código KOMBAX para cambiar tu contraseña`.

No se debe incluir service-role, secretos SMTP ni claves privadas en el frontend o en este paquete.
