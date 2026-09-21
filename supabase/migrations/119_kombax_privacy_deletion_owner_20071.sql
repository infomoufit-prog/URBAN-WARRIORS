-- KOMBAX RC13 build 20071 · 119
-- Separación Moderación/Privacidad y ejecución trazable de eliminación de cuenta.
-- La cuenta se anonimiza: se conserva únicamente el UUID técnico necesario para
-- integridad/auditoría y las trazas sujetas a retención. El Auth se desactiva y
-- anonimiza desde la Edge Function account-deletion-executor antes del finalize.
begin;

alter table public.kombax_solicitudes_eliminacion
  add column if not exists ejecucion_iniciada_en timestamptz,
  add column if not exists anonimizado_en timestamptz,
  add column if not exists ejecucion_resumen jsonb;

-- Cola de privacidad: exclusivamente sesión maestra Owner/Admin, nunca Moderador.
create or replace function public.app_kombax_deletion_queue_v119(p_estado text default null,p_limit integer default 50)
returns table(
  id uuid,perfil_id uuid,alcance text,perfil_directo_id uuid,club_id uuid,estado text,
  motivo text,nota_retencion text,resolucion text,solicitado_en timestamptz,
  actualizado_en timestamptz,completado_en timestamptz,ejecucion_iniciada_en timestamptz,
  anonimizado_en timestamptz
)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  return query
  select s.id,s.perfil_id,s.alcance,s.perfil_directo_id,s.club_id,s.estado,
         s.motivo,s.nota_retencion,s.resolucion,s.solicitado_en,s.actualizado_en,
         s.completado_en,s.ejecucion_iniciada_en,s.anonimizado_en
  from public.kombax_solicitudes_eliminacion s
  where p_estado is null or s.estado=lower(p_estado)
  order by case s.estado when 'confirmed' then 0 when 'in_review' then 1 when 'requested' then 2 else 3 end,
           s.solicitado_en asc
  limit least(greatest(coalesce(p_limit,50),1),100);
end $$;
revoke all on function public.app_kombax_deletion_queue_v119(text,integer) from public,anon;
grant execute on function public.app_kombax_deletion_queue_v119(text,integer) to authenticated;

-- Reemplaza únicamente la autorización de review de v047: privacidad/cierre de
-- cuenta pertenece a Owner/Administración, no al rol global de Moderador.
create or replace function public.app_kombax_eliminacion_mutate_v047(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_req public.kombax_solicitudes_eliminacion;v_scope text;v_profile uuid;v_club uuid;v_id uuid;v_state text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);end if;

  if p_operation='kombax.deletion.request' then
    v_scope:=lower(coalesce(v_payload->>'alcance','account'));if v_scope not in ('account','profile','club') then raise exception 'KOMBAX_DELETION_SCOPE_INVALID';end if;
    begin v_profile:=nullif(v_payload->>'perfil_directo_id','')::uuid;v_club:=nullif(v_payload->>'club_id','')::uuid;exception when others then raise exception 'KOMBAX_DELETION_TARGET_INVALID';end;
    if v_scope='account' then v_profile:=null;v_club:=null;
    elsif v_scope='profile' then if v_profile is null or not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_profile and d.perfil_id=v_uid) then raise exception 'KOMBAX_DELETION_PROFILE_FORBIDDEN';end if;v_club:=null;
    else if v_club is null or not public.app_puede_gestionar_perfil_club_v035(v_club) then raise exception 'KOMBAX_DELETION_CLUB_FORBIDDEN';end if;v_profile:=null;end if;
    insert into public.kombax_solicitudes_eliminacion(perfil_id,alcance,perfil_directo_id,club_id,motivo,nota_retencion)
    values(v_uid,v_scope,v_profile,v_club,nullif(left(btrim(v_payload->>'motivo'),1200),''),'La solicitud no borra automáticamente trazabilidad económica o legal que deba conservarse.') returning * into v_req;
    v_result:=to_jsonb(v_req);
  elsif p_operation='kombax.deletion.cancel' then
    begin v_id:=(v_payload->>'solicitud_id')::uuid;exception when others then raise exception 'KOMBAX_DELETION_ID_INVALID';end;
    update public.kombax_solicitudes_eliminacion set estado='cancelled',actualizado_en=now() where id=v_id and perfil_id=v_uid and estado in ('requested','needs_information') returning * into v_req;
    if v_req.id is null then raise exception 'KOMBAX_DELETION_CANCEL_NOT_ALLOWED';end if;v_result:=to_jsonb(v_req);
  elsif p_operation='kombax.deletion.review' then
    if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
    begin v_id:=(v_payload->>'solicitud_id')::uuid;exception when others then raise exception 'KOMBAX_DELETION_ID_INVALID';end;
    v_state:=lower(coalesce(v_payload->>'estado',''));if v_state not in ('in_review','needs_information','confirmed','rejected') then raise exception 'KOMBAX_DELETION_STATE_INVALID';end if;
    update public.kombax_solicitudes_eliminacion
       set estado=v_state,resolucion=nullif(left(btrim(v_payload->>'resolucion'),2000),''),
           nota_retencion=coalesce(nullif(left(btrim(v_payload->>'nota_retencion'),1200),''),nota_retencion),
           resuelto_por=v_uid,actualizado_en=now()
     where id=v_id and completado_en is null returning * into v_req;
    if v_req.id is null then raise exception 'KOMBAX_DELETION_NOT_FOUND';end if;v_result:=to_jsonb(v_req);
  else raise exception 'KOMBAX_DELETION_OPERATION_NOT_ALLOWED';end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when unique_violation then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise exception 'KOMBAX_DELETION_ALREADY_OPEN';
when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_eliminacion_mutate_v047(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eliminacion_mutate_v047(text,jsonb,uuid) to authenticated;

-- Plan exacto de objetos físicos eliminables. La Edge Function lo consume con
-- el JWT Owner y usa service_role únicamente para Storage/Auth, nunca en frontend.
create or replace function public.app_kombax_deletion_plan_v119(p_solicitud_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_req public.kombax_solicitudes_eliminacion;v_target uuid;v_objects jsonb;v_social_ids uuid[];v_direct_ids uuid[];
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  select * into v_req from public.kombax_solicitudes_eliminacion where id=p_solicitud_id for update;
  if v_req.id is null then raise exception 'KOMBAX_DELETION_NOT_FOUND';end if;
  if v_req.alcance<>'account' then raise exception 'KOMBAX_DELETION_EXECUTOR_ACCOUNT_ONLY';end if;
  if v_req.estado<>'confirmed' then raise exception 'KOMBAX_DELETION_CONFIRM_REQUIRED';end if;
  if v_req.completado_en is not null then raise exception 'KOMBAX_DELETION_ALREADY_COMPLETED';end if;
  v_target:=v_req.perfil_id;
  if exists(select 1 from public.kombax_platform_admins where perfil_id=v_target and activo) then raise exception 'KOMBAX_DELETION_PLATFORM_ADMIN_REASSIGN_REQUIRED';end if;

  select coalesce(array_agg(sp.id),'{}'::uuid[]) into v_social_ids
  from public.kombax_social_perfiles sp
  where (sp.sujeto_tipo='miembro' and sp.identidad_social_id in (select i.id from public.identidades_sociales i where i.perfil_id=v_target))
     or (sp.sujeto_tipo='perfil_directo' and sp.perfil_directo_id in (select d.id from public.perfiles_kombax_directos d where d.perfil_id=v_target));
  select coalesce(array_agg(d.id),'{}'::uuid[]) into v_direct_ids from public.perfiles_kombax_directos d where d.perfil_id=v_target;

  select coalesce(jsonb_agg(x.obj order by x.bucket,x.path),'[]'::jsonb) into v_objects
  from (
    select distinct bucket,path,jsonb_build_object('bucket',bucket,'path',path) obj from (
      select 'profile-media'::text bucket,p.avatar_path path from public.perfiles p where p.id=v_target and p.avatar_path is not null
      union all select 'kombax-public-media',sp.avatar_path from public.kombax_social_perfiles sp where sp.id=any(v_social_ids) and sp.avatar_path is not null
      union all select 'kombax-public-media',sp.banner_path from public.kombax_social_perfiles sp where sp.id=any(v_social_ids) and sp.banner_path is not null
      union all select 'kombax-public-media',d.avatar_path from public.perfiles_kombax_directos d where d.id=any(v_direct_ids) and d.avatar_path is not null
      union all select 'kombax-public-media',d.banner_path from public.perfiles_kombax_directos d where d.id=any(v_direct_ids) and d.banner_path is not null
      union all select coalesce(m.storage_bucket,'kombax-public-media'),m.storage_path from public.kombax_social_media m where m.social_profile_id=any(v_social_ids) and m.storage_path is not null
      union all select 'kombax-public-media',m.storage_path from public.kombax_perfil_media m where m.perfil_directo_id=any(v_direct_ids) and m.storage_path is not null
      union all select 'kombax-verification-docs',d.storage_path from public.kombax_verificacion_documentos d where d.perfil_id=v_target and d.storage_path is not null
      union all select 'community-media',p.media_path from public.publicaciones_comunidad p where p.autor_perfil_id=v_target and p.media_path is not null
      union all select 'community-media',p.portada_automatica_path from public.publicaciones_comunidad p where p.autor_perfil_id=v_target and p.portada_automatica_path is not null
      union all select 'community-media',p.portada_manual_path from public.publicaciones_comunidad p where p.autor_perfil_id=v_target and p.portada_manual_path is not null
      union all select 'sports-profile-media',pd.foto_path from public.perfiles_deportivos pd join public.socios s on s.club_id=pd.club_id and s.id=pd.socio_id where s.perfil_id=v_target and pd.foto_path is not null
    ) o where path is not null and btrim(path)<>''
  ) x;

  update public.kombax_solicitudes_eliminacion set ejecucion_iniciada_en=coalesce(ejecucion_iniciada_en,now()),actualizado_en=now() where id=v_req.id;
  return jsonb_build_object('request_id',v_req.id,'target_profile_id',v_target,'storage_objects',v_objects,'storage_count',jsonb_array_length(v_objects));
end $$;
revoke all on function public.app_kombax_deletion_plan_v119(uuid) from public,anon;
grant execute on function public.app_kombax_deletion_plan_v119(uuid) to authenticated;

-- Fase DB posterior a Storage/Auth. Mantiene el UUID técnico como tombstone
-- anónimo para no destruir referencias históricas/financieras/auditoría.
create or replace function public.app_kombax_deletion_finalize_v119(p_solicitud_id uuid,p_auth_anonymized boolean,p_storage_removed integer default 0)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_req public.kombax_solicitudes_eliminacion;v_target uuid;v_social_ids uuid[];v_direct_ids uuid[];v_socios uuid[];v_summary jsonb;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  if p_auth_anonymized is not true then raise exception 'KOMBAX_DELETION_AUTH_ANONYMIZATION_REQUIRED';end if;
  select * into v_req from public.kombax_solicitudes_eliminacion where id=p_solicitud_id for update;
  if v_req.id is null or v_req.alcance<>'account' or v_req.estado<>'confirmed' then raise exception 'KOMBAX_DELETION_NOT_EXECUTABLE';end if;
  if v_req.completado_en is not null then return coalesce(v_req.ejecucion_resumen,jsonb_build_object('ok',true,'already_completed',true));end if;
  v_target:=v_req.perfil_id;
  if exists(select 1 from public.kombax_platform_admins where perfil_id=v_target and activo) then raise exception 'KOMBAX_DELETION_PLATFORM_ADMIN_REASSIGN_REQUIRED';end if;

  select coalesce(array_agg(sp.id),'{}'::uuid[]) into v_social_ids
  from public.kombax_social_perfiles sp
  where (sp.sujeto_tipo='miembro' and sp.identidad_social_id in (select i.id from public.identidades_sociales i where i.perfil_id=v_target))
     or (sp.sujeto_tipo='perfil_directo' and sp.perfil_directo_id in (select d.id from public.perfiles_kombax_directos d where d.perfil_id=v_target));
  select coalesce(array_agg(d.id),'{}'::uuid[]) into v_direct_ids from public.perfiles_kombax_directos d where d.perfil_id=v_target;
  select coalesce(array_agg(s.id),'{}'::uuid[]) into v_socios from public.socios s where s.perfil_id=v_target;

  -- Contenido/interacciones eliminables del usuario.
  delete from public.kombax_social_contactos where remitente_social_id=any(v_social_ids) or destinatario_social_id=any(v_social_ids);
  delete from public.kombax_relaciones where origen_social_id=any(v_social_ids) or destino_social_id=any(v_social_ids);
  delete from public.kombax_social_comentarios where autor_social_id=any(v_social_ids);
  delete from public.kombax_social_likes where perfil_id=v_target;
  delete from public.kombax_social_guardados where perfil_id=v_target;
  delete from public.kombax_social_bloqueos where bloqueador_perfil_id=v_target or bloqueado_social_id=any(v_social_ids);
  delete from public.kombax_social_reportes where reportado_por=v_target;
  delete from public.kombax_social_publicaciones where autor_perfil_id=any(v_social_ids);
  delete from public.kombax_social_media where social_profile_id=any(v_social_ids);
  delete from public.kombax_perfil_media where perfil_directo_id=any(v_direct_ids);
  delete from public.kombax_verificacion_documentos where perfil_id=v_target;
  delete from public.publicaciones_comunidad where autor_perfil_id=v_target;
  delete from public.comunidad_likes where perfil_id=v_target;
  delete from public.reportes_comunidad where reportado_por=v_target;
  delete from public.bloqueos_comunidad where bloqueador_perfil_id=v_target or bloqueado_perfil_id=v_target;
  update public.perfiles_deportivos set foto_path=null,actualizado_en=now() where socio_id=any(v_socios);

  -- Revocación funcional de la cuenta en la plataforma.
  delete from public.dispositivos_push where perfil_id=v_target;
  delete from public.preferencias_notificacion where perfil_id=v_target;
  delete from public.notificaciones where perfil_id=v_target;
  delete from public.notificaciones_lecturas where perfil_id=v_target;
  delete from public.notificaciones_revisiones where perfil_id=v_target;
  delete from public.kombax_club_team_permissions where perfil_id=v_target;
  delete from public.kombax_perfil_gestores where perfil_id=v_target;
  delete from public.kombax_showcase_gestores where perfil_id=v_target;
  delete from public.kombax_showcase_guardados where perfil_id=v_target;
  delete from public.kombax_moderadores_globales where perfil_id=v_target;
  delete from public.kombax_verificadores_globales_v117 where perfil_id=v_target;
  delete from public.moderacion_accesos_sociales where perfil_id=v_target;
  delete from public.kombax_codigo_intentos_v086 where perfil_id=v_target;
  delete from public.kombax_client_incidents_v117 where perfil_id=v_target;
  delete from public.tutores_socios where tutor_perfil_id=v_target;
  delete from public.miembros_club where perfil_id=v_target;
  update public.socios set perfil_id=null where perfil_id=v_target;

  -- Solicitudes de alta conservan solo estado/traza, no dossier aportado.
  update public.kombax_solicitudes_alta set nombre_publico='Cuenta eliminada',datos_publicos='{}'::jsonb,datos_verificacion='{}'::jsonb,motivo_revision=null,actualizado_en=now() where perfil_id=v_target;

  -- Tombstones públicos y administrativos sin PII.
  update public.identidades_sociales
     set slug='deleted-'||replace(id::text,'-',''),nombre_publico='Cuenta eliminada',estado='cerrada',
         bio_publica=null,afiliacion_visible=false,apodo_deportivo=null,disciplinas_publicas=null,
         experiencia_anos=null,guardia=null,tecnica_favorita=null,especialidad=null,
         trayectoria_declarada=null,objetivos=null,suspension_motivo=null,actualizado_en=now()
   where perfil_id=v_target;
  update public.kombax_social_perfiles
     set slug='deleted-'||replace(id::text,'-',''),nombre_publico='Cuenta eliminada',bio=null,
         avatar_url=null,banner_url=null,avatar_path=null,banner_path=null,visible=false,
         publicar_habilitado=false,contacto_habilitado=false,estado='cerrado',actualizado_en=now()
   where id=any(v_social_ids);
  update public.perfiles_kombax_directos
     set slug='deleted-'||replace(id::text,'-',''),nombre_publico='Cuenta eliminada',descripcion=null,
         estado='cerrado',verificacion_estado='no_iniciada',publico=false,moderacion_estado='normal',
         workflow_estado='suspended',ubicacion=null,disciplinas='{}'::text[],categoria=null,
         club_declarado=null,web_publica=null,avatar_path=null,banner_path=null,
         social_activo=false,social_activado_en=null,social_normas_version=null,
         fecha_nacimiento_verificada=null,actualizado_en=now()
   where perfil_id=v_target;
  update public.perfiles set nombre=null,apellidos=null,telefono=null,avatar_url=null,avatar_path=null,actualizado_en=now() where id=v_target;

  v_summary:=jsonb_build_object('ok',true,'request_id',v_req.id,'target_profile_id',v_target,'auth_anonymized',true,'storage_removed',greatest(coalesce(p_storage_removed,0),0),'completed_at',now());
  update public.kombax_solicitudes_eliminacion set estado='completed',resolucion='Cuenta desactivada y datos eliminables anonimizados/eliminados. Se conservan únicamente trazas técnicas o legalmente exigibles.',resuelto_por=auth.uid(),actualizado_en=now(),completado_en=now(),anonimizado_en=now(),ejecucion_resumen=v_summary where id=v_req.id;
  return v_summary;
end $$;
revoke all on function public.app_kombax_deletion_finalize_v119(uuid,boolean,integer) from public,anon;
grant execute on function public.app_kombax_deletion_finalize_v119(uuid,boolean,integer) to authenticated;

notify pgrst,'reload schema';
commit;
