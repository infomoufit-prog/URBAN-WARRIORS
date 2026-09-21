begin;
drop function if exists public.app_kombax_eventos_invitaciones_contexto_v172(uuid);
notify pgrst,'reload schema';
commit;
