-- Reviewed rollback; not executed. Apply only with the previous frontend or its missing-RPC fallbacks.
begin;
CREATE OR REPLACE FUNCTION private.kombax_workspace_actor_allowed_v147(p_club_id uuid, p_social_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select private.kombax_workspace_club_access_v147(p_club_id)
    and p_social_id is not null
    and exists(
      select 1
      from public.kombax_social_perfiles sp
      left join public.identidades_sociales i on i.id=sp.identidad_social_id
      where sp.id=p_social_id
        and sp.visible
        and sp.estado='activo'
        and (
          (sp.sujeto_tipo='club' and sp.club_id=p_club_id
            and (public.app_kombax_social_puede_actuar_v051(sp.id)
              or coalesce(public.app_kombax_support_club_v140(p_club_id),false)))
          or
          (sp.sujeto_tipo='miembro'
            and i.club_origen_id=p_club_id
            and i.perfil_id=(select auth.uid())
            and i.estado='activa'
            and public.app_kombax_social_puede_actuar_v051(sp.id))
        )
    );
$function$
;
CREATE OR REPLACE FUNCTION public.app_kombax_social_mis_perfiles_v051(p_club_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(id uuid, sujeto_tipo text, nombre_publico text, slug text, avatar_url text, avatar_path text, banner_url text, banner_path text, verificado boolean, contacto_habilitado boolean, perfil_directo_id uuid, perfil_tipo text, club_id uuid, club_nombre text, identity_label text, publication_enabled boolean, network_enabled boolean, album_enabled boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select p.*,public.app_kombax_social_puede_actuar_v051(p.id),
  public.app_kombax_social_network_actor_allowed_v255(p.id),
  coalesce(p.perfil_tipo<>'espectador',false)
 from public.app_kombax_social_mis_perfiles_pre_capabilities_r270(p_club_id) p;
$function$
;
drop function if exists public.app_kombax_social_directory_r271(text,integer);
drop function if exists public.app_kombax_social_identity_bundle_r271(uuid);
drop function if exists public.app_kombax_social_identity_catalog_r271(uuid,boolean);
drop function if exists private.kombax_social_identity_meta_r271(uuid);
drop function if exists private.kombax_social_person_owner_r271(uuid);
notify pgrst,'reload schema';
commit;
