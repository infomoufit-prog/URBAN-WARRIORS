# R62.5 · Checklist de validación TEST

## Preparación
- [ ] Aplicar la migración R62.5 en Supabase TEST.
- [ ] Ejecutar `verify_r62_5_showcase_events_ticketing.sql`.
- [ ] Desplegar `stripe-connect`, `stripe-checkout` y `stripe-webhook` en TEST.
- [ ] Confirmar `STRIPE_CONNECT_SECRET_KEY`, `STRIPE_CONNECT_WEBHOOK_SECRET` y `KOMBAX_APP_URL` del entorno TEST.
- [ ] Confirmar webhook para Connected Accounts.

## Showcase comprador
- [ ] Producto publicado con venta directa, precio y stock.
- [ ] **Me interesa** abre conversación sin crear pago.
- [ ] **Comprar** abre Stripe Checkout de la cuenta del vendedor.
- [ ] Pago aprobado aparece como **Pago confirmado**.
- [ ] Producto con envío solicita dirección/teléfono.
- [ ] **Mis pedidos** muestra historial y tracking.
- [ ] Pago fallido no descuenta stock.
- [ ] Webhook repetido no descuenta stock dos veces.
- [ ] Reembolso cambia el pedido a reembolsado.

## Showcase vendedor
- [ ] Panel Pedidos muestra pendientes/pagados/preparando/enviados/incidencias.
- [ ] Pago confirmado → Preparando.
- [ ] Preparando → Enviado con transportista y tracking.
- [ ] Enviado → Entregado.
- [ ] No permite saltos de estado inválidos.

## Events
- [ ] Gestionar evento → **Entradas y cobros**.
- [ ] Modo sin venta funciona.
- [ ] Modo externo conserva URL HTTPS.
- [ ] Modo KOMBAX exige precio y cupo.
- [ ] Si Connect no está activo ofrece activar/completar Stripe.
- [ ] Evento publicado muestra **Comprar entradas**.
- [ ] Límite por pedido se respeta.
- [ ] Cupo agotado muestra **Entradas agotadas**.
- [ ] Dos Checkouts concurrentes no sobre-venden el cupo.
- [ ] Pago aprobado emite exactamente N tickets.
- [ ] **Mis entradas** muestra códigos.
- [ ] Ventas de entradas muestra pedidos del evento.
- [ ] Check-in cambia una entrada `active` a `used` una sola vez.
- [ ] Reembolso invalida las entradas.
- [ ] Disputa queda registrada.

## Aislamiento
- [ ] Club A nunca cobra un evento de Club B.
- [ ] Federación utiliza su propio Connect.
- [ ] Marca reutiliza el Connect de su proveedor Showcase.
- [ ] Profesional/Competidor organizador utiliza `event_organizer` propio.
- [ ] Un `acct_...` no puede reasignarse a otra entidad.
- [ ] `platform_fee_minor = 0` en Showcase y Events.
