-- Rollback aditivo Fase 3 20.092. Ejecutar solo si se decide retirar por completo la capa pública de participantes/combates.
begin;
drop function if exists public.app_kombax_eventos_mutate_v161(text,jsonb,uuid);
drop function if exists public.app_kombax_evento_publico_detalle_v161(uuid);
drop function if exists public.app_kombax_evento_combates_v161(uuid);
drop function if exists public.app_kombax_evento_participantes_v161(uuid);
drop function if exists public.app_kombax_eventos_actor_puede_participar_v161(uuid,uuid);
drop table if exists public.kombax_evento_combates_publicos;
drop table if exists public.kombax_evento_participantes_publicos;
delete from public.kombax_plan_capacidades where capacidad_clave in ('events.public.participate','events.public.fights.manage','events.public.fightcards.read');
delete from public.kombax_capacidades where clave in ('events.public.participate','events.public.fights.manage','events.public.fightcards.read');
commit;
