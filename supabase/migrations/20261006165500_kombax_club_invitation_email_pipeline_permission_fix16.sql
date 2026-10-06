-- FIX16: restore authenticated access to the authorized email-invitation pipeline.
-- Both functions are SECURITY DEFINER and enforce club-role authorization internally.
begin;
revoke all on function public.app_kombax_invitacion_email_payload_v059(uuid) from public,anon;
revoke all on function public.app_kombax_invitacion_email_estado_v059(uuid,text,text) from public,anon;
grant execute on function public.app_kombax_invitacion_email_payload_v059(uuid) to authenticated;
grant execute on function public.app_kombax_invitacion_email_estado_v059(uuid,text,text) to authenticated;
notify pgrst, 'reload schema';
commit;
