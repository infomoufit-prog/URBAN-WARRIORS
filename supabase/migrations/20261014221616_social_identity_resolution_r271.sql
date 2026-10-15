-- R271: compatible identity resolution. No historical rows are rewritten.
create or replace function private.kombax_social_person_owner_r271(p_id uuid)
returns uuid language sql stable security definer set search_path='' as $$
 select case when sp.sujeto_tipo='miembro' then i.perfil_id
             when d.tipo in ('espectador','competidor','profesional') then d.perfil_id end
 from public.kombax_social_perfiles sp
 left join public.identidades_sociales i on i.id=sp.identidad_social_id
 left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
 where sp.id=p_id;
$$;
revoke all on function private.kombax_social_person_owner_r271(uuid) from public,anon,authenticated;

create or replace function private.kombax_social_identity_meta_r271(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_owner_id uuid; canonical_id uuid; aliases uuid[]; types text[];
begin
 v_owner_id:=private.kombax_social_person_owner_r271(p_id);
 if v_owner_id is null then return jsonb_build_object('canonical_social_id',p_id,'personal_aliases',jsonb_build_array(p_id),'is_personal',false); end if;
 select array_agg(sp.id order by sp.creado_en,sp.id),
        array_agg(distinct public.app_kombax_social_tipo_v051(sp.id))
 into aliases,types
 from public.kombax_social_perfiles sp
 where sp.visible and sp.estado='activo'
 and private.kombax_social_person_owner_r271(sp.id)=v_owner_id;
 canonical_id:=coalesce(aliases[1],p_id);
 return jsonb_build_object('canonical_social_id',canonical_id,'personal_aliases',coalesce(to_jsonb(aliases),jsonb_build_array(p_id)),
 'facet_types',coalesce(to_jsonb(types),'[]'::jsonb),'is_personal',true);
end $$;
revoke all on function private.kombax_social_identity_meta_r271(uuid) from public,anon,authenticated;

-- Interaction eligibility is distinct from publication. Keep club isolation.
create or replace function private.kombax_workspace_actor_allowed_v147(p_club_id uuid,p_social_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select private.kombax_workspace_club_access_v147(p_club_id) and exists(
 select 1 from public.kombax_social_perfiles sp
 left join public.identidades_sociales i on i.id=sp.identidad_social_id
 where sp.id=p_social_id and sp.visible and sp.estado='activo' and (
  (sp.sujeto_tipo='club' and sp.club_id=p_club_id
   and (public.app_kombax_social_network_actor_allowed_v255(sp.id)
        or coalesce(public.app_kombax_support_club_v140(p_club_id),false)))
  or (sp.sujeto_tipo='miembro' and i.club_origen_id=p_club_id
      and i.perfil_id=(select auth.uid()) and i.estado='activa'
      and public.app_kombax_social_network_actor_allowed_v255(sp.id))
 ));
$$;
revoke all on function private.kombax_workspace_actor_allowed_v147(uuid,uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_identity_catalog_r271(p_club_id uuid default null,p_workspace boolean default false)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_workspace and not private.kombax_workspace_club_access_v147(p_club_id) then raise exception 'CLUB_ACCESS_REQUIRED'; end if;
 select coalesce(jsonb_agg(
 jsonb_build_object('id',sp.id,'sujeto_tipo',sp.sujeto_tipo,'nombre_publico',sp.nombre_publico,'slug',sp.slug,
 'avatar_url',public.app_kombax_social_avatar_url_v063(sp.id),'avatar_path',public.app_kombax_social_avatar_path_v058(sp.id),
 'banner_url',public.app_kombax_social_banner_url_v063(sp.id),'banner_path',public.app_kombax_social_banner_path_v058(sp.id),
 'verificado',sp.verificado,'contacto_habilitado',public.app_kombax_social_contactable_v041(sp.id),
 'perfil_directo_id',sp.perfil_directo_id,'perfil_tipo',public.app_kombax_social_tipo_v051(sp.id),
 'club_id',coalesce(sp.club_id,i.club_origen_id),'club_nombre',c.nombre,
 'identity_label',sp.nombre_publico||' · '||initcap(public.app_kombax_social_tipo_v051(sp.id)),
 'publication_enabled',public.app_kombax_social_puede_actuar_v051(sp.id),
 'network_enabled',public.app_kombax_social_network_actor_allowed_v255(sp.id),
 'album_enabled',public.app_kombax_social_tipo_v051(sp.id)<>'espectador',
 'management_enabled',public.app_kombax_social_puede_gestionar_perfil_publico_r117(sp.id),
 'profile_state',sp.estado) || private.kombax_social_identity_meta_r271(sp.id)
 order by case when sp.sujeto_tipo='club' and sp.club_id=p_club_id then 0 else 1 end,sp.nombre_publico,sp.id),'[]'::jsonb)
 into result
 from public.kombax_social_perfiles sp
 left join public.identidades_sociales i on i.id=sp.identidad_social_id
 left join public.clubes c on c.id=coalesce(sp.club_id,i.club_origen_id)
 where (public.app_kombax_social_puede_gestionar_perfil_publico_r117(sp.id) or public.app_kombax_social_network_actor_allowed_v255(sp.id))
 and (p_club_id is null or sp.sujeto_tipo<>'club' or sp.club_id=p_club_id)
 and (not p_workspace or private.kombax_workspace_actor_allowed_v147(p_club_id,sp.id));
 return result;
end $$;
revoke all on function public.app_kombax_social_identity_catalog_r271(uuid,boolean) from public,anon;
grant execute on function public.app_kombax_social_identity_catalog_r271(uuid,boolean) to authenticated;

-- Every variant is checked through the existing public-profile access policy.
create or replace function public.app_kombax_social_identity_bundle_r271(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare requested jsonb; meta jsonb; variants jsonb:='[]'::jsonb; item jsonb; id uuid;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 requested:=public.app_kombax_perfil_publico_v094(p_social_id);
 if requested is null then return null; end if;
 meta:=private.kombax_social_identity_meta_r271(p_social_id);
 for id in select value::text::uuid from jsonb_array_elements_text(meta->'personal_aliases')
 loop
  item:=public.app_kombax_perfil_publico_v094(id);
  if item is not null then variants:=variants||jsonb_build_array(item); end if;
 end loop;
 if jsonb_array_length(variants)=0 then variants:=jsonb_build_array(requested); end if;
 -- If the canonical variant cannot be read, do not expose its identifier.
 if not exists(select 1 from jsonb_array_elements(variants) v where v->>'id'=meta->>'canonical_social_id') then
  meta:=jsonb_set(meta,'{canonical_social_id}',to_jsonb(p_social_id));
 end if;
 meta:=jsonb_set(meta,'{personal_aliases}',(select jsonb_agg(v->'id') from jsonb_array_elements(variants) v));
 return meta||jsonb_build_object('requested_social_id',p_social_id,'variants',variants);
end $$;
revoke all on function public.app_kombax_social_identity_bundle_r271(uuid) from public,anon;
grant execute on function public.app_kombax_social_identity_bundle_r271(uuid) to authenticated;
notify pgrst,'reload schema';
-- Canonical cards retain query matching by facet without duplicating the person.
create or replace function public.app_kombax_social_directory_r271(p_query text default '',p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare row_data jsonb; bundle jsonb; root jsonb; seen uuid[]:='{}'; result jsonb:='[]'; cid uuid;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 for row_data in select to_jsonb(r) from public.app_kombax_social_directorio_v072(p_query,least(50,greatest(1,p_limit))) r
 loop
  bundle:=public.app_kombax_social_identity_bundle_r271((row_data->>'id')::uuid);
  if bundle is null then continue; end if;
  cid:=(bundle->>'canonical_social_id')::uuid;
  if cid=any(seen) then continue; end if;
  seen:=array_append(seen,cid);
  select v into root from jsonb_array_elements(bundle->'variants') v where v->>'id'=cid::text;
  result:=result||jsonb_build_array(row_data||jsonb_build_object(
  'id',cid,'nombre_publico',root->'nombre_publico','avatar_url',root->'avatar_url','avatar_path',root->'avatar_path',
  'perfil_tipo',root->'perfil_tipo','sujeto_tipo',root->'sujeto_tipo','verificado',root->'verificado',
  'canonical_social_id',cid,'facet_types',bundle->'facet_types','is_personal',bundle->'is_personal'));
 end loop;
 return result;
end $$;
revoke all on function public.app_kombax_social_directory_r271(text,integer) from public,anon;
grant execute on function public.app_kombax_social_directory_r271(text,integer) to authenticated;

-- Existing 18-field contracts keep their shape. Manageability is not publication.
create or replace function public.app_kombax_social_mis_perfiles_v051(p_club_id uuid default null)
returns table(id uuid,sujeto_tipo text,nombre_publico text,slug text,avatar_url text,avatar_path text,banner_url text,banner_path text,verificado boolean,contacto_habilitado boolean,perfil_directo_id uuid,perfil_tipo text,club_id uuid,club_nombre text,identity_label text,publication_enabled boolean,network_enabled boolean,album_enabled boolean)
language sql stable security definer set search_path='' as $$
 select * from public.app_kombax_social_mis_perfiles_r117(p_club_id);
$$;
revoke all on function public.app_kombax_social_mis_perfiles_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_mis_perfiles_v051(uuid) to authenticated;
notify pgrst,'reload schema';
