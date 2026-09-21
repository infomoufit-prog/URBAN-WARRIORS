# KOMBAX R62.5.1 · Supabase Pilot / QA Handoff

Fecha: 2026-09-10
Baseline: R62.5 Showcase Orders + Events Ticketing + Stripe Connect
Supabase project: `poggsobhtutbuagjiydc`

## Estado aplicado en Supabase

Aplicadas y verificadas en remoto:

- `20260910175619_kombax_stripe_connect_hardening_federation_r62_4`
- `20260910180156_kombax_r625_connect_event_organizer`
- `20260910180332_kombax_r625_ticketing_schema_seller`
- `20260910180404_kombax_r625_ticketing_rpcs`
- `20260910180447_kombax_r625_checkout_showcase_orders`
- `20260910180521_kombax_r625_webhook_privileges`
- `20260910180842_kombax_r625_pilot_security_performance_hardening`

Verificadores remotos ejecutados:

- R62.4 Stripe Connect hardening: PASS
- R62.5 Showcase + Events Ticketing: PASS
- R62.5 Pilot hardening: PASS

Edge Functions desplegadas:

- `stripe-connect` v6 · ACTIVE · JWT requerido
- `stripe-checkout` v5 · ACTIVE · JWT requerido
- `stripe-webhook` v5 · ACTIVE · sin JWT de Supabase; usa firma `Stripe-Signature` y ventana anti-replay de 5 min

## Invariantes que NO deben romperse durante QA

1. Direct Charges: el pago pertenece a la cuenta Stripe conectada de la entidad vendedora.
2. `platform_fee_minor = 0` para Showcase y Events.
3. No introducir `application_fee_amount`, `transfer_data.destination` ni `on_behalf_of`.
4. `stripe_account_id`, precio, moneda, stock/cupo y beneficiario se resuelven server-side.
5. Una misma cuenta Stripe no puede pertenecer a dos entidades KOMBAX.
6. Club, Marca, Federación y Organizador de evento directo deben permanecer aislados entre sí.
7. Las tablas privadas de ticketing no se consultan directamente desde cliente; solo RPCs autorizadas.

## Configuración que Work debe comprobar antes de Stripe TEST E2E

En Supabase/Stripe TEST deben existir y ser coherentes:

- `STRIPE_CONNECT_SECRET_KEY`
- `STRIPE_CONNECT_WEBHOOK_SECRET`
- `KOMBAX_APP_URL`
- opcional `STRIPE_CONNECT_API_VERSION` (default del código: `2026-07-29.dahlia`)

No imprimir ni copiar secretos en logs, issues, prompts de agentes o capturas.

## Flujo local recomendado

1. Instalar dependencias usando el lockfile del proyecto.
2. Ejecutar la suite completa.
3. Ejecutar build y comprobar `web = dist = Android`.
4. Iniciar frontend local según scripts de `package.json`.
5. Usar cuentas de TEST autenticadas contra Supabase remoto.
6. Probar Stripe exclusivamente en TEST mode.
7. No ejecutar seeds destructivos ni reset de base remota.

## Gate E2E mínimo para estabilización

### Connect
- Club: status/onboarding/return/refresh.
- Marca: status/onboarding/return/refresh.
- Federación: status/onboarding/return/refresh.
- Profesional o Competidor verificado con entitlement de Events: status/onboarding/return/refresh.
- Intento cross-tenant/cross-entity: debe fallar.

### Showcase
- “Me interesa” sigue abriendo conversación, sin crear pago.
- “Comprar” crea Checkout en la cuenta de la Marca.
- Pago TEST confirmado -> pedido `payment_confirmed`.
- `preparing -> shipped -> delivered` respeta transiciones.
- Envío exige tracking cuando corresponde.
- Webhook duplicado no duplica stock, pedido ni historial.
- Refund/dispute actualizan estado sin crear duplicados.

### Events Ticketing
- `none`, `external` y `kombax` funcionan como modos distintos.
- Venta KOMBAX exige Connect activo y cuenta correcta del organizador.
- El precio se obtiene del evento en backend.
- El cupo se reserva durante Checkout pendiente.
- Dos compras concurrentes cerca del aforo no pueden sobre-vender.
- Pago confirmado emite exactamente N tickets para quantity=N.
- “Mis entradas” solo devuelve tickets del comprador.
- Panel organizador solo devuelve ventas de eventos gestionables.
- Uso de ticket solo puede realizarlo un gestor del evento y una sola vez.
- Refund invalida tickets; dispute marca el pedido correctamente.

## Estado de pilot readiness global existente

El gate histórico `kombax_pilot_readiness_v117` NO debe falsearse. A 2026-09-10 siguen sin evidencia verificada:

- `backup_export`
- `restore_drill`
- `monitoring`
- `incident_runbook`
- `owner_mfa`
- `smtp`
- `legal_controller`

Por tanto esta baseline debe etiquetarse:

- SCHEMA READY: YES
- EDGE FUNCTIONS READY: YES
- LOCAL REGRESSION READY: YES
- STRIPE TEST E2E VERIFIED: PENDING
- PILOT STABILIZATION BASELINE: YES
- PRODUCTION / PUBLIC PILOT GO-LIVE: NO, hasta cerrar E2E Stripe + gates globales.

## Advisors

Security/Performance Advisors fueron revisados tras las migraciones. Existen numerosos avisos históricos previos de funciones SECURITY DEFINER, RLS sin policies en tablas internas, FKs sin índice e índices no usados. Para R62.5:

- las tablas privadas de ticketing tienen RLS y acceso directo `anon/authenticated` revocado deliberadamente;
- se añadieron índices a los FKs nuevos relevantes de `payment_attempts.event_ticket_order_id` y `event_ticket_order_history.actor_user_id`;
- el estado público de entradas ahora comprueba visibilidad del evento antes de devolver información.

No limpiar masivamente advisors históricos durante esta estabilización sin una auditoría separada.
