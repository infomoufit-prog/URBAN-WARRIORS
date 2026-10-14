# Migraciones Fase 2

- **Nuevas aplicadas durante Fase 2: 0**.
- **Edge Functions desplegadas durante Fase 2: 0**.
- Confirmadas como previamente aplicadas en Supabase:
  - `20261013214451` — `kombax_signup_intent_recovery_r262`.
  - `20261013220252` — `kombax_club_licenses_without_federation_r263`.
  - `20261013220433` — `kombax_club_license_legacy_rpc_security_r263`.
  - `20261013220641` — `kombax_internal_license_self_view_r263`.
- Verificados contratos RPC de lectura y mutación, incluido el sentinel R263.
- El SQL original de estas migraciones aplicadas no está en el ZIP de base; no se recrean a partir de conjeturas. Debe exportarse oficialmente antes de considerarlas reproducibles fuera del proyecto actual.
- Se mantiene compatibilidad frontend actual: solo cambia el paquete local; no se altera producción.
