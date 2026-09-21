# KOMBAX 20.084 · Runbook de último deploy y piloto

## Etapa A · Antes del deploy
1. Congelar el checkout exacto que recibirá 20.084.
2. Guardar commit/tag y hash del candidato.
3. Confirmar que no hay secretos/keystore dentro del árbol.
4. Confirmar backup/PITR disponible y preparar el restore drill.
5. Ejecutar tests 20079 → 20084.

## Etapa B · Backend
1. Aplicar 143 → 149 en orden.
2. No activar ningún flag financiero ni `pilot_security_enabled` por SQL directo.
3. Desplegar `finance-recurring` y `finance-report`.
4. Ejecutar advisors de seguridad/performance.
5. Verificar RLS, Storage privado y contratos.

## Etapa C · Auth Owner
1. Activar Leaked Password Protection en Supabase Auth.
2. Entrar en Owner con contraseña mientras `owner_mfa_required=false`.
3. Consola Owner → Seguridad → Configurar y exigir MFA Owner.
4. Escanear QR TOTP y validar código.
5. Salir completamente y probar una entrada nueva: contraseña → TOTP → Owner.
6. Probar que contraseña sola ya no abre Owner/Soporte.

## Etapa D · Web/PWA
1. Merge de headers 20.084 sin romper CSP/connect-src Supabase/FCM.
2. Deploy `kombax.es`.
3. Limpiar/actualizar service worker.
4. Verificar headers reales de producción.
5. Probar cambio Club A ↔ Club B ↔ perfil directo ↔ Owner/Soporte.

## Etapa E · Android / Google Play tester
1. Aplicar patch Android 20.084 y `versionCode 20084`.
2. Build release firmado desde Android Studio con el keystore fuera del repositorio.
3. Validar APK local: sin cleartext, sin WebView debug, sin backup, deep links correctos.
4. Generar AAB release de la misma fuente.
5. Subir al track de testing correspondiente en Google Play.
6. Instalar desde Play en al menos dos dispositivos/cuentas de prueba cuando sea posible.

## Etapa F · QA hostil 2 clubes / ~20 usuarios
Ejecutar `PILOT_QA_2_CLUBS_20_USERS_20084.md` con cuentas reales de prueba y mezcla deliberada de IDs, pestañas, sesiones, soporte, Storage y finanzas.

## Etapa G · Evidencias y apertura
1. Registrar evidencia para cada control pendiente mediante Owner AAL2.
2. Re-ejecutar Security Advisors después de las migraciones.
3. Confirmar `app_kombax_security_status_v149().pilot_ready=true`.
4. Solo entonces ejecutar la habilitación explícita `HABILITAR PILOTO KOMBAX` desde un flujo administrativo controlado.
5. Finance recurring sigue sujeto además a sus gates Shadow/QA/Finance Pilot; Security Pilot no los sustituye.

## Rollback
Ante cruce de tenant, bypass Owner, anomalía financiera bloqueante o exposición de secreto: cerrar Security Pilot/Finance recurring, cerrar sesiones privilegiadas, volver al release conocido y aplicar `INCIDENT_RESPONSE_MINIMUM_20084.md`. No borrar evidencias ni registros financieros.
