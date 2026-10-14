# Supabase — Migraciones Fase 3

Proyecto: `poggsobhtutbuagjiydc`.

| Supabase ID real | Nombre | Resultado |
|---|---|---|
| `20261014110805` | `kombax_fee_void_audit_r264` | Aplicada; nueva tabla y RPC auditada, vistas de saldos corregidas |
| `20261014111044` | `kombax_fee_void_permission_hardening_r264` | Aplicada; comprobación de rol NULL-safe |

Archivos reproducibles contenidos en este ZIP:
- `supabase/migrations/20261014123000_kombax_fee_void_audit_r264.sql` — base final endurecida para una instalación nueva.
- `supabase/migrations/20261014123500_kombax_fee_void_permission_hardening_r264.sql` — hotfix idempotente en backend preexistente.

**No ejecutar estas migraciones otra vez en este proyecto.** Para otros entornos, ejecutar mediante inventario de migraciones, no mediante copias ciegas.

R262/R263 permanecen aplicadas desde la fase anterior; no se reaplicaron.
