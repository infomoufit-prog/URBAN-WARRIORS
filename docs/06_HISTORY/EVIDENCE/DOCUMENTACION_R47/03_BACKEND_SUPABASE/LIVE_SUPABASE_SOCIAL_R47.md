# Evidencia viva Supabase · Social R47

Proyecto: `poggsobhtutbuagjiydc`

## Migraciones registradas
- `20260905082544 kombax_social_visibility_core_r47`
- `20260905082606 kombax_social_feed_preferences_r47`
- `20260905082640 kombax_social_mutation_visibility_r47`

Un borrador monolítico de reconciliación fue rechazado anteriormente y no quedó registrado; el cierre usa las tres migraciones anteriores, que son el contrato vivo y el que contiene el ZIP.

## RPC/ACL comprobados en vivo
- `app_kombax_social_feed_v237(numeric,timestamptz,uuid,integer)`: authenticated EXECUTE=true; anon=false.
- `app_kombax_social_visibility_config_v237(uuid)`: authenticated EXECUTE=true; anon=false.
- `app_kombax_social_mutate_v123(text,jsonb,uuid)`: authenticated EXECUTE=true; anon=false; contiene `kombax.social.preferencia` y `kombax.social.visibilidad`.

## RLS / acceso directo
RLS=true y sin SELECT/WRITE directo para `anon`/`authenticated` en:
- `kombax_social_preferencias_usuario_v237`
- `kombax_social_post_visibility_profiles_v237`
- `kombax_social_post_visibility_types_v237`

## Estado de datos al verificar
- preferencias R47: 0
- selecciones de visibilidad por perfil: 0
- selecciones por tipo: 0
- likes históricos: 11

Esto es coherente con que aún no se ha realizado una interacción real nueva R47 en producción.

## Advisors y E2E
No se obtuvo una ejecución nueva fiable de Security/Performance Advisors en este cierre, por lo que no se declaran limpios. Tampoco se realizó un E2E autenticado destructivo/real en producción. Ambos quedan como gates separados del cierre técnico automatizado.
