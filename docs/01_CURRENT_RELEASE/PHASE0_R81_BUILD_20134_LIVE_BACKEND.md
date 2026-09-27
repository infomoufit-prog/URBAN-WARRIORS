# KOMBAX Fase 0 · Backend live · R81 build 20134

## Supabase

Auditoría sobre el proyecto live de KOMBAX durante Fase 0.

### Migración R81

`kombax_r81_terminal_tap_to_pay` -> aplicada.

### Contratos live principales

- `app_stripe_payment_methods_status_r81(text, uuid)` -> presente.
- `app_stripe_terminal_toggle_r81(text, uuid, boolean)` -> presente.
- `app_stripe_event_apply_v267(jsonb)` -> presente.
- `kombax_payments.terminal_locations_r81` -> presente, RLS ON.
- `kombax_payments.terminal_sales_r81` -> presente, RLS ON.

### Edge Functions observadas

- `stripe-connect` -> ACTIVE / JWT.
- `stripe-checkout` -> ACTIVE / JWT.
- `stripe-sepa` -> ACTIVE / JWT.
- `stripe-terminal` -> ACTIVE / JWT.
- `stripe-refund` -> ACTIVE / JWT.
- `stripe-account-finance` -> ACTIVE / JWT.
- `stripe-webhook` -> ACTIVE; JWT Supabase desactivado por diseño, valida firma Stripe.
- `health` -> ACTIVE, build 20134 tras cierre de Fase 0.

No se ha efectuado ningún cargo, devolución o movimiento real de dinero para esta auditoría.
