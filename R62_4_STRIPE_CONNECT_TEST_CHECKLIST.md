# R62.4 — Checklist Stripe Connect TEST

## A. Antes de tocar Stripe

- [ ] Trabajar en Supabase/Stripe TEST, no producción.
- [ ] Aplicar migración R62.4.
- [ ] Ejecutar `verify_r62_4_stripe_connect.sql` sin errores.
- [ ] Configurar `STRIPE_CONNECT_SECRET_KEY` TEST.
- [ ] Configurar `STRIPE_CONNECT_WEBHOOK_SECRET` TEST.
- [ ] Configurar `STRIPE_CONNECT_API_VERSION=2026-07-29.dahlia`.
- [ ] Configurar `KOMBAX_APP_URL` para el entorno QA.
- [ ] Desplegar `stripe-connect`, `stripe-checkout`, `stripe-webhook` solo en TEST.
- [ ] Crear webhook Stripe TEST para Connected Accounts.
- [ ] No mezclar el webhook de Connect con Stripe Billing.

## B. QA local

- [ ] `npm install`
- [ ] `npm run test:20110:r62.4`
- [ ] `npm run build`
- [ ] `npm run dev`
- [ ] Abrir `http://127.0.0.1:4173`

## C. Club

- [ ] Dirección puede ver/activar Connect.
- [ ] Alumno no puede activar Connect.
- [ ] Onboarding devuelve a KOMBAX.
- [ ] Refresh de Account Link regenera enlace autenticado.
- [ ] Estado se sincroniza con Stripe.
- [ ] `charges_enabled=false` impide Checkout.
- [ ] Cuota obtiene importe server-side.
- [ ] Pago aprobado marca cuota/pago correctamente.
- [ ] Pago rechazado no marca cuota pagada.
- [ ] Doble clic/reintento no duplica Checkout lógico.
- [ ] Webhook repetido no duplica pago.

## D. Marca / Showcase

- [ ] Gestor autorizado puede activar Connect.
- [ ] Usuario ajeno no puede activarlo.
- [ ] Estado se sincroniza con Stripe.
- [ ] Pedido obtiene precio/cantidad/proveedor server-side.
- [ ] Checkout usa la Connected Account de la Marca correcta.
- [ ] Pago aprobado concilia el pedido una sola vez.
- [ ] Marca A no puede cobrar pedido de Marca B.

## E. Federación

- [ ] Perfil Federación activo y verificado.
- [ ] Propietario/presidencia puede iniciar onboarding.
- [ ] Tesorería puede consultar estado si tiene `federation.team.finance`.
- [ ] Tesorería no puede reemplazar/crear por sí sola una Connected Account.
- [ ] Secretaría sin permiso financiero no obtiene acceso Connect por defecto.
- [ ] Onboarding devuelve a KOMBAX y sincroniza estado.
- [ ] Federación A no puede reutilizar `acct_...` de Federación B/Club/Marca.
- [ ] NO marcar pago federativo como verificado: no existe todavía un concepto federativo de Checkout server-side en esta base.

## F. Seguridad / aislamiento

- [ ] No aparece `sk_test_`, `sk_live_` ni `whsec_` real en `web/`, `dist/` o Android assets.
- [ ] `stripe_account_id` nunca se toma del navegador como fuente de verdad.
- [ ] `amount` nunca se toma del navegador como fuente de verdad.
- [ ] No existe `application_fee_amount`.
- [ ] No existe `transfer_data.destination`.
- [ ] No existe `on_behalf_of`.
- [ ] `platform_fee_minor=0`.
- [ ] Reasignación de `acct_...` existente es rechazada.
- [ ] Firma del webhook inválida es rechazada.
- [ ] Evento webhook antiguo/replay fuera de tolerancia es rechazado.

## G. Casos Stripe TEST

- [ ] Pago aprobado.
- [ ] Pago rechazado.
- [ ] 3DS/autenticación adicional.
- [ ] Checkout cancelado.
- [ ] Refund.
- [ ] Dispute (si se simula en el entorno TEST).
- [ ] Requirements pendientes/restricción temporal.

## H. Salida

- [ ] Club onboarding verificado.
- [ ] Marca onboarding verificado.
- [ ] Federación onboarding verificado.
- [ ] Club payment verificado.
- [ ] Marca payment verificado.
- [ ] Refund verificado.
- [ ] Multitenant end-to-end verificado.
- [ ] Decisión/implementación de cobro federativo antes de marcar `FEDERATION PAYMENT VERIFIED`.
- [ ] Solo entonces evaluar `PILOT READY`.
