# Changelog RC13 build 20.097

- Aislamiento de KOMBAX Eventos por workspace de club.
- Nuevo `app_kombax_eventos_organizador_contexto_v171(uuid)`.
- Nuevo `app_kombax_evento_contexto_gestion_v171(uuid,uuid)`.
- Nuevo gateway `app_kombax_eventos_mutate_v171`.
- Invitaciones contextuales `app_kombax_eventos_invitaciones_contexto_v172(uuid)`.
- La frontend envía `workspace_club_id` en mutaciones de Eventos.
- En contexto de club se ocultan identidades directas Federación/Profesional/Competidor como organizadoras.
- Activación piloto de Urban Warriors preparada fuera de la cadena automática de migraciones para ejecutarse tras desplegar 20.097.
