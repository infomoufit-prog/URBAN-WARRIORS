-- Verificación read-only 20.091
select to_regclass('public.kombax_eventos_publicos') as public_events_foundation,
       to_regclass('public.kombax_evento_entidades') as organizations_layer,
       to_regclass('public.eventos_competicion') as internal_club_events_kept_separate;
select to_regprocedure('public.app_kombax_evento_publico_detalle_v160(uuid)') is not null as detail_v160,
       to_regprocedure('public.app_kombax_eventos_mutate_v160(text,jsonb,uuid)') is not null as mutate_v160,
       to_regprocedure('public.app_kombax_eventos_mis_organizadores_v160()') is not null as organizer_contexts_v160;
select count(*)=0 as no_internal_event_fk
from pg_constraint c
join pg_class t on t.oid=c.conrelid
where t.relname='kombax_evento_entidades' and pg_get_constraintdef(c.oid) ilike '%eventos_competicion%';
