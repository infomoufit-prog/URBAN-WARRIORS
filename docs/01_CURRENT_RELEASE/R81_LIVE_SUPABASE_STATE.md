# KOMBAX R81 build 20133 · Estado backend live

Proyecto Supabase de KOMBAX validado durante el cierre de R81.

## Migración R81 aplicada

`kombax_r81_terminal_tap_to_pay`

La migración crea/extiende:

- `kombax_payments.payment_method_preferences_r80.tap_to_pay_enabled`
- `payment_attempts.kind = terminal_sale`
- `public.pagos.metodo = terminal`
- `kombax_payments.terminal_locations_r81`
- `kombax_payments.terminal_sales_r81`
- RPC de status/toggle/context/location/sale/history
- reconciliador webhook `app_stripe_event_apply_v267`

Comprobación live de las funciones/tablas principales: PASS.

## RLS

`terminal_locations_r81` → RLS ON  
`terminal_sales_r81` → RLS ON

No tienen políticas públicas intencionadamente: acceso directo deny-by-default; operaciones financieras a través de service-role / RPC controlado.

## Edge Functions relevantes

| Función | Estado | Configuración |
|---|---|---|
| `stripe-terminal` | ACTIVE | JWT obligatorio |
| `stripe-webhook` | ACTIVE | firma Stripe validada en función; JWT de Supabase desactivado por diseño |
| `stripe-connect` | ACTIVE | JWT obligatorio |
| `stripe-sepa` | ACTIVE | JWT obligatorio |
| `health` | ACTIVE | build 20133 |

En el cierre observado:

- `stripe-terminal` version 1
- `stripe-webhook` version 8
- `stripe-connect` version 8
- `stripe-sepa` version 1
- `health` version 33

## Seguridad

Los advisories de Supabase siguen mostrando numerosos avisos históricos de tablas internas con RLS sin policy. En las tablas R81 esto es deliberado y no se abrió una policy permisiva para “silenciar” el advisory.

Los avisos de índices sin uso/duplicados observados son acumulativos e históricos y no bloquean R81.

## Importante

No se ejecutó ningún cargo real para validar la release. La activación final de cobro live depende de que la cuenta Stripe Connect de la identidad comercial haya completado todos sus requisitos y capacidades.
