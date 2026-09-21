# KOMBAX R65 · Supabase live state

Comprobación final realizada contra el proyecto conectado `poggsobhtutbuagjiydc`.

## Historial R65 confirmado

Las últimas ocho migraciones del historial corresponden a R65 y coinciden con los archivos incluidos en `supabase/migrations/`:

- 20260913223620 · kombax_r65_commerce_events_operations_part1
- 20260913223644 · kombax_r65_commerce_events_operations_part2
- 20260913223707 · kombax_r65_refund_prepare
- 20260913223732 · kombax_r65_refund_finalize_and_batches
- 20260913223753 · kombax_r65_sales_and_finance
- 20260913223819 · kombax_r65_bi_qr_order_operations
- 20260913223837 · kombax_r65_webhook_v265
- 20260913223848 · kombax_r65_outbox_hardening

## Advisors

La auditoría posterior muestra avisos de performance no bloqueantes. El proyecto conserva un volumen amplio de avisos históricos sobre foreign keys sin índice e índices no utilizados. Las tablas R65 aportan algunos avisos INFO adicionales de foreign keys sin índice. También permanece un warning histórico de índice duplicado en `public.informes_financieros`.

No se han hecho eliminaciones masivas de índices en el cierre R65 para evitar introducir cambios de rendimiento no medidos antes del piloto.
