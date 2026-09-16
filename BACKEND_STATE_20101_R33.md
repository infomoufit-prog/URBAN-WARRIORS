# KOMBAX 20.101 R33 · Estado backend real

Proyecto principal Supabase: `poggsobhtutbuagjiydc`.

## Migraciones live R33
- 20260831111254 `kombax_federation_licenses_admin_20101_r33`
- 20260831111634 `kombax_federation_licenses_r33_hardening`
- 20260831111729 `kombax_federation_license_documents_reader_20101_r33`
- 20260831112640 `kombax_federation_club_scope_fix_20101_r33`
- 20260831123311 `kombax_federation_r33_fk_index_hardening_20101`

## Edge Function
`invite-email` desplegada como versión 4, estado ACTIVE, `verify_jwt=true`.
Integra invitaciones Club/alumno existentes y nuevas invitaciones `federation_team`.

## Storage
Bucket privado: `federation-license-documents`.
Lectura autorizada por función backend; la aplicación usa URL firmada de 300 s.

## Aislamiento verificado
Prueba backend real Club X + Federación A/B: A no descubre B, no lee licencia B ni documento B; B sí accede a sus propios objetos/autorizaciones.

## Equipo federativo verificado
Invitación vinculada al email, aceptación, role capabilities y revocación inmediata verificadas. Secretaría puede gestionar licencia sin capability de Tesorería.
