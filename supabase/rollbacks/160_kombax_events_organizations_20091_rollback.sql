-- Rollback build 20.091 · no toca KOMBAX Eventos Foundation 20.090 ni Mi Club > Eventos.
begin;
drop function if exists public.app_kombax_eventos_mutate_v160(text,jsonb,uuid);
drop function if exists public.app_kombax_eventos_invitaciones_v160();
drop function if exists public.app_kombax_evento_publico_detalle_v160(uuid);
drop function if exists public.app_kombax_evento_entidades_v160(uuid);
drop function if exists public.app_kombax_eventos_mis_organizadores_v160();
drop function if exists public.app_kombax_evento_puede_gestionar_v160(uuid);
drop function if exists public.app_kombax_eventos_puede_actuar_social_v160(uuid);
drop function if exists public.app_kombax_eventos_sujeto_puede_organizar_v160(text,uuid);
drop function if exists public.app_kombax_eventos_social_subject_v160(uuid);
drop table if exists public.kombax_evento_entidades;
delete from public.kombax_plan_capacidades where capacidad_clave in ('events.public.organize','events.public.partners.manage','events.public.share') and plan_codigo='federacion_institucional';
delete from public.kombax_capacidades where clave='events.public.partners.manage' and not exists(select 1 from public.kombax_entitlements e where e.capacidad_clave='events.public.partners.manage');
commit;
