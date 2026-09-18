# KOMBAX R80 - Auditoría previa Stripe Connect + SEPA

Base única auditada: `KOMBAX_20130_R79_VIDEO_FULLSCREEN_EXIT_FIX_ACCUMULATIVE.zip`.
Fecha: 2026-09-18.

## Hallazgos AS-IS

- Stripe Connect está centralizado en `stripe-connect` y usa cuentas conectadas V2.
- Los sujetos ya soportados por backend son `club`, `showcase_provider`, `federation` y `event_organizer`.
- Showcase Commerce y Events Ticketing usan Direct Charges sobre la cuenta conectada del vendedor/organizador.
- Finanzas de Club expone actualmente una única activación visible: cobros con tarjeta.
- El motor de cuotas y recibos ya es la fuente de verdad de Finanzas; no se sustituirá por Stripe Billing.
- Los webhooks Stripe ya reconcilian PaymentIntents, reembolsos y disputas.
- Existe infraestructura de `payment_authorizations` y `payment_attempts`, pero no un centro universal de métodos de cobro ni un flujo SEPA completo, reutilizable y account-scoped.
- El Customer Stripe existente no debe asumirse global para Direct Charges; los Customers reutilizables de domiciliación deben quedar vinculados a la cuenta conectada correspondiente.

## Decisiones de diseño R80

1. Una cuenta Stripe Connect por identidad comercial, nunca una cuenta por servicio.
2. Métodos independientes por identidad: tarjeta y domiciliación bancaria SEPA.
3. Tarjeta: pagos inmediatos (cuotas pagadas en el momento, Showcase Commerce, Ticketing).
4. SEPA: cobros recurrentes/diferidos compatibles, empezando por cuotas de Club y pagador/tutor.
5. Un ticket o pedido inmediato no se confirma mediante SEPA mientras el adeudo siga en procesamiento.
6. KOMBAX no almacena IBAN completo: solo referencias Stripe, mandato, last4 y estado.
7. El frontend no marca pagos como pagados: los webhooks son la fuente de verdad financiera.
8. Connect es una capacidad reutilizable para Club, Federación, Marca/Showcase Provider y Organizador de eventos, siempre sujeto a suscripción/entitlements existentes.
9. La experiencia de cobros se centraliza visualmente en un Centro de cobros premium, reutilizado en Finanzas, Seller Center y Events.
10. La documentación de usuario se integra en la plataforma y KOMBAX Assist debe poder guiar la activación sin solicitar datos bancarios o credenciales en chat.

## Gate previo

- No alterar planes ni derechos comerciales existentes.
- No introducir un segundo procesador de pagos.
- No romper card checkout actual.
- No emitir tickets ni pedidos con SEPA diferido en R80.
- Mantener compatibilidad web/PWA/Android y multiclub.
