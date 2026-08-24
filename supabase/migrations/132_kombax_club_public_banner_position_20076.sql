-- KOMBAX RC13 build 20076 · expose canonical banner focal point in the dedicated club public-profile view.
begin;

create or replace function public.app_perfil_club_publico_v132(p_club_id uuid)
returns table(
  club_id uuid,slug text,nombre_publico text,alias text,lema text,descripcion text,historia text,ciudad text,provincia text,pais text,
  logros text,contacto_publico text,web_publica text,instagram text,tiktok text,youtube text,logo_url text,portada_url text,
  visible boolean,moderacion_oculta boolean,editable boolean,disciplinas jsonb,theme_id text,
  social_profile_id uuid,banner_position_x numeric,banner_position_y numeric
)
language sql stable security definer set search_path=public,auth as $$
  select b.club_id,b.slug,b.nombre_publico,b.alias,b.lema,b.descripcion,b.historia,b.ciudad,b.provincia,b.pais,
    b.logros,b.contacto_publico,b.web_publica,b.instagram,b.tiktok,b.youtube,b.logo_url,b.portada_url,
    b.visible,b.moderacion_oculta,b.editable,b.disciplinas,b.theme_id,
    sp.id,coalesce(sp.banner_position_x,50),coalesce(sp.banner_position_y,50)
  from public.app_perfil_club_publico_v061(p_club_id) b
  left join public.kombax_social_perfiles sp on sp.sujeto_tipo='club' and sp.club_id=b.club_id
  limit 1;
$$;
revoke all on function public.app_perfil_club_publico_v132(uuid) from public,anon;
grant execute on function public.app_perfil_club_publico_v132(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
