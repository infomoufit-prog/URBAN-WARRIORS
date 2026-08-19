begin;
revoke all on function public.app_kombax_relacion_mutate_v045(text,jsonb,uuid) from authenticated;
revoke all on function public.app_kombax_relaciones_v045(uuid) from authenticated;
revoke all on function public.app_kombax_showcase_mis_espacios_v045(uuid) from authenticated;
revoke all on function public.app_kombax_showcase_ensure_club_v045(uuid) from authenticated;
update public.kombax_relaciones set estado='suspended' where estado in ('pending','confirmed');
notify pgrst,'reload schema';
commit;
