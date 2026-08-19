-- KOMBAX RC13 build 20034 · 061 · propagate club theme to public profile surfaces.

create or replace function public.app_perfil_club_publico_v061(p_club_id uuid)
returns table(
  club_id uuid,slug text,nombre_publico text,alias text,lema text,descripcion text,historia text,ciudad text,provincia text,pais text,
  logros text,contacto_publico text,web_publica text,instagram text,tiktok text,youtube text,logo_url text,portada_url text,
  visible boolean,moderacion_oculta boolean,editable boolean,disciplinas jsonb,theme_id text
)
language sql stable security definer set search_path=public,auth
as $$
  select p.club_id,p.slug,p.nombre_publico,p.alias,p.lema,p.descripcion,p.historia,p.ciudad,p.provincia,p.pais,
    p.logros,p.contacto_publico,p.web_publica,p.instagram,p.tiktok,p.youtube,p.logo_url,p.portada_url,
    p.visible,p.moderacion_oculta,public.app_puede_gestionar_perfil_club_v035(p.club_id),
    coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'nombre',d.nombre) order by d.orden,d.nombre)
      from public.disciplinas d where d.club_id=p.club_id and d.activa),'[]'::jsonb),
    coalesce(c.theme_id,'combat-dark')
  from public.perfiles_club_publicos p
  join public.clubes c on c.id=p.club_id
  where p.club_id=p_club_id
    and auth.uid() is not null
    and ((p.visible and not p.moderacion_oculta) or public.app_puede_gestionar_perfil_club_v035(p.club_id));
$$;
revoke all on function public.app_perfil_club_publico_v061(uuid) from public,anon;
grant execute on function public.app_perfil_club_publico_v061(uuid) to authenticated;

create or replace function public.app_kombax_perfil_publico_v053(p_social_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare v jsonb;v_member_album jsonb;v_avatar text;v_banner text;v_theme text;
begin
  v:=public.app_kombax_perfil_publico_v052(p_social_id);
  v_avatar:=public.app_kombax_social_avatar_path_v058(p_social_id);
  v_banner:=public.app_kombax_social_banner_path_v058(p_social_id);
  if v_avatar is not null then v:=jsonb_set(v,'{avatar_path}',to_jsonb(v_avatar),true);end if;
  if v_banner is not null then v:=jsonb_set(v,'{banner_path}',to_jsonb(v_banner),true);end if;
  if coalesce(v->>'sujeto_tipo','')='miembro' then
    select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'tipo',m.tipo,'storage_path',m.storage_path,'mime_type',m.mime_type,'duration_seconds',m.duration_seconds) order by m.creado_en desc),'[]'::jsonb)
      into v_member_album from public.kombax_social_media m where m.social_profile_id=p_social_id and m.estado='active' and m.en_album and m.tipo in ('photo','video');
    v:=jsonb_set(v,'{album}',coalesce(v_member_album,'[]'::jsonb),true);
  end if;
  if coalesce(v->>'sujeto_tipo','')='club' then
    select coalesce(c.theme_id,'combat-dark') into v_theme
      from public.clubes c where c.id=nullif(v->>'club_id','')::uuid;
    if v_theme is not null then v:=jsonb_set(v,'{theme_id}',to_jsonb(v_theme),true);end if;
  end if;
  return v;
end $$;
revoke all on function public.app_kombax_perfil_publico_v053(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v053(uuid) to authenticated;

notify pgrst,'reload schema';
