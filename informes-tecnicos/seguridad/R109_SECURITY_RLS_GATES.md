# R109 · Seguridad, RLS, RPC y gates

## Verificaciones ejecutadas

- La migración R109 es aditiva y no crea tablas ni elimina datos.
- `competidor` deja de aceptarse como autorización desde `raw_user_meta_data` de signup.
- `app_kombax_application_validate_v072` sigue siendo RPC interna: sin `EXECUTE` para `PUBLIC`, `anon` ni `authenticated`.
- El trigger de tipo de cuenta tampoco es ejecutable directamente por esos roles.
- Las RPC de usuario (`app_kombax_perfil_mutate_r58`, Social mutate/helpers) no son ejecutables por `PUBLIC`/`anon`; `authenticated` conserva el acceso intencional preexistente.
- Los gates Social consultan ownership (`auth.uid()`), estado activo, verificación y edad backend; no dependen de ocultar botones.
- Miembro conserva comprobación de identidad social + socio activo.
- Competidor requiere fecha de nacimiento verificada; Profesional usa la tabla privada v196.

## Advisors Supabase

El Advisor posterior a R109 no detecta hallazgos de rendimiento asociados a las funciones modificadas. El Advisor global reporta 201 avisos informativos `rls_enabled_no_policy`, 51 avisos `anon_security_definer_function_executable`, 561 avisos `authenticated_security_definer_function_executable` y 1 aviso de `auth_leaked_password_protection`; son inventario global del proyecto, no hallazgos creados por R109. Mantiene avisos globales heredados, entre ellos RPC `SECURITY DEFINER` autenticadas y tablas internas con RLS sin políticas públicas. Para las RPC R109 expuestas a `authenticated`, el uso es intencional y se conservan comprobaciones internas de identidad/ownership.

Avisos globales relevantes que no pertenecen al alcance R109:

- `authenticated_security_definer_function_executable`: patrón ampliamente existente; requiere revisión específica función por función antes de cualquier refactor. Referencia: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- `auth_leaked_password_protection`: protección de contraseñas filtradas desactivada. Referencia: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

**Pendiente recomendado antes/ durante piloto:** habilitar Leaked Password Protection desde configuración Auth si el plan/configuración del proyecto lo permite, y mantener revisión de Advisors como control recurrente.
