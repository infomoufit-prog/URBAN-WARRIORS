# BACKEND_STATE_20101_R40.md

Proyecto Supabase: `poggsobhtutbuagjiydc`.

## Migraciones live R40 verificadas
- `20260904172146` · `kombax_social_network_visibility_r40`
- `20260904172248` · `kombax_event_visibility_r40`

## Seguridad R40
Tablas nuevas:
- `kombax_social_post_visibility_clubs_v235`
- `kombax_event_visibility_v236`
- `kombax_event_visibility_clubs_v236`

Las 3 tienen RLS activa, política deny-direct y 0 grants directos a `anon`/`authenticated`.
Las RPC de configuración/mutación R40 son `SECURITY DEFINER`, `search_path=''`, `anon EXECUTE=false`; las de cliente autenticado necesarias tienen `authenticated EXECUTE=true`.

## Privacidad deportiva
Escaneo live sobre 18 funciones/RPC afectadas por R40:
- referencias a `kombax_competition_preparations_v216`: 0
- referencias a `kombax_weight_measurements_v216`: 0
- referencias a `kombax_event_official_weigh_ins_v218`: 0

Los 3 eventos existentes permanecen con visibilidad heredada `publico`; R40 no reescribió silenciosamente eventos existentes. Las tablas de reglas R40 permanecen a 0 filas hasta uso real de piloto.

## Brand Business Hub R37
Las 6 tablas `kombax_brand_*` existentes tienen RLS activa y 0 grants directos a `anon`/`authenticated`. La proyección pública continúa realizándose mediante RPC controlada, no mediante lectura directa de tablas.
