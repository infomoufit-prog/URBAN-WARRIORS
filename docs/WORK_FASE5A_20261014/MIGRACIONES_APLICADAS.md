# Migraciones Supabase aplicadas (Fase 5A)

| Registrada en Supabase | Nombre | Objetivo |
|---|---|---|
| 20261014150538 | `kombax_showcase_preserve_inquiries_on_delete_r268` | Evitar cascada de borrado de consultas y mensajes |
| 20261014151035 | `kombax_showcase_preserve_associated_history_r268b` | Evitar perder conversaciones Social, movimientos de stock, analítica y seguridad |

No volver a aplicar desde el ZIP si ya constan en historial. Ambas migraciones verificadas directamente. Las RPC de consultas R58 ya existían y se reutilizan.
