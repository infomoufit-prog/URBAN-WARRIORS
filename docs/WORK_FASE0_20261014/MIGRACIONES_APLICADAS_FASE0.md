# Supabase — Reconciliación preliminar de migraciones

**Esta fase no ha aplicado migraciones.** Supabase devuelve 509 entradas históricas registradas, frente a 459 archivos SQL del ZIP local. No equivale a 50 migraciones faltantes: difieren versiones, fuentes y gran parte del historial.

Últimas migraciones comprobadas como registradas en producción:

| Fecha/versión | Nombre | Estado |
|---|---|---|
| 20261007201408 | kombax_meta_instagram_fix20 | Aplicada previamente |
| 20261007201735 | meta_instagram_fk_indexes_fix20 | Aplicada previamente |
| 20261007205827 | member_seniority_historical_finance_fix20 | Aplicada previamente |
| 20261013214451 | kombax_signup_intent_recovery_r262 | Aplicada previamente, no presente en ZIP base |
| 20261013220252 | kombax_club_licenses_without_federation_r263 | Aplicada previamente, no presente en ZIP base |
| 20261013220433 | kombax_club_license_legacy_rpc_security_r263 | Aplicada previamente, no presente en ZIP base |
| 20261013220641 | kombax_internal_license_self_view_r263 | Aplicada previamente, no presente en ZIP base |

**Pendiente:** elaborar reconciliación completa SQL origen ↔ registro de migración ↔ definición de funciones activas antes de ejecutar nueva migración. Nunca lanzar migraciones antiguas en bloque.
