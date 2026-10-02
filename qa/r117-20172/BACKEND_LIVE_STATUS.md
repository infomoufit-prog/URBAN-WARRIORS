# Backend live status · R117 build 20172

Verified on Supabase project `poggsobhtutbuagjiydc` during pilot on 2026-10-02.

- `crear_perfil_usuario()` contains the mandatory DOB guard `KOMBAX_ACCOUNT_BIRTH_DATE_REQUIRED`.
- `app_kombax_account_birthdate_set_r117(date)` exists.
- `app_kombax_club_link_resolve_r117(uuid,boolean,uuid)` exists.
- Pilot Club registration remains open-mode / no pilot invitation code.
- Member/family invitation codes remain available only as an optional linking route.
- Health Edge Function deployed as version 40 with build marker `20172` and existing `verify_jwt=false` preserved.

No frontend/Netlify deployment was performed from this environment.
