# KOMBAX 20.084 — Security Go-Live

Objetivo: cerrar la última capa de seguridad antes del piloto sin rehacer RC13.

## Implementado en código
- Gate global de seguridad del piloto, apagado por defecto.
- Inventario de SECURITY DEFINER visible solo al Owner.
- Controles/evidencias de seguridad inmutables para usuarios normales.
- MFA TOTP Owner integrado en la consola: QR, challenge/verify, elevación a AAL2 y enforcement fail-closed.
- Entrada Owner/Soporte v149 con rate limit y AAL2 obligatorio una vez activado el enforcement.
- La apertura de la sesión Owner v139 y el helper global de autorización v055 quedan envueltos por el requisito AAL2 cuando se activa.
- Revocación de EXECUTE autenticado del bypass de inicio v114.
- Recurrencia financiera real bloqueada hasta que Security Pilot esté habilitado.
- Finance pilot activation bloqueada hasta Security Pilot.
- Reset de intenciones privadas en cambios de workspace y banner permanente de modo soporte.
- Patch de hardening Android y cabeceras Netlify aditivas.

## Controles manuales obligatorios antes de HABILITAR PILOTO KOMBAX
1. leaked_password_protection: activar en Supabase Auth y documentar evidencia.
2. owner_mfa_aal2: desde Consola Owner → Seguridad, enrolar TOTP, verificar AAL2 y activar el enforcement. La UI llama a `app_kombax_security_owner_mfa_enforce_v149('EXIGIR MFA OWNER')` solo después de una verificación correcta.
3. backup_restore_drill: restauración comprobada en entorno seguro.
4. incident_runbook: responsable, revocación de sesiones/secretos y comunicación definidos.
5. android_release_security: APK/AAB release firmada, no debug, no cleartext, sin secretos.
6. two_club_isolation_e2e: pruebas hostiles Club A/Club B.
7. security_advisors_triaged: revisión final de advisors después de aplicar migraciones.
8. secrets_repository_review: búsqueda de service_role, tokens, keystore, claves y credenciales históricas.
9. netlify_security_headers: verificar headers sobre kombax.es.

Nunca marcar automáticamente un control externo como verificado.
