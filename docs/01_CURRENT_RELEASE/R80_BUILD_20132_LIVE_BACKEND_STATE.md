# R80 build 20132 — Estado backend live

## Supabase

Proyecto KOMBAX verificado como activo y saludable.

Migraciones R80 aplicadas el 18/09/2026 en bloques aditivos:
- `kombax_r80_estado_cuota_disputada`
- `kombax_r80_payment_center_foundation`
- `kombax_r80_sepa_internal_flows`
- `kombax_r80_sepa_webhook_reconciliation`

RPC R80 verificados presentes:
- `app_stripe_payment_methods_status_r80`
- `app_stripe_payment_method_toggle_r80`
- `app_stripe_payer_options_r80`
- `app_stripe_sepa_summary_r80`
- `app_stripe_event_apply_v266`

Edge Functions verificadas activas:
- `stripe-connect` v8
- `stripe-sepa` v1
- `stripe-webhook` v7

## Seguridad

Los datos financieros sensibles R80 no se exponen mediante acceso directo de usuarios a tablas. RLS permanece activado y las tablas de mandatos/Customers/preferencias se operan mediante funciones controladas y service role. KOMBAX no almacena el IBAN completo.

## Estado operativo Urban Warriors

Stripe Connect requiere completar requisitos del titular/comercio antes de habilitar cobros y payouts. Mientras esos requisitos sigan pendientes, KOMBAX debe mostrar Tarjeta/SEPA como no operativos y ofrecer completar la configuración de Stripe.

## Nota de seguridad operacional

Durante la corrección no se realizó ningún cargo real, adeudo SEPA, reembolso ni movimiento de fondos. La validación de `Nuevo cargo` se hizo exclusivamente en modo preview/shadow.
