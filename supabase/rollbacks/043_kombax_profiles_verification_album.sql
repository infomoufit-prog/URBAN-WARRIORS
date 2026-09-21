-- Rollback seguro 043: desactiva funciones de escritura nuevas y conserva datos para migración/forense.
begin;
revoke all on function public.app_kombax_perfil_mutate_v043(text,jsonb,uuid) from authenticated;
revoke all on function public.app_kombax_media_mutate_v043(text,jsonb,uuid) from authenticated;
revoke all on function public.app_kombax_mis_perfiles_v043() from authenticated;
revoke all on function public.app_kombax_mis_solicitudes_v043() from authenticated;
revoke all on function public.app_kombax_album_v043(uuid) from authenticated;
update public.kombax_perfil_media set estado='hidden' where estado='active';
notify pgrst,'reload schema';
commit;
