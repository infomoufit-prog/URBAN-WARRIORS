# KOMBAX RC13 build 20076 · Banner positioning validation

## Resultado
**PASS técnico · candidata local**

## Cambio funcional
- El banner del perfil ya no queda forzado al centro.
- Al seleccionar una nueva portada de Miembro aparece una vista previa interactiva.
- Se puede arrastrar con ratón o dedo y ajustar horizontal/verticalmente.
- Existe botón **Ajustar banner** para volver a modificar el encuadre sin sustituir la imagen.
- Se conserva la imagen original: solo se persiste el punto focal X/Y (0–100).
- El encuadre queda persistido y se aplica en móvil y escritorio.
- Cobertura: Miembro, Club y las identidades canónicas Marca/Federación/Competidor. El perfil público dedicado del Club consume el mismo punto focal.

## Backend / Supabase
- Migración 131 `kombax_profile_banner_position_20076`: columnas `banner_position_x/y`, RPC protegido `app_kombax_social_banner_position_v131`, enriquecimiento de `app_kombax_perfil_publico_v094`.
- Migración 132 `kombax_club_public_banner_position_20076`: RPC `app_perfil_club_publico_v132` con `social_profile_id` y posición focal.
- Ambas migraciones están aplicadas en Supabase.
- Prueba reversible: el propietario guardó 32/18 y el perfil devolvió 32/18; otro perfil fue rechazado con `KOMBAX_SOCIAL_PROFILE_FORBIDDEN`.
- Club: usuario sin permisos -> `editable=false`; Dirección -> `editable=true`.

## QA
- `npm test`: PASS.
- Test específico 20076: PASS.
- `npm run build`: PASS.
- 73 archivos: `web = dist = Android`.
- Referencias runtime a `urban01.netlify.app`: 0.
- Secretos privados detectados en runtime: 0.
- Health Supabase v4: HTTP 200, build 20076, DB OK.
- Android preflight: 4/5; falta únicamente firma local (`android/keystore.properties`).

## Publicación
GitHub y Netlify no se han modificado.
