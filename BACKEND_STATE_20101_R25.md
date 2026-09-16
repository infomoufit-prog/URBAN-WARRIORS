# BACKEND STATE — KOMBAX 20.101 R25

R25 intentionally makes **no backend change**.

Verified against the main Supabase project after the previous R24 rollback:
- `app_kombax_evento_bundle_v189`: present.
- `app_kombax_eventos_publicos_page_v191`: present.
- `app_kombax_eventos_mutate_v191`: present.
- public functions containing `v192`: none.
- public functions containing `v193`: none.

The previously deployed R24 `event-media-batch-url` function cannot be deleted with the available connector, so it remains neutralized:
- ACTIVE compatibility endpoint
- verify_jwt=true
- returns HTTP 410 `R24_ROLLED_BACK_TO_R23`
- performs no database or Storage access
- R23/R25 frontend does not call it

R25 does not alter tables, RLS, grants, storage paths, event data, participant data or demo seed.
