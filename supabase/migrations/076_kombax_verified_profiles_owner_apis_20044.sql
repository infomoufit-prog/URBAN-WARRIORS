-- KOMBAX RC13 build 20044 · 076 · kombax verified profiles owner apis

begin;

-- ---------------------------------------------------------------------------
-- 5. Listados propios y álbum, conscientes de gestores/servicio.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_mis_perfiles_v072()
returns table(id uuid,tipo text,slug text,nombre_publico text,descripcion text,workflow_estado text,verificacion_estado text,publico boolean,ubicacion text,disciplinas text[],categoria text,club_declarado text,web_publica text,avatar_path text,banner_path text,origen_identidad_social_id uuid,manager_role text,servicio_estado text,plan_codigo text,social_profile_id uuid,actualizado_en timestamptz)
language sql stable security definer set search_path=public,auth as $$
  select d.id,d.tipo,d.slug,d.nombre_publico,d.descripcion,d.workflow_estado,d.verificacion_estado,d.publico,d.ubicacion,d.disciplinas,d.categoria,d.club_declarado,d.web_publica,d.avatar_path,d.banner_path,
    d.origen_identidad_social_id,case when d.perfil_id=auth.uid() then 'owner' else g.rol end,
    coalesce(s.estado,'inactiva'),s.modalidad,(select sp.id from public.kombax_social_perfiles sp where sp.perfil_directo_id=d.id limit 1),d.actualizado_en
  from public.perfiles_kombax_directos d left join public.kombax_perfil_gestores g on g.perfil_directo_id=d.id and g.perfil_id=auth.uid() and g.estado='activo'
  left join lateral(select x.estado,x.modalidad from public.kombax_suscripciones x where x.sujeto_tipo='perfil_directo' and x.sujeto_id=d.id order by x.actualizado_en desc limit 1)s on true
  where d.perfil_id=auth.uid() or g.id is not null order by d.creado_en;
$$;
revoke all on function public.app_kombax_mis_perfiles_v072() from public,anon;
grant execute on function public.app_kombax_mis_perfiles_v072() to authenticated;

create or replace function public.app_kombax_mis_solicitudes_v072()
returns table(id uuid,tipo text,perfil_directo_id uuid,nombre_publico text,datos_publicos jsonb,datos_verificacion jsonb,estado text,motivo_revision text,declaracion_aceptada boolean,enviado_en timestamptz,revisado_en timestamptz,actualizado_en timestamptz)
language sql stable security definer set search_path=public,auth as $$
  select s.id,s.tipo,s.perfil_directo_id,s.nombre_publico,s.datos_publicos,s.datos_verificacion,s.estado,s.motivo_revision,s.declaracion_aceptada,s.enviado_en,s.revisado_en,s.actualizado_en
  from public.kombax_solicitudes_alta s where s.perfil_id=auth.uid() or (s.perfil_directo_id is not null and public.app_kombax_puede_gestionar_perfil_v070(s.perfil_directo_id,'admin')) order by s.creado_en desc;
$$;
revoke all on function public.app_kombax_mis_solicitudes_v072() from public,anon;
grant execute on function public.app_kombax_mis_solicitudes_v072() to authenticated;

create or replace function public.app_kombax_album_v072(p_perfil_directo_id uuid)
returns table(id uuid,tipo text,storage_path text,mime_type text,bytes bigint,width integer,height integer,duration_seconds numeric,"position" integer,estado text,creado_en timestamptz)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_public boolean;v_official boolean;v_manage boolean;
begin
  select d.publico,(d.workflow_estado in ('verified','limited') and d.estado='activo' and d.verificacion_estado='verificado' and public.app_kombax_perfil_servicio_activo_v071(d.id)),public.app_kombax_puede_gestionar_perfil_v070(d.id,'read')
  into v_public,v_official,v_manage from public.perfiles_kombax_directos d where d.id=p_perfil_directo_id;
  if not found then raise exception 'KOMBAX_PROFILE_NOT_FOUND'; end if;
  if not v_manage and not public.app_kombax_es_moderador_v041() and not(v_public and v_official) then raise exception 'KOMBAX_PROFILE_NOT_PUBLIC'; end if;
  return query select m.id,m.tipo,m.storage_path,m.mime_type,m.bytes,m.width,m.height,m.duration_seconds,m.position,m.estado,m.creado_en from public.kombax_perfil_media m
  where m.perfil_directo_id=p_perfil_directo_id and (v_manage or public.app_kombax_es_moderador_v041() or m.estado='active')
  order by case m.tipo when 'avatar' then 0 when 'banner' then 1 when 'photo' then 2 else 3 end,m.position,m.creado_en;
end $$;
revoke all on function public.app_kombax_album_v072(uuid) from public,anon;
grant execute on function public.app_kombax_album_v072(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
