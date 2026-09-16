# Release checklist — KOMBAX 20.111 R63

## Paquete
- [x] Fuente completa derivada de R62.8.
- [x] versionCode 20111.
- [x] versionName R63 compliance.
- [x] `dist` generado.
- [x] Android web assets sincronizados.
- [x] Migración Supabase R63 incluida.
- [x] Verification SQL incluida.
- [x] Rollback conservador incluido.
- [x] Informes jurídico-técnicos incluidos.
- [x] Targeted QA PASS.
- [x] Manifest SHA-256 del contenido.

## Antes de Supabase producción
- [ ] Backup/preflight.
- [ ] Aplicar `20260912004500_kombax_r63_commercial_compliance_hardening.sql` en staging.
- [ ] Ejecutar `verify_r63_commercial_compliance.sql`.
- [ ] QA autenticada adulto / 16–17 / <16.
- [ ] QA vendedor/organizador verificado/no verificado.
- [ ] QA notice-and-action y moderación.
- [ ] QA cancelación/refund.

## Antes de Netlify/GitHub
- [ ] Revisar variables y secretos fuera del repo.
- [ ] Confirmar `npm run build` en runner con dependencias disponibles.
- [ ] Review de diff R63.
- [ ] Tag/release según política del proyecto.

## Antes de Android / Google Play
- [ ] `keystore.properties` local autorizado.
- [ ] JDK/Gradle con red/cache disponible.
- [ ] `assembleRelease` / `bundleRelease`.
- [ ] Firma verificada.
- [ ] Instalar APK/AAB en dispositivo real.
- [ ] QA safe-areas, checkout externo, deep links, FCM y back navigation.
- [ ] Subir primero a Internal Testing.

## Antes de venta pública
- [ ] Datos legales reales en Terms/Privacy.
- [ ] Revisión legal final.
- [ ] Revisión fiscal DAC7.
- [ ] Stripe TEST E2E y webhooks.
- [ ] Safety Gate/point of contact si se confirma obligación.
