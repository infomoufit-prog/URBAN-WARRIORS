# KOMBAX 20.111 R63 — Inventario de auditoría

## Base auditada
- Base recibida: KOMBAX 20.110 R62.8 — SHOWCASE_EVENTS_COMMERCIAL_PILOT_QA_READY.
- SHA-256 del ZIP de entrada: `33054a6a5bcaaefc766b5a962344d07512b8d056754f58e02e2ad95d09982575`.
- Release derivada: KOMBAX 20.111 R63 — SHOWCASE_EVENTS_COMPLIANCE_HARDENING.
- Android: versionCode `20111`; versionName `2.0.0-rc.13-r63-compliance`.

## Arquitectura localizada
- Frontend web/PWA sincronizado a `dist` y Android assets.
- Android WebView/Capacitor-style project con Firebase presente.
- Supabase: migraciones, RPC, RLS y Edge Functions.
- Stripe Connect: checkout sobre connected account y modelo sin application fee KOMBAX.
- KOMBAX Showcase: catálogo, vendedor, checkout, pedidos, Seller Center.
- KOMBAX Events: eventos, ticketing, checkout, QR/pedidos y capacidad de organizador.
- Núcleo común de verificación profesional y moderación/auditoría reutilizable.

## Contratos/políticas localizados
- Terms generales KOMBAX 1.1.0-piloto.
- Privacy 1.1.0-piloto.
- marketplace_terms 1.1-qa.
- seller_agreement 1.1-qa.
- buyer_protection 1.1-qa.
- prohibited_products 1.1-qa.
- events_organizer_terms 1.0-qa.
- events_ticketing_agreement 1.0-qa.

## Hallazgos previos a R63
- Checkout Showcase y Events sin guard backend de edad <18.
- Aceptación general desalineada: UI 1.1.0-piloto vs motor 1.0.0.
- Evidencia contractual sin hash canónico de Terms/Privacy.
- Producto sin campos suficientes de trazabilidad/seguridad GPSR.
- No existía notice-and-action comercial específico para producto/evento.
- Moderación existente centrada en Social; aprovechable pero no conectada a casos comerciales.
- Cancelación de evento detenía venta, pero faltaba plan trazable de refund pendiente.
- Texto histórico de ayuda decía que Showcase no era ecommerce aunque R62.8 ya incluye checkout/pedido.
- Terms/Privacy mantienen datos fiscales y registrales pendientes de completar.

## Principio aplicado
R63 amplía componentes existentes y evita crear sistemas duplicados. No se ha desplegado a Supabase, GitHub, Netlify ni Google Play.
