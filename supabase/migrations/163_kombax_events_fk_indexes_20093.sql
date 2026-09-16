-- KOMBAX RC13 build 20.093 · 163 · KOMBAX Events FK index hardening
-- Additive performance hardening only for the public KOMBAX Events domain.
-- Does not alter Mi Club > Eventos tables or business rules.
begin;

create index if not exists idx_kombax_eventos_publicos_creado_por_v163
  on public.kombax_eventos_publicos(creado_por);

create index if not exists idx_kombax_evento_entidades_creado_por_v163
  on public.kombax_evento_entidades(creado_por);
create index if not exists idx_kombax_evento_entidades_respondido_por_v163
  on public.kombax_evento_entidades(respondido_por)
  where respondido_por is not null;

create index if not exists idx_kombax_evento_participantes_competidor_v163
  on public.kombax_evento_participantes_publicos(competidor_social_profile_id)
  where competidor_social_profile_id is not null;
create index if not exists idx_kombax_evento_participantes_club_v163
  on public.kombax_evento_participantes_publicos(club_social_profile_id)
  where club_social_profile_id is not null;
create index if not exists idx_kombax_evento_participantes_creado_por_v163
  on public.kombax_evento_participantes_publicos(creado_por);

create index if not exists idx_kombax_evento_combates_participante_a_v163
  on public.kombax_evento_combates_publicos(participante_a_id);
create index if not exists idx_kombax_evento_combates_participante_b_v163
  on public.kombax_evento_combates_publicos(participante_b_id);
create index if not exists idx_kombax_evento_combates_ganador_v163
  on public.kombax_evento_combates_publicos(ganador_participante_id)
  where ganador_participante_id is not null;
create index if not exists idx_kombax_evento_combates_creado_por_v163
  on public.kombax_evento_combates_publicos(creado_por);

create index if not exists idx_kombax_evento_interes_perfil_v163
  on public.kombax_evento_interes(perfil_id,actualizado_en desc);

create index if not exists idx_kombax_evento_social_links_creado_por_v163
  on public.kombax_evento_social_links(creado_por);

commit;
