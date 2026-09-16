# CHANGELOG · KOMBAX R62.5.1 Supabase Pilot QA

## Aplicado en remoto
- R62.4 Stripe Connect Federation hardening.
- R62.5 Connect para organizador directo.
- R62.5 ticketing schema + RPCs.
- R62.5 Checkout para entradas y pedidos Showcase.
- R62.5 webhook de pagos, refunds/disputes y emisión idempotente de tickets.
- Hardening piloto: índices nuevos de ticketing y privacidad del estado público de entradas.
- Edge Functions desplegadas: stripe-connect v6, stripe-checkout v5, stripe-webhook v5.

## Validado
- Direct Charges conservado.
- Comisión de plataforma por transacción = 0.
- Unicidad de Connected Account entre entidades.
- RLS y bloqueo de acceso directo cliente a tablas privadas de ticketing.
- Build/regresión local completos.
- web/dist/Android sincronizados (197 archivos).

## Pendiente de evidencia antes de go-live público
- Stripe TEST E2E autenticado para Club, Marca, Federación y Event Organizer.
- Pago TEST Showcase y ticketing con webhook real.
- Refund/dispute TEST reales.
- Concurrencia de aforo en E2E.
- Gates globales: backup_export, restore_drill, monitoring, incident_runbook, owner_mfa, smtp, legal_controller.
- Advisor global: leaked-password protection aparece desactivado y debe revisarse antes de producción.
