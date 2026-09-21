select v.index_name, to_regclass('public.'||v.index_name) is not null as ok
from (values
 ('idx_kombax_eventos_publicos_creado_por_v163'),
 ('idx_kombax_evento_entidades_creado_por_v163'),
 ('idx_kombax_evento_entidades_respondido_por_v163'),
 ('idx_kombax_evento_participantes_competidor_v163'),
 ('idx_kombax_evento_participantes_club_v163'),
 ('idx_kombax_evento_participantes_creado_por_v163'),
 ('idx_kombax_evento_combates_participante_a_v163'),
 ('idx_kombax_evento_combates_participante_b_v163'),
 ('idx_kombax_evento_combates_ganador_v163'),
 ('idx_kombax_evento_combates_creado_por_v163'),
 ('idx_kombax_evento_interes_perfil_v163'),
 ('idx_kombax_evento_social_links_creado_por_v163')
) as v(index_name)
order by v.index_name;
