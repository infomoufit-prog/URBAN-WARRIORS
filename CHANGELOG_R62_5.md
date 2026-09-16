# CHANGELOG · KOMBAX 20.110 R62.5

Base: `KOMBAX_20110_R62_4_STRIPE_CONNECT_HARDENED_TEST_READY`.

## Añadido
- Venta interna de tickets en KOMBAX Events con Stripe Connect.
- Modos de ticketing `none`, `external` y `kombax`.
- Cupo, precio, límite por pedido y ventana de venta server-side.
- Reservas temporales de cupo durante Checkout.
- Pedidos de entradas y emisión de tickets individuales tras webhook pagado.
- **Mis entradas** para compradores.
- **Ventas de entradas** y check-in para organizadores.
- Connect `event_organizer` para perfiles Profesional/Competidor verificados con capacidad Events.
- Panel de pedidos Showcase con estados, filtros, historial, envío y tracking.
- Datos de entrega de Showcase recogidos por Stripe Checkout cuando el fulfillment requiere envío.
- Retorno de Checkout con contexto `payment_kind` y mensajes específicos.

## Conservado
- **Me interesa** en Showcase como conversación sin pago.
- Compra directa Showcase existente.
- Links externos de entradas en Events.
- Direct Charges y comisión transaccional KOMBAX = 0.
- Separación entre Stripe Connect y Stripe Billing de KOMBAX.

## Seguridad
- Beneficiario, precio, stock/cupo y account Stripe se resuelven en servidor.
- Idempotencia Checkout/webhook preservada.
- Bloqueo de reasignación de Connected Account preservado.
- RLS y acceso RPC para tablas de tickets.

## No realizado
- No se ha desplegado frontend.
- No se ha hecho push a GitHub.
- No se ha aplicado la migración R62.5 al Supabase remoto.
- No se han ejecutado cargos Stripe LIVE.
