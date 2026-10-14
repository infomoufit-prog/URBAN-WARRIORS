# Contratos de Supabase ya existentes — NO DUPLICAR

- `20261014130901 kombax_event_ticket_categories_draft_r265`: tabla `public.kombax_event_ticket_categories_r265` y RPC de gestión.
- `20261014133710 kombax_ticket_categories_schema_catalog_r266`: campos snapshot de ticketing.
- `20261014133753 kombax_ticket_category_checkout_prepare_r266`: checkout Stripe por categoría.
- `20261014133822 kombax_ticket_category_wallet_checkin_r266`: wallet y control de acceso.
- `20261014133952 kombax_ticket_category_sales_snapshot_r266`: ventas y snapshot.
- `20261014134400 kombax_ticket_category_inventory_guard_r266`: guard de cupos.
- `20261014150538 kombax_showcase_preserve_inquiries_on_delete_r268`, `20261014151035 ... r268b` precedentes en 5A.

Las versiones se han observado directamente en la tabla de migraciones de Supabase; **no se recrean** aquí como SQL copiado a ciegas. Auditoría de lecturas SQL solamente. Mantener las fuentes originales de las migraciones históricas cuando se consolide el repositorio.
