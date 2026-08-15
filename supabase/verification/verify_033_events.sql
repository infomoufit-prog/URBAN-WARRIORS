-- Urban Warriors RC13 · verificación 033. SOLO LECTURA.
-- Resultado requerido: todos los controles booleanos = true y 0 incidencias.
select * from (values
  ('eventos',to_regclass('public.eventos_competicion') is not null),
  ('participantes',to_regclass('public.evento_participantes') is not null),
  ('combates',to_regclass('public.evento_combates') is not null),
  ('gateway_033',to_regprocedure('public.app_mutate_v160_pre_events_033(text,jsonb,uuid)') is not null),
  ('contrato_033',to_regprocedure('public.app_runtime_contract_v160_pre_events_033(uuid)') is not null),
  ('permiso_eventos',to_regprocedure('public.app_puede_gestionar_eventos_v033(uuid)') is not null),
  ('rpc_participantes_segura',to_regprocedure('public.app_evento_participantes_visibles_v033(uuid,uuid)') is not null),
  ('rpc_combates_segura',to_regprocedure('public.app_evento_combates_visibles_v033(uuid,uuid)') is not null),
  ('participantes_sin_select_directo',not has_table_privilege('authenticated','public.evento_participantes','SELECT')),
  ('combates_sin_select_directo',not has_table_privilege('authenticated','public.evento_combates','SELECT'))
) x(control,ok) order by control;

select 'combates_participantes_fuera_evento' control,count(*) incidencias
from public.evento_combates c
left join public.evento_participantes a on a.club_id=c.club_id and a.id=c.participante_a_id and a.evento_id=c.evento_id
left join public.evento_participantes b on b.club_id=c.club_id and b.id=c.participante_b_id and b.evento_id=c.evento_id
where a.id is null or b.id is null;

select 'combates_con_participante_no_confirmado' control,count(*) incidencias
from public.evento_combates c
join public.evento_participantes a on a.club_id=c.club_id and a.id=c.participante_a_id
join public.evento_participantes b on b.club_id=c.club_id and b.id=c.participante_b_id
where c.estado<>'cancelado' and (a.estado<>'confirmado' or b.estado<>'confirmado');
