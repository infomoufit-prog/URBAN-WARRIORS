# R62.8 — Estado remoto final verificado

Proyecto Supabase: `poggsobhtutbuagjiydc`.

Última auditoría remota:
- operador activo de contratos Events: **KOMBAX SPAIN**;
- referencias erróneas del operador anterior: **0**;
- Showcase orders existentes: **0**;
- productos con `commerce_enabled=true`: **0**;
- solicitudes `events_ticketing`: **0**;
- add-ons `events_ticketing` activos: **0**;
- documentos legales/contractuales activos aún pendientes de revisión jurídica: **6**.

Catálogo comercial activo:
- `events_publish` → core / incluido / sin checkout;
- `events_ticketing` → add-on / precio por definir / checkout habilitable;
- `showcase_marketplace` → marketplace / suscripción / checkout;
- `showcase_professional_services` → free listing / gratuito / sin checkout.

El Edge Function `stripe-checkout` remoto está desplegado con JWT obligatorio y gates de servidor para Marketplace y Events + Ticketing.
