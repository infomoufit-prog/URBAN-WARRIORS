# KOMBAX 20.110 R62.5 · Showcase Orders + Events Ticketing + Stripe

## Objetivo
R62.5 amplía la base R62.4 sin cambiar el modelo económico: Direct Charges sobre la cuenta Stripe Connect de la entidad que vende, con `platform_fee_minor = 0`. KOMBAX no actúa como merchant of record para estas operaciones.

## Showcase
- La ficha comercial conserva **Me interesa** para abrir conversación y **Comprar** cuando la venta directa está activada.
- Checkout resuelve producto, precio, stock, vendedor y cuenta conectada desde backend.
- En productos con envío, Stripe Checkout recopila dirección y teléfono; el webhook los asocia al pedido.
- El comprador dispone de **Mis pedidos** con estados: pendiente de pago, pago confirmado, preparando, enviado, entregado, cancelado, reembolsado e incidencia.
- El vendedor dispone de panel de pedidos, filtros, dirección de entrega, tracking e historial.
- Las transiciones de estado se validan en servidor y el stock se descuenta una sola vez al confirmar el pago.

## Events · venta de entradas
Cada evento puede elegir uno de tres modos:
1. `none`: sin venta de entradas.
2. `external`: mantiene un enlace externo y proveedor.
3. `kombax`: venta interna mediante Stripe Checkout y Stripe Connect.

En modo KOMBAX el organizador configura precio, cupo, máximo por pedido y ventana de venta. El frontend nunca elige la cuenta Stripe ni es fuente de verdad del precio.

### Beneficiario de la venta
El backend resuelve el organizador económico del evento:
- Club → Connect del Club.
- Federación → Connect de la Federación.
- Marca → Connect del proveedor Showcase asociado.
- Profesional/Competidor verificado con derecho a organizar Events → Connect `event_organizer`.

Una identidad no reutiliza el `acct_...` de otra entidad. R62.4 mantiene el bloqueo de reasignación de cuentas.

## Aforo y reservas
Al iniciar Checkout se reserva temporalmente el número de entradas durante 35 minutos. El cálculo de disponibilidad cuenta pagos confirmados y reservas pendientes no expiradas. De esta forma, dos compradores concurrentes no pueden consumir el mismo último cupo desde la preparación del Checkout.

## Emisión
Tras webhook pagado:
- el pedido pasa a `paid`;
- se emite una entrada por unidad comprada;
- cada entrada recibe un código KOMBAX único;
- **Mis entradas** muestra los códigos y su estado;
- el organizador puede consultar **Ventas de entradas** y marcar una entrada válida como usada.

Reembolso y disputa actualizan el pedido y, en el caso del reembolso, invalidan las entradas emitidas.

## Seguridad
- Secret key y webhook secret solo en Edge Functions/Supabase Secrets.
- Precio, stock/cupo, beneficiario y `stripe_account_id` se resuelven server-side.
- Direct Charges; no `application_fee_amount`, `transfer_data.destination` ni `on_behalf_of`.
- Las tablas operativas de tickets tienen RLS activado y no exponen acceso directo a `anon`/`authenticated`; la lectura/escritura pasa por RPCs limitadas.
- Los webhooks conservan comprobación de firma, idempotencia por evento y comprobación de Connected Account.

## Archivos principales
- R62.5 está aplicada como cadena incremental `20260910180156` → `20260910180842`; ver `R62_5_1_SUPABASE_PILOT_QA_HANDOFF.md`.
- `supabase/verification/verify_r62_5_showcase_events_ticketing.sql`
- `supabase/functions/stripe-connect/index.ts`
- `supabase/functions/stripe-checkout/index.ts`
- `supabase/functions/stripe-webhook/index.ts`
- `web/js/modules/showcase.js`
- `web/js/modules/kombax-events.js`
- `web/js/core/repositories.js`

## Estado que puede certificarse desde este ZIP
La compilación y QA estático/local pueden certificar `CODE READY` y `LOCAL TEST READY`. `STRIPE PAYMENT VERIFIED`, `WEBHOOK VERIFIED` y `PILOT READY` requieren aplicar la migración/Edge Functions en el entorno TEST y ejecutar pagos reales de Stripe TEST.
