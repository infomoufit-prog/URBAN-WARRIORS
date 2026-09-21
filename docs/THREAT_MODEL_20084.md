# KOMBAX 20.084 · Threat Model de piloto

## Activos críticos
- Identidad y sesiones de usuarios.
- Datos de menores/tutores y expedientes de socios.
- Documentos privados y justificantes.
- Finanzas: cargos, pagos, recibos, informes y snapshots.
- Chats y relaciones privadas.
- Permisos de club, perfiles directos y moderación.
- Sesión Owner/Soporte y auditoría privilegiada.
- Claves de firma Android, secretos de plataforma y service role.

## Fronteras de confianza
1. Navegador/PWA ↔ Supabase Auth/REST/Storage/Functions.
2. APK WebView ↔ `kombax.es`/Supabase/FCM.
3. Club A ↔ Club B (frontera tenant obligatoria).
4. Identidad KOMBAX global ↔ workspace privado de un club.
5. Usuario normal ↔ Equipo/Moderador ↔ Owner.
6. Cliente público ↔ Edge Functions/service role.
7. Producción ↔ backups/restauración.

## Amenazas bloqueantes
- IDOR o sustitución de IDs para acceder a otro club.
- Mezcla de identidad Social/Showcase/chat entre workspaces.
- Escalada a Dirección/Moderador/Owner.
- Compromiso de contraseña Owner o sesión privilegiada.
- Bypass de AAL2/soporte temporal.
- Exposición de `service_role`, keystore o secretos.
- URL/path de Storage de otro tenant.
- XSS/token theft desde PWA/WebView.
- Recurrencias financieras duplicadas o activación prematura.
- Manipulación/borrado no autorizado de pagos/recibos/informes.
- Supply-chain/dependencia o build release alterado.
- Pérdida de datos sin restauración verificada.
- Abuso de signup/login/OTP/mensajería/uploads.

## Controles implementados o heredados
- RLS por club en tablas críticas; vistas financieras `security_invoker`.
- Gateway e idempotencia en mutaciones financieras.
- Context isolation 20083 para club + actor + conversación.
- Storage privado/signed URLs para informes y documentos sensibles según flujo.
- Sesiones Owner temporales, entidad de soporte explícita y auditoría.
- 20.084: TOTP/AAL2 Owner, wrapper fail-closed, rate limit de entrada a soporte y revocación del bypass v114.
- 20.084: gate Security Pilot antes de Finance live.
- 20.084: Android cleartext/backup/debug hardening y headers web adicionales.
- 20.084: checklist de evidencia; ningún control externo se auto-certifica.

## Riesgos que requieren evidencia antes del piloto
- Leaked Password Protection realmente activado en Supabase Auth.
- MFA Owner realmente enrolado y probado en AAL2.
- Restore drill realizado.
- QA hostil Club A/B sin cruces.
- APK/AAB release realmente firmada desde el checkout final.
- Headers de producción comprobados tras deploy.
- Advisors re-ejecutados después de migraciones.
- Secret scan local/histórico del checkout usado para release.

## Criterio de aceptación
No se declara `Pilot Security Ready` por existencia de código. Solo cuando el estado v149 indique todos los controles obligatorios verificados y las pruebas del entorno real no detecten cruces de tenant, bypass privilegiado ni anomalías financieras bloqueantes.
