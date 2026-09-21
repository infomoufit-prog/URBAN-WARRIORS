begin;
create or replace function public.app_kombax_perfil_publico_v072(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_aff jsonb;v_badge text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  v:=public.app_kombax_perfil_publico_v068(p_social_id); if v is null then return null; end if;
  v_aff:=public.app_kombax_social_afiliacion_v072(p_social_id); v_badge:=public.app_kombax_badge_tipo_v069(p_social_id);
  v:=jsonb_set(v,'{badge_type}',to_jsonb(v_badge),true);
  v:=jsonb_set(v,'{verified}',to_jsonb(v_badge is not null),true);
  if v_aff is not null then v:=jsonb_set(v,'{affiliation}',v_aff,true); else v:=v-'affiliation'; end if;
  return v-'relations';
end $$;
revoke all on function public.app_kombax_perfil_publico_v072(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v072(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
