# Migraciones relevantes · R28 → R32

Estado contrastado contra `supabase_migrations.schema_migrations` del Supabase principal.

## R28 — aplicadas live el 30/08/2026
- `20260830221459` · `kombax_profile_capability_foundation_20101_r28`
- `20260830221550` · `kombax_profile_professional_spectator_mutations_20101_r28`
- `20260830222259` · `kombax_profile_capability_advisor_hardening_20101_r28`

Nota de trazabilidad: el ZIP R27 fuente terminaba físicamente en 194/195; estas tres migraciones ya estaban aplicadas live al iniciar la reconciliación R28. El historial exacto (incluido array `statements`) se verificó en Supabase durante R32. Véase `docs/profile-matrix/R28_BACKEND_RECONCILIATION.md`.

## R29
- local `199_kombax_managed_profile_hubs_20101_r29.sql`
- live `20260831094145` · `kombax_managed_profile_hubs_20101_r29`

## R30
- local `200_kombax_professional_relations_operations_20101_r30.sql`
- live `20260831094845` · `kombax_professional_relations_operations_20101_r30`
- local `201_kombax_professional_relations_r30_advisor_hardening.sql`
- live `20260831095347` · `kombax_professional_relations_r30_advisor_hardening`

## R31
- local `202_kombax_professional_basic_finance_20101_r31.sql`
- live `20260831095754` · `kombax_professional_finance_schema_20101_r31`
- local `203_kombax_professional_finance_runtime_20101_r31.sql`
- live `20260831100627` · `kombax_professional_finance_runtime_20101_r31`
- local `204_kombax_professional_notifications_policy_hardening_20101_r31.sql`
- live `20260831101007` · `kombax_professional_notifications_policy_hardening_20101_r31`

## R32
No requiere DDL nuevo: es hardening, matriz de regresión, advisors, build/paridad y packaging sobre el contrato vivo R28-R31.
