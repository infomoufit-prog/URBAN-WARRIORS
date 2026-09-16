# Supabase vivo · R49

Proyecto auditado: `poggsobhtutbuagjiydc`.

## Migración aplicada
`kombax_social_like_interest_separation_r49`

## Verificación posterior
- `app_kombax_social_feed_v238(...)`: existe.
- `app_kombax_social_preference_v240(uuid,smallint,uuid)`: existe.
- `app_kombax_social_report_offtopic_v240(uuid,text)`: existe.
- `authenticated`: EXECUTE permitido en los tres contratos anteriores.
- `anon`: EXECUTE denegado en los tres contratos anteriores.
- Constraint `kombax_social_reportes_motivo_check` contiene `fuera_tematica`.

Conteos observados en la verificación:
- likes públicos: 11
- preferencias positivas: 1
- preferencias negativas: 0

No se generaron likes, preferencias ni reportes artificiales sobre usuarios reales para validar la migración.

## Events
R49 no aplica migración Events. Se reutilizan los contratos de media/Fight Card/Co-Main ya verificados en R48.
