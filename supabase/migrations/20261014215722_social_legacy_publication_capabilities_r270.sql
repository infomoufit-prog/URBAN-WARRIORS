-- Keep the original network eligibility and ordering; expose canonical capabilities to older clients.
alter function public.app_kombax_social_mis_perfiles_v051(uuid)
 rename to app_kombax_social_mis_perfiles_pre_capabilities_r270;
revoke all on function public.app_kombax_social_mis_perfiles_pre_capabilities_r270(uuid) from public,anon,authenticated;
create function public.app_kombax_social_mis_perfiles_v051(p_club_id uuid default null)
returns table(id uuid,sujeto_tipo text,nombre_publico text,slug text,avatar_url text,avatar_path text,
 banner_url text,banner_path text,verificado boolean,contacto_habilitado boolean,perfil_directo_id uuid,
 perfil_tipo text,club_id uuid,club_nombre text,identity_label text,publication_enabled boolean,
 network_enabled boolean,album_enabled boolean)
language sql stable security definer set search_path='' as $$
 select p.*,public.app_kombax_social_puede_actuar_v051(p.id),
  public.app_kombax_social_network_actor_allowed_v255(p.id),
  coalesce(p.perfil_tipo<>'espectador',false)
 from public.app_kombax_social_mis_perfiles_pre_capabilities_r270(p_club_id) p;
$$;
revoke all on function public.app_kombax_social_mis_perfiles_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_mis_perfiles_v051(uuid) to authenticated;
notify pgrst,'reload schema';
