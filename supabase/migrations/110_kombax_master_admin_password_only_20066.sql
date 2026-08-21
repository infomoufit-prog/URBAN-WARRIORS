-- KOMBAX RC13 build 20066 · 110
-- TEMPORAL QA: acceso maestro con Owner + contraseña reciente, sin correo OTP.
-- Mantiene challenge, session_id, expiración y autorización backend.
begin;

create or replace function public.app_kombax_platform_admin_password_complete_v110(p_challenge_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_session_id text:=nullif(auth.jwt()->>'session_id','');
  v_challenge public.kombax_platform_admin_challenges%rowtype;
  v_expira timestamptz:=now()+interval '30 minutes';
  v_nivel text;
begin
  if v_uid is null or v_session_id is null then raise exception 'KOMBAX_ADMIN_AUTH_REQUIRED'; end if;

  select a.nivel into v_nivel
  from public.kombax_platform_admins a
  where a.perfil_id=v_uid and a.activo
  limit 1;
  if v_nivel is null then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;

  -- La contraseña debe haberse validado recientemente en ESTA sesión Auth.
  if not public.app_kombax_auth_method_recent_v108('password',600) then
    raise exception 'KOMBAX_ADMIN_PASSWORD_REQUIRED';
  end if;

  select * into v_challenge
  from public.kombax_platform_admin_challenges c
  where c.id=p_challenge_id and c.perfil_id=v_uid
  for update;

  if v_challenge.id is null
     or v_challenge.consumido_en is not null
     or v_challenge.expira_en<=now()
     or coalesce(v_challenge.password_session_id,'')<>v_session_id then
    raise exception 'KOMBAX_ADMIN_CHALLENGE_INVALID';
  end if;

  update public.kombax_platform_admin_challenges
     set consumido_en=now()
   where id=v_challenge.id;

  update public.kombax_platform_admin_sessions
     set terminado_en=coalesce(terminado_en,now())
   where perfil_id=v_uid and terminado_en is null;

  insert into public.kombax_platform_admin_sessions(perfil_id,auth_session_id,challenge_id,expira_en)
  values(v_uid,v_session_id,v_challenge.id,v_expira);

  return jsonb_build_object('authorized',true,'nivel',v_nivel,'expires_at',v_expira,'auth_mode','password');
end;
$$;

revoke all on function public.app_kombax_platform_admin_password_complete_v110(uuid) from public,anon;
grant execute on function public.app_kombax_platform_admin_password_complete_v110(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
