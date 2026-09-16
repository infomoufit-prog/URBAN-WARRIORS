# R62.8 — Backend verification

Proyecto Supabase: `poggsobhtutbuagjiydc`.

Migraciones de esta entrega: `kombax_r628_showcase_orders`, `kombax_r628_events_ticketing_addon`, políticas Marketplace/Events R62.8 y corrección de identidad `kombax_r628_kombax_spain_identity_fix`.

Verificado tras aplicación:
- 4 columnas nuevas de clasificación Showcase.
- 5 columnas de trazabilidad de fulfillment de pedidos.
- 5 tablas privadas `kombax_commercial`, todas con RLS.
- 0 privilegios directos de `anon/authenticated` sobre `kombax_commercial`.
- catálogo: Events Publish, Events + Ticketing, Showcase Marketplace, Servicios profesionales.
- 0 add-ons Events + Ticketing activos y 0 solicitudes creadas automáticamente.
- 0 pedidos existentes y 0 productos con comercio activado durante la migración.
- 1 ficha existente en Servicios profesionales convertida a `professional_service` sin checkout.
- contratos Events y políticas Marketplace activos en versiones QA, revisión jurídica pendiente; operador verificado: `KOMBAX SPAIN`.
- `stripe-checkout` desplegado con JWT obligatorio y gate `app_event_ticket_checkout_gate_r628`.

No se ha realizado despliegue de frontend, GitHub ni Google Play.
