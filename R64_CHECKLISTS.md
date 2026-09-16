# KOMBAX 20.112 R64 - Checklists

## Supabase
- [ ] Revisar migraciones 20260912210000..214000 en staging.
- [ ] Aplicar en orden.
- [ ] Verificar RLS/GRANT.
- [ ] Validar catalog/context RPCs.
- [ ] Validar fee resolver 1,5 % / 0 %.
- [ ] Validar Commerce temporal y expiración.
- [ ] Validar Promotions/72h/2 al día.
- [ ] Validar Ticketing incluido por Enterprise.
- [ ] Validar Partner mensual; mantener anual pendiente.
- [ ] No aplicar a producción sin autorización.

## Stripe
- [ ] Staging/test mode con connected account Standard.
- [ ] Direct charge sigue creándose en connected account.
- [ ] Club/Premium/Brand Start/Growth: application fee 1,5 %.
- [ ] Enterprise/Brand Enterprise: 0 %.
- [ ] Ticketing: buyer fee 1,50 € separado y trazable.
- [ ] Refund/reversal proporcional.
- [ ] Gran Evento >1.000 bloquea automatización estándar cuando corresponda.
- [ ] No ejecutar live mode sin autorización.

## Netlify/PWA
- [ ] Build estático web/dist validado.
- [ ] Variables de entorno correctas.
- [ ] PDF comercial accesible.
- [ ] Plan y servicios responsive.
- [ ] No deploy sin autorización.

## Android
- [x] versionCode 20112.
- [x] assets web sincronizados.
- [x] Firebase config presente.
- [ ] keystore.properties local y archivo de firma disponibles.
- [ ] APK debug QA opcional.
- [ ] APK/AAB release solo tras autorización.
- [ ] Play Console solo tras autorización.

## QA manual autenticada
- [ ] Club / Premium / Enterprise.
- [ ] Brand Start/Growth/Enterprise.
- [ ] Federation/Partner.
- [ ] Founder alta/continuidad/baja/realta.
- [ ] 18+ Showcase/Events.
- [ ] Commerce temporal/cooldown.
- [ ] Destacar Event y producto + Social.
- [ ] Ticketing + QR + puerta + refund.
- [ ] Assist/Migrations counters.
