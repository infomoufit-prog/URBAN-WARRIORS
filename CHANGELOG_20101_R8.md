# Changelog · KOMBAX 20.101 R8

## Urban Warriors Jiu-Jitsu Event
- Añadido segundo evento ficticio completo sin alterar “Noche de Impacto”.
- Evento asociado al club real Urban Warriors (`creador_tipo=club`).
- Entitlement `events.public.organize` obligatorio.
- Perfil Social de Urban Warriors usado como organizador principal cuando está disponible.
- 12 participantes ficticios.
- 6 Fight Cards, incluidas 2 destacadas.
- Cobertura por edades desde 8 años hasta adultos.
- 15 imágenes WEBP optimizadas; sin MP4/WEBM/MOV.
- Álbum dividido en previo / evento / posterior.
- Auto-bootstrap Owner en el primer acceso a Events + botón manual idempotente.
- Nuevo RPC `app_kombax_demo_urban_warriors_jiujitsu_seed_v180()` y cleanup equivalente.
- Migración R8 aplicada a Supabase como preparación del bootstrap; no se fuerza un evento público con assets rotos antes de ejecutar la build R8.

## Regresión preservada
- R7 Gateway Atmospheric Hero intacto.
- Social / Events / Showcase mantienen humo CSS y responsive.
- Noche de Impacto permanece independiente.
- Sin cambios a Finanzas, Auth, RLS de otros dominios ni eventos privados de Mi Club.
