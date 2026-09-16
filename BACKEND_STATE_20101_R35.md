# Backend State · KOMBAX 20.101 R35

Proyecto Supabase verificado: `poggsobhtutbuagjiydc`.

## Migraciones live R35

- `20260903232924` · `kombax_event_centric_preparation_20101_r35`
- `20260903233155` · `kombax_event_centric_preparation_privacy_hardening_20101_r35`

## Esquema verificado

`kombax_competition_preparations_v216` incorpora:
- `event_source`
- `public_participant_id`
- `internal_event_id`
- `internal_participant_id`

Nueva tabla:
- `kombax_event_official_weigh_ins_v218`
- RLS: habilitado
- políticas directas: 1 política deny-by-default

## RPC verificadas

- `app_kombax_event_preparation_roster_v218`
- `app_kombax_event_preparation_mutate_v218`
- `app_kombax_public_registration_private_manager_v218`
- `app_kombax_preparation_can_v216`
- `app_kombax_weight_measurements_v216`

En las cinco funciones auditadas:
- `anon EXECUTE = false`
- `authenticated EXECUTE = true`
- `search_path` fijo/vacío en SECURITY DEFINER

## Hardening privado verificado

- El helper privado no contiene una concesión implícita al rol `monitor`.
- El lector de registros diarios no contiene el antiguo bypass `official_verify`.
- El organizador/federación no obtiene por defecto acceso al histórico privado.
- Dirección/coordinación y autorizaciones explícitas siguen siendo la ruta de acceso privada.

## Datos live en el momento del cierre

- preparaciones R34/R35: 0
- pesajes oficiales R35: 0

Por tanto, no fue necesaria una migración de datos existentes; el cambio de R35 es estructural y compatible con la tabla R34.
