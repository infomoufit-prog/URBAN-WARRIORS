# KOMBAX 20.110 R62.6 — Social Discovery

## Alcance
R62.6 añade un motor común de Discovery dentro de KOMBAX Social para descubrir competidores y profesionales sin crear una mensajería paralela ni un paywall específico.

## Cambios funcionales
- Nueva vista de primer nivel: **Descubrir competidores y profesionales**.
- Estado general de disponibilidad independiente: `Disponible`, `Limitado`, `No disponible`.
- Fechas/horarios de disponibilidad opcionales y separados del estado general.
- Discovery no consulta agendas profesionales privadas.
- Competidores: disciplinas, nivel, categoría, rango de peso público, territorio, desplazamiento, aviso mínimo, short notice, afiliación federado/independiente y récord competitivo declarado (combates/victorias/derrotas/empates).
- Profesionales: especialidad, disciplinas, territorio, desplazamiento, modos de trabajo, experiencia y disponibilidad.
- Contacto reutiliza KOMBAX Social y sus permisos existentes, sin exponer email/teléfono privados.
- Perfiles Competidor y Profesional pueden editar Discovery desde su hub/perfil propio.
- Perfil público muestra disponibilidad declarada cuando procede.
- KOMBAX Events reutiliza el Discovery general sin eliminar el buscador especializado de oponentes ni las invitaciones de combate existentes.

## Backend
Migración remota aplicada:
- `20260911102242_kombax_r626_social_discovery`

RPC nuevas autenticadas:
- `app_kombax_discovery_search_r626(jsonb)`
- `app_kombax_discovery_profile_r626(uuid)`
- `app_kombax_discovery_mutate_r626(uuid,jsonb,uuid)`
- `app_kombax_discovery_slots_r626(uuid)`
- `app_kombax_discovery_slot_mutate_r626(uuid,text,jsonb,uuid)`
- `app_kombax_discovery_public_profile_r626(uuid)`

Las seis RPC tienen `anon` revocado, `authenticated` habilitado, `SECURITY DEFINER` y `search_path=''`.

## Despliegue
- Supabase: migración aplicada y verificada.
- Netlify: NO desplegado.
- GitHub: NO push.
- Google Play: NO publicado.
