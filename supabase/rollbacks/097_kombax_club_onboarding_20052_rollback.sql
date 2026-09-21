begin;
drop trigger if exists trg_kombax_club_application_provision_v097 on public.kombax_solicitudes_alta;
drop function if exists public.app_kombax_club_application_provision_v097();
drop function if exists public.app_kombax_platform_mutate_v097(text,jsonb,uuid);
drop function if exists public.app_kombax_mis_clubes_v097();
drop function if exists public.app_kombax_create_club_core_v097(uuid,text,jsonb,jsonb,uuid);
drop index if exists public.idx_kombax_solicitudes_alta_club_v097;
alter table public.kombax_solicitudes_alta drop column if exists club_id;
commit;
