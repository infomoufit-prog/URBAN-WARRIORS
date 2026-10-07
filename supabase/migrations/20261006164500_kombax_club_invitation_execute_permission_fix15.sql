-- FIX15: restore authenticated RPC access for club email invitations.
-- The function is SECURITY DEFINER and performs its own club-role authorization.
begin;
revoke all on function public.app_kombax_invitacion_crear_v059(uuid,text,text,text,text,integer) from public,anon;
grant execute on function public.app_kombax_invitacion_crear_v059(uuid,text,text,text,text,integer) to authenticated;
notify pgrst, 'reload schema';
commit;
