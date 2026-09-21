begin;

-- KOMBAX 049 · acceso Social global para perfiles directos verificados.
-- La activación es voluntaria y separada de la mera verificación.
alter table public.perfiles_kombax_directos add column if not exists social_activo boolean not null default false;
alter table public.perfiles_kombax_directos add column if not exists social_activado_en timestamptz;
alter table public.perfiles_kombax_directos add column if not exists social_normas_version text;

create table if not exists public.kombax_aceptaciones_globales(
  id uuid primary key default gen_random_uuid(),perfil_id uuid not null references public.perfiles(id),perfil_directo_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
  tipo text not null check(tipo in ('social_normas','social_privacidad')),version text not null,aceptado boolean not null default true,user_agent text,aceptado_en timestamptz not null default now(),revocado_en timestamptz,
  unique(perfil_directo_id,tipo,version)
);
alter table public.kombax_aceptaciones_globales enable row level security;revoke all on table public.kombax_aceptaciones_globales from public,anon,authenticated;

create or replace function public.app_kombax_social_puede_publicar_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.publicar_habilitado and (
      (sp.sujeto_tipo='miembro' and exists(select 1 from public.identidades_sociales i where i.id=sp.identidad_social_id and i.perfil_id=auth.uid() and i.estado='activa') and public.app_kombax_capacidad_club_v041((select i.club_origen_id from public.identidades_sociales i where i.id=sp.identidad_social_id),'social.publish'))
      or (sp.sujeto_tipo='club' and public.app_kombax_capacidad_club_v041(sp.club_id,'social.publish') and exists(select 1 from public.miembros_club m where m.club_id=sp.club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))))
      or (sp.sujeto_tipo='perfil_directo' and exists(select 1 from public.perfiles_kombax_directos d join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='social.publish' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()) where d.id=sp.perfil_directo_id and d.perfil_id=auth.uid() and d.estado='activo' and d.verificacion_estado='verificado' and d.social_activo and d.tipo in ('marca','federacion')))
    )
  );
$$;
revoke all on function public.app_kombax_social_puede_publicar_v041(uuid) from public,anon;grant execute on function public.app_kombax_social_puede_publicar_v041(uuid) to authenticated;

create or replace function public.app_kombax_social_contactable_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(select 1 from public.kombax_social_perfiles sp where sp.id=p_social_id and sp.visible and sp.estado='activo' and (
    (sp.sujeto_tipo='club' and sp.contacto_habilitado)
    or (sp.sujeto_tipo='perfil_directo' and sp.contacto_habilitado and exists(select 1 from public.perfiles_kombax_directos d where d.id=sp.perfil_directo_id and d.estado='activo' and d.verificacion_estado='verificado' and d.social_activo and d.tipo in ('marca','federacion')))
    or exists(select 1 from public.identidades_sociales i join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id where i.id=sp.identidad_social_id and i.estado='activa' and s.estado='activo' and s.fecha_nacimiento is not null and extract(year from age(current_date,s.fecha_nacimiento))>=18)
  ));
$$;
revoke all on function public.app_kombax_social_contactable_v041(uuid) from public,anon;grant execute on function public.app_kombax_social_contactable_v041(uuid) to authenticated;

create or replace function public.app_kombax_social_estado_v049(p_club_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_d public.perfiles_kombax_directos;v_sp public.kombax_social_perfiles;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_club_id is not null and public.es_miembro_club(p_club_id) then return public.app_kombax_social_estado_v041(p_club_id);end if;
  select d.* into v_d from public.perfiles_kombax_directos d where d.perfil_id=auth.uid() and d.estado='activo' and d.verificacion_estado='verificado'
  order by d.social_activo desc,case when d.tipo in ('marca','federacion') then 0 else 1 end,d.actualizado_en desc limit 1;
  if v_d.id is null then return jsonb_build_object('status','inactiva','eligible',false,'reason','Necesitas un perfil KOMBAX verificado para activar Social.','scope','global');end if;
  select * into v_sp from public.kombax_social_perfiles where perfil_directo_id=v_d.id;
  if v_d.tipo in ('competidor','profesional') then
    return jsonb_build_object('status','inactiva','eligible',false,'reason','Los perfiles personales Competidor/Profesional requieren edad verificada por un club antes de activar KOMBAX Social. Usa la identidad afiliada al club cuando corresponda.','scope','global','direct_profile_id',v_d.id,'social_profile_id',v_sp.id,'contact_enabled',false,'rules_version','1.1.0','age_gate','club_verified_required');
  end if;
  return jsonb_build_object('status',case when v_d.social_activo then 'activa' else 'inactiva' end,'eligible',true,'reason',case when v_d.social_activo then 'KOMBAX Social activo para tu perfil verificado.' else 'La activación de Social es voluntaria y separada de la verificación.' end,'scope','global','direct_profile_id',v_d.id,'social_profile_id',v_sp.id,'contact_enabled',public.app_kombax_social_contactable_v041(v_sp.id),'rules_version','1.1.0');
end $$;
revoke all on function public.app_kombax_social_estado_v049(uuid) from public,anon;grant execute on function public.app_kombax_social_estado_v049(uuid) to authenticated;

create or replace function public.app_kombax_social_mutate_v049(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_actor uuid;v_target uuid;v_post public.kombax_social_publicaciones;v_contact public.kombax_social_contactos;v_report public.kombax_social_reportes;v_active boolean;v_status text;v_reason text;v_type text;v_text text;v_direct uuid;v_sp uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  if p_operation='kombax.social.activar' then return public.app_kombax_social_mutate_v041(p_operation,p_payload,p_request_id);end if;
  if p_operation in ('kombax.social.publicar','kombax.social.guardar','kombax.social.comentar','kombax.social.comentario.eliminar') then return public.app_kombax_social_mutate_v044(p_operation,p_payload,p_request_id);end if;
  if not public.app_kombax_social_acceso_v041() and p_operation not in ('kombax.social.direct.activate') then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);end if;

  if p_operation='kombax.social.direct.activate' then
    begin v_direct:=(v_payload->>'perfil_directo_id')::uuid;exception when others then raise exception 'KOMBAX_DIRECT_PROFILE_INVALID';end;
    if not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_direct and d.perfil_id=v_uid and d.estado='activo' and d.verificacion_estado='verificado') then raise exception 'KOMBAX_DIRECT_PROFILE_VERIFIED_REQUIRED';end if;
    if exists(select 1 from public.perfiles_kombax_directos d where d.id=v_direct and d.tipo in ('competidor','profesional')) then raise exception 'KOMBAX_SOCIAL_CLUB_VERIFIED_AGE_REQUIRED';end if;
    if coalesce((v_payload->>'acepta_normas')::boolean,false) is not true or coalesce((v_payload->>'acepta_privacidad')::boolean,false) is not true then raise exception 'KOMBAX_SOCIAL_CONSENT_REQUIRED';end if;
    update public.perfiles_kombax_directos set social_activo=true,social_activado_en=now(),social_normas_version='1.1.0',actualizado_en=now() where id=v_direct;
    insert into public.kombax_aceptaciones_globales(perfil_id,perfil_directo_id,tipo,version,aceptado,user_agent) values
      (v_uid,v_direct,'social_normas','1.1.0',true,left(coalesce(v_payload->>'user_agent',''),500)),(v_uid,v_direct,'social_privacidad','1.1.0',true,left(coalesce(v_payload->>'user_agent',''),500))
      on conflict(perfil_directo_id,tipo,version) do update set aceptado=true,aceptado_en=now(),revocado_en=null,user_agent=excluded.user_agent;
    select id into v_sp from public.kombax_social_perfiles where perfil_directo_id=v_direct;v_result:=jsonb_build_object('perfil_directo_id',v_direct,'social_profile_id',v_sp,'status','activa');
  elsif p_operation='kombax.social.retirar' then
    begin v_target:=(v_payload->>'publicacion_id')::uuid;exception when others then raise exception 'KOMBAX_POST_ID_INVALID';end;select * into v_post from public.kombax_social_publicaciones where id=v_target for update;
    if v_post.id is null or (not public.app_kombax_social_puede_publicar_v041(v_post.autor_perfil_id) and not public.app_kombax_es_moderador_v041()) then raise exception 'KOMBAX_POST_WITHDRAW_FORBIDDEN';end if;update public.kombax_social_publicaciones set estado='retirada',actualizado_en=now() where id=v_target returning * into v_post;v_result:=jsonb_build_object('id',v_post.id,'estado',v_post.estado);
  elsif p_operation='kombax.social.like' then
    begin v_target:=(v_payload->>'publicacion_id')::uuid;exception when others then raise exception 'KOMBAX_POST_ID_INVALID';end;if not exists(select 1 from public.kombax_social_publicaciones p join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id where p.id=v_target and p.estado='activa' and sp.visible and sp.estado='activo') then raise exception 'KOMBAX_POST_NOT_AVAILABLE';end if;
    v_active:=coalesce((v_payload->>'activo')::boolean,true);if v_active then insert into public.kombax_social_likes(publicacion_id,perfil_id) values(v_target,v_uid) on conflict do nothing;else delete from public.kombax_social_likes where publicacion_id=v_target and perfil_id=v_uid;end if;v_result:=jsonb_build_object('publicacion_id',v_target,'activo',v_active);
  elsif p_operation='kombax.social.bloquear' then
    begin v_target:=(v_payload->>'perfil_social_id')::uuid;exception when others then raise exception 'KOMBAX_SOCIAL_PROFILE_INVALID';end;if not exists(select 1 from public.kombax_social_perfiles where id=v_target and visible) then raise exception 'KOMBAX_SOCIAL_PROFILE_NOT_FOUND';end if;
    v_active:=coalesce((v_payload->>'bloquear')::boolean,true);if v_active then insert into public.kombax_social_bloqueos(bloqueador_perfil_id,bloqueado_social_id) values(v_uid,v_target) on conflict do nothing;else delete from public.kombax_social_bloqueos where bloqueador_perfil_id=v_uid and bloqueado_social_id=v_target;end if;v_result:=jsonb_build_object('perfil_social_id',v_target,'bloqueado',v_active);
  elsif p_operation='kombax.social.contactar' then
    begin v_actor:=(v_payload->>'remitente_social_id')::uuid;v_target:=(v_payload->>'destinatario_social_id')::uuid;exception when others then raise exception 'KOMBAX_CONTACT_PROFILES_INVALID';end;
    if not public.app_kombax_social_puede_publicar_v041(v_actor) then raise exception 'KOMBAX_CONTACT_SOURCE_FORBIDDEN';end if;if not public.app_kombax_social_contactable_v041(v_actor) or not public.app_kombax_social_contactable_v041(v_target) then raise exception 'KOMBAX_CONTACT_MINOR_OR_DISABLED';end if;if v_actor=v_target then raise exception 'KOMBAX_CONTACT_SELF_FORBIDDEN';end if;
    v_reason:=lower(coalesce(v_payload->>'motivo','otro'));if not public.app_kombax_contact_reason_allowed_v044(v_actor,v_target,v_reason) then raise exception 'KOMBAX_CONTACT_REASON_NOT_ALLOWED_FOR_RELATION';end if;v_text:=btrim(coalesce(v_payload->>'mensaje',''));if char_length(v_text)<10 or char_length(v_text)>500 then raise exception 'KOMBAX_CONTACT_MESSAGE_INVALID';end if;
    if exists(select 1 from public.kombax_social_contactos c where c.remitente_social_id=v_actor and c.destinatario_social_id=v_target and c.estado='pendiente') then raise exception 'KOMBAX_CONTACT_ALREADY_PENDING';end if;
    insert into public.kombax_social_contactos(remitente_social_id,destinatario_social_id,creado_por,motivo,mensaje) values(v_actor,v_target,v_uid,v_reason,v_text) returning * into v_contact;v_result:=jsonb_build_object('id',v_contact.id,'estado',v_contact.estado);
  elsif p_operation='kombax.social.contacto.estado' then
    begin v_target:=(v_payload->>'contacto_id')::uuid;exception when others then raise exception 'KOMBAX_CONTACT_ID_INVALID';end;select * into v_contact from public.kombax_social_contactos where id=v_target for update;
    if v_contact.id is null or not public.app_kombax_social_puede_publicar_v041(v_contact.destinatario_social_id) then raise exception 'KOMBAX_CONTACT_MANAGE_FORBIDDEN';end if;v_status:=lower(coalesce(v_payload->>'estado',''));if v_status not in ('aceptada','rechazada','cerrada') then raise exception 'KOMBAX_CONTACT_STATE_INVALID';end if;if v_contact.estado<>'pendiente' and v_status<>'cerrada' then raise exception 'KOMBAX_CONTACT_ALREADY_ANSWERED';end if;
    update public.kombax_social_contactos set estado=v_status,respondido_por=v_uid,respondido_en=now() where id=v_target returning * into v_contact;v_result:=jsonb_build_object('id',v_contact.id,'estado',v_contact.estado);
  elsif p_operation='kombax.social.denunciar' then
    v_type:=lower(coalesce(v_payload->>'objetivo_tipo',''));if v_type not in ('publicacion','perfil') then raise exception 'KOMBAX_REPORT_TARGET_TYPE_INVALID';end if;begin v_target:=(v_payload->>'objetivo_id')::uuid;exception when others then raise exception 'KOMBAX_REPORT_TARGET_INVALID';end;
    if v_type='publicacion' and not exists(select 1 from public.kombax_social_publicaciones where id=v_target) then raise exception 'KOMBAX_POST_NOT_FOUND';end if;if v_type='perfil' and not exists(select 1 from public.kombax_social_perfiles where id=v_target) then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;
    v_reason:=lower(coalesce(v_payload->>'motivo','otro'));if v_reason not in ('acoso','odio_discriminacion','violencia','sexual_menores','privacidad','spam','suplantacion','otro') then raise exception 'KOMBAX_REPORT_REASON_INVALID';end if;
    insert into public.kombax_social_reportes(reportado_por,objetivo_tipo,objetivo_id,motivo,detalle) values(v_uid,v_type,v_target,v_reason,left(nullif(btrim(v_payload->>'detalle'),''),1500)) on conflict(reportado_por,objetivo_tipo,objetivo_id) where estado in ('pendiente','en_revision') do update set motivo=excluded.motivo,detalle=excluded.detalle,creado_en=now() returning * into v_report;v_result:=jsonb_build_object('id',v_report.id,'estado',v_report.estado);
  elsif p_operation='kombax.social.moderar' then
    if not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;begin v_target:=(v_payload->>'reporte_id')::uuid;exception when others then raise exception 'KOMBAX_REPORT_ID_INVALID';end;v_status:=lower(coalesce(v_payload->>'estado',''));if v_status not in ('en_revision','resuelta','descartada') then raise exception 'KOMBAX_REPORT_STATE_INVALID';end if;v_reason:=left(nullif(btrim(v_payload->>'resolucion'),''),1500);
    update public.kombax_social_reportes set estado=v_status,revisado_por=v_uid,resolucion=v_reason,revisado_en=now() where id=v_target returning * into v_report;if v_report.id is null then raise exception 'KOMBAX_REPORT_NOT_FOUND';end if;if v_status='resuelta' and coalesce((v_payload->>'ocultar')::boolean,false) and v_report.objetivo_tipo='publicacion' then update public.kombax_social_publicaciones set estado='oculta',moderada_por=v_uid,moderacion_motivo=coalesce(v_reason,'Ocultada por moderación'),actualizado_en=now() where id=v_report.objetivo_id;end if;insert into public.kombax_social_moderacion(moderador_id,objetivo_tipo,objetivo_id,accion,motivo) values(v_uid,'reporte',v_report.id,case when v_status='descartada' then 'descartar' else 'resolver' end,coalesce(v_reason,'Revisión de denuncia'));v_result:=jsonb_build_object('id',v_report.id,'estado',v_report.estado);
  else raise exception 'KOMBAX_SOCIAL_OPERATION_NOT_ALLOWED';end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_social_mutate_v049(text,jsonb,uuid) from public,anon;grant execute on function public.app_kombax_social_mutate_v049(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
