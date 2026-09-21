-- Rollback conservador 059: restaura gateway anterior y conserva columnas/códigos para auditoría.
begin;
do $$ begin
  if to_regprocedure('public.app_mutate_v160_pre_invites_059(text,jsonb,uuid)') is not null then
    drop function if exists public.app_mutate_v160(text,jsonb,uuid);
    alter function public.app_mutate_v160_pre_invites_059(text,jsonb,uuid) rename to app_mutate_v160;
    grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;
  end if;
end $$;
drop function if exists public.app_kombax_invitacion_email_estado_v059(uuid,text,text);
drop function if exists public.app_kombax_invitacion_email_payload_v059(uuid);
drop function if exists public.app_kombax_invitacion_aceptar_equipo_v059(text);
drop function if exists public.app_kombax_invitacion_validar_v059(text,text);
drop function if exists public.app_kombax_invitacion_crear_v059(uuid,text,text,text,text,integer);
drop function if exists public.app_kombax_invitation_code_v059(text);
notify pgrst,'reload schema';
commit;
