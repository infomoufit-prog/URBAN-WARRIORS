# KOMBAX 20.101 R33.1 · Estado backend real

Proyecto principal Supabase: `poggsobhtutbuagjiydc`.

## Nueva migración live
- `20260831134406` `kombax_managed_profile_modules_r33_1`

La migración reemplaza únicamente `app_kombax_managed_profile_hub_v197(uuid)` para anunciar la matriz UX R33.1 de Federación, Competidor y Profesional. No crea tablas, no amplía RLS y no altera las fronteras cross-federation de R33.

## Verificación live dirigida
Funciones comprobadas:
- `app_kombax_managed_profile_hub_v197`
- `app_kombax_self_licenses_v200`
- `app_kombax_professional_authorized_licenses_v200`
- `app_kombax_club_federation_context_v200`
- `app_kombax_federation_context_v200`

En las cinco:
- `SECURITY DEFINER`: sí.
- `search_path=public, auth`: fijado.
- EXECUTE `anon`: no.
- EXECUTE `authenticated`: sí.

El workspace R33.1 fue verificado además con marcador `r33.1-v197` y módulos federativos/personales presentes.

## Estado R33 preservado
- `invite-email`: versión 4 ACTIVE, `verify_jwt=true` (estado de R33).
- Bucket privado `federation-license-documents` preservado.
- Aislamiento Federación A/B y equipo federativo siguen cubiertos por test R33 52/52 y por las fronteras backend existentes.
