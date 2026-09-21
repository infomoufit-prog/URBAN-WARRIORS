# KOMBAX R72 · Checklist QA / Pilot Freeze

## Automatización
- [x] Release regression: 22/22.
- [x] Commercial continuity: 18/18.
- [x] Identity + Spectator: 15/15.
- [x] Showcase Seller Center: 13/13.
- [x] Events Operations Center: 15/15.
- [x] Sidebar Product Accordions: 9/9.
- [x] Reputation + Catalog R72: 14/14.
- [x] **Total R72: 106/106**.
- [x] `npm run build` final: PASS.
- [x] Build determinista: 206 archivos.
- [x] Paridad exacta `web = dist = android/app/src/main/assets/www`.

## Supabase live
- [x] 11 migraciones canónicas R72 aplicadas.
- [x] Historial duplicado accidental detectado y normalizado a las 11 entradas canónicas, sin rollback funcional.
- [x] +25 / 30 días / 8 EUR verificado en SQL.
- [x] 4 tablas privadas de reputación presentes.
- [x] 16 RPC R72 presentes.
- [x] 2 políticas Storage R72 presentes.
- [x] 12 FKs del esquema reputación; 0 sin índice de cobertura.
- [x] Contratos QA Showcase `1.2-r72-qa` activos y marcados `pending` para revisión jurídica.
- [x] Contrato QA Events `1.3-r72-qa` activo y marcado `pending`.
- [x] Health ACTIVE v30 / build 20123.
- [x] Security + Performance Advisors revisados y documentados.

## Android
- [x] `applicationId` estable: `com.urbanwarriors.app`.
- [x] `versionCode 20123`.
- [x] Assets web embebidos.
- [x] Firebase presente.
- [ ] Firma local: falta `android/keystore.properties` en este entorno.
- [ ] APK/AAB R72: no generado; Gradle no pudo descargar 8.11.1 por `UnknownHostException: services.gradle.org`.

## Integridad
- [x] Escaneo de archivos de credenciales privadas: PASS.
- [x] Sin `.env` real, `keystore.properties`, `.jks/.keystore/.p12/.pfx/.pem/.key`.
- [x] Sin marcadores de clave privada o Stripe live secret detectados.
- [x] Manifest SHA-256 del contenido del release.
- [x] ZIP final sometido a `ZipFile.testzip()` tras empaquetado.

## Validaciones externas todavía necesarias antes de lanzamiento público
- [ ] QA manual autenticado con cuentas de todos los roles relevantes.
- [ ] Stripe E2E: onboarding seller/organizer, checkout, refund y Ticketing.
- [ ] Build Android firmado y validación en dispositivo/Play interno.
- [ ] Revisión jurídica y datos reales del operador (identidad/NIF/domicilio).
- [ ] Revisión/cierre de deuda histórica Supabase Advisor y leaked-password protection.
- [ ] Activación de SaaS Billing de KOMBAX cuando se decida comercialmente.
- [ ] Autorización explícita para despliegue Netlify/GitHub/Google Play.

**Resultado:** **QA READY · CONTROLLED PILOT FREEZE CANDIDATE**. No se etiqueta como producción pública final.
