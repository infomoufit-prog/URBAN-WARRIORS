-- Rollback compatible de 039: deshabilita escrituras nuevas sin borrar historial ni columnas.
begin;
revoke execute on function public.app_publicar_branding_v039(uuid,integer,text,text,text) from authenticated;
revoke execute on function public.app_restaurar_branding_v039(uuid,integer) from authenticated;
drop function if exists public.app_publicar_branding_v039(uuid,integer,text,text,text);
drop function if exists public.app_restaurar_branding_v039(uuid,integer);
drop trigger if exists clubes_guard_branding_v039 on public.clubes;
drop function if exists public.app_guard_branding_v039();
drop policy if exists club_branding_history_select_v039 on public.club_branding_history;
revoke execute on function public.app_puede_publicar_branding_v039(uuid) from authenticated;
drop function if exists public.app_puede_publicar_branding_v039(uuid);
-- Se conservan theme_id, branding_version y club_branding_history para evitar pérdida de datos.
commit;
