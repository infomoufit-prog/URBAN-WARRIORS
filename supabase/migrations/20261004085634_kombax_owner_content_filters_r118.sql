-- Owner-only filters run before pagination; no public access or content writes.
create or replace function public.app_kombax_content_browse_filtered_r118(
 p_channel text,p_state text default '',p_search text default '',p_offset integer default 0,
 p_from timestamptz default null,p_until timestamptz default null,p_profile text default '',p_club text default '',p_profile_type text default '')
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or not coalesce(public.app_kombax_es_moderador_v041(),false) then raise exception 'MODERATOR_REQUIRED' using errcode='42501';end if;
 if p_from is not null and p_until is not null and p_from>=p_until then raise exception 'INVALID_DATE_RANGE';end if;
 if coalesce(p_profile_type,'') not in('','club','marca','federacion','profesional','competidor','miembro','espectador') then raise exception 'INVALID_PROFILE_TYPE';end if;
 if p_channel='social' then
  select coalesce(jsonb_agg(row_data),'[]'::jsonb) into result from (
   select jsonb_build_object('id',p.id,'title',s.nombre_publico,'text',p.texto,'state',p.estado,'created_at',p.creado_en,
    'moderation_state',l.state,'reason',l.reason,'media',coalesce(to_jsonb(m),to_jsonb(pm)),'author_id',p.autor_perfil_id,
    'profile_type',public.app_kombax_social_tipo_v051(s.id),'club_name',c.nombre) row_data
   from public.kombax_social_publicaciones p join public.kombax_social_perfiles s on s.id=p.autor_perfil_id
   left join public.identidades_sociales i on i.id=s.identidad_social_id
   left join public.clubes c on c.id=coalesce(s.club_id,i.club_origen_id)
   left join public.kombax_social_media m on m.id=p.social_media_id
   left join public.kombax_perfil_media pm on pm.id=p.media_id
   left join kombax_moderation.content_state l on l.channel='social' and l.content_id=p.id
   where (coalesce(p_state,'')='' or p.estado=p_state)
    and (p_from is null or p.creado_en>=p_from) and (p_until is null or p.creado_en<p_until)
    and (coalesce(p_search,'')='' or p.texto ilike '%'||left(p_search,120)||'%' or s.nombre_publico ilike '%'||left(p_search,120)||'%')
    and (coalesce(p_profile,'')='' or s.nombre_publico ilike '%'||left(p_profile,120)||'%' or s.id::text=p_profile)
    and (coalesce(p_club,'')='' or c.nombre ilike '%'||left(p_club,120)||'%' or c.id::text=p_club)
    and (coalesce(p_profile_type,'')='' or public.app_kombax_social_tipo_v051(s.id)=p_profile_type)
   order by p.creado_en desc,p.id desc limit 11 offset greatest(0,coalesce(p_offset,0))
  ) q;
 elsif p_channel='showcase' then
  select coalesce(jsonb_agg(row_data),'[]'::jsonb) into result from (
   select jsonb_build_object('id',e.id,'title',e.nombre,'text',e.descripcion,'summary',e.resumen,'state',e.estado,'created_at',e.creado_en,
    'moderation_state',l.state,'reason',l.reason,'image_url',e.imagen_url,'gallery',e.galeria,'seller',m.nombre,'commerce_enabled',e.commerce_enabled,
    'author_id',m.perfil_directo_id,'profile_type',case when m.club_id is not null then 'club' else d.tipo end,'club_name',c.nombre) row_data
   from public.kombax_showcase_elementos e join public.kombax_showcase_marcas m on m.id=e.marca_id
   left join public.perfiles_kombax_directos d on d.id=m.perfil_directo_id
   left join public.clubes c on c.id=m.club_id
   left join kombax_moderation.content_state l on l.channel='showcase' and l.content_id=e.id
   where (coalesce(p_state,'')='' or e.estado=p_state)
    and (p_from is null or e.creado_en>=p_from) and (p_until is null or e.creado_en<p_until)
    and (coalesce(p_search,'')='' or e.nombre ilike '%'||left(p_search,120)||'%' or e.descripcion ilike '%'||left(p_search,120)||'%' or m.nombre ilike '%'||left(p_search,120)||'%')
    and (coalesce(p_profile,'')='' or m.nombre ilike '%'||left(p_profile,120)||'%' or d.nombre_publico ilike '%'||left(p_profile,120)||'%' or m.id::text=p_profile or d.id::text=p_profile)
    and (coalesce(p_club,'')='' or c.nombre ilike '%'||left(p_club,120)||'%' or c.id::text=p_club)
    and (coalesce(p_profile_type,'')='' or (case when m.club_id is not null then 'club' else d.tipo end)=p_profile_type)
   order by e.creado_en desc,e.id desc limit 11 offset greatest(0,coalesce(p_offset,0))
  ) q;
 else raise exception 'INVALID_CHANNEL';end if;
 return jsonb_build_object('items',(select coalesce(jsonb_agg(item),'[]'::jsonb) from jsonb_array_elements(result) with ordinality q(item,n) where n<=10),'has_more',jsonb_array_length(result)>10);
end $$;
revoke all on function public.app_kombax_content_browse_filtered_r118(text,text,text,integer,timestamptz,timestamptz,text,text,text) from public,anon;
grant execute on function public.app_kombax_content_browse_filtered_r118(text,text,text,integer,timestamptz,timestamptz,text,text,text) to authenticated;
