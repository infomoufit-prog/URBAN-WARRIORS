# KOMBAX 20.084 · Auth Security

## Owner

20.084 añade MFA TOTP real para la cuenta Owner usando Supabase Auth.

Flujo de activación:
1. Aplicar migración 149, manteniendo `owner_mfa_required=false`.
2. Entrar una vez a la Consola Owner con la contraseña actual.
3. Abrir la pestaña **Seguridad**.
4. Pulsar **Configurar y exigir MFA Owner**.
5. Escanear el QR con una aplicación autenticadora y validar el código de seis dígitos.
6. El cliente comprueba que el JWT ha alcanzado `aal2`.
7. `app_kombax_security_owner_mfa_enforce_v149('EXIGIR MFA OWNER')` deja el requisito activo.
8. Desde ese momento `app_kombax_es_platform_admin_v055`, la apertura de la sesión Owner v139 y las sesiones de soporte exigen AAL2.

No habilitar `owner_mfa_required` manualmente antes de verificar un factor TOTP; hacerlo podría dejar al Owner sin vía normal de entrada.

## Usuarios piloto

MFA no se fuerza globalmente en 20.084. El piloto mantiene login normal para Club, Dirección, Equipo, Alumno/Familia y perfiles KOMBAX. El objetivo es no añadir fricción a los testers mientras la cuenta privilegiada Owner queda protegida con segundo factor.

## Configuración Supabase Auth obligatoria antes de declarar Pilot Security Ready

- Activar **Leaked Password Protection**.
- Mantener confirmación de correo en los flujos donde corresponda.
- Mínimo de contraseña: al menos 8; para cuentas administrativas se recomienda contraseña larga y única gestionada con password manager.
- Mantener rate limits de Auth y revisar CAPTCHA antes de una apertura pública masiva.
- Revisar sesiones. Para el piloto no se cambia automáticamente la política global de sesiones; la sesión privilegiada Owner de KOMBAX sigue siendo temporal e independiente.

`leaked_password_protection` no se marca automáticamente como verificado: debe existir evidencia real de la configuración de plataforma.
