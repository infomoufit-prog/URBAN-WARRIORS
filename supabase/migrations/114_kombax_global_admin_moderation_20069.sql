-- KOMBAX RC13 build 20069 · Administración global temporal + Moderación estructurada.
-- Extiende v110; no restaura OTP, no crea membresías y no suplanta identidades.
begin;

create table if not exists public.kombax_platform_entity_sessions(
  id uuid primary key default gen_random_uuid(),
  platform_session_id uuid not null references public.kombax_platform_admin_sessions(id) on delete cascade,
  actor_perfil_id uuid not null references public.perfiles(id) on delete restrict,
  auth_session_id text not null,
  entidad_tipo text not null check(entidad_tipo ~ '^[a-z][a-z0-9_]{1,39}$'),
  entidad_id uuid not null,
  motivo text not null check(char_length(btrim(motivo)) between 10 and 500),
  creado_en timestamptz not null default now(),
  expira_en timestamptz not null default (now()+interval '15 minutes'),
  ultima_actividad_en timestamptz not null default now(),
  terminado_en timestamptz,
  constraint kombax_platform_entity_session_window check(expira_en>creado_en)
);
create unique index if not exists uq_kombax_entity_session_active_v114
  on public.kombax_platform_entity_sessions(actor_perfil_id,auth_session_id)
  where terminado_en is null;
create index if not exists idx_kombax_entity_session_target_v114
  on public.kombax_platform_entity_sessions(entidad_tipo,entidad_id,creado_en desc);

create table if not exists public.kombax_platform_privileged_audit(
  id bigint generated always as identity primary key,
  actor_perfil_id uuid not null references public.perfiles(id) on delete restrict,
  auth_session_id text not null,
  platform_session_id uuid references public.kombax_platform_admin_sessions(id) on delete set null,
  entity_session_id uuid references public.kombax_platform_entity_sessions(id) on delete set null,
  entidad_tipo text not null,
  entidad_id uuid not null,
  accion text not null check(accion ~ '^[a-z][a-z0-9_.]{2,119}$'),
  resultado text not null check(resultado in ('success','denied','error')),
  motivo text,
  detalle jsonb not null default '{}'::jsonb,
  creado_en timestamptz not null default now()
);
create index if not exists idx_kombax_privileged_audit_target_v114
  on public.kombax_platform_privileged_audit(entidad_tipo,entidad_id,creado_en desc);
create index if not exists idx_kombax_privileged_audit_actor_v114
  on public.kombax_platform_privileged_audit(actor_perfil_id,creado_en desc);

create table if not exists public.kombax_moderation_decisions_v114(
  id uuid primary key default gen_random_uuid(),
  reporte_id uuid references public.kombax_social_reportes(id) on delete set null,
  moderador_id uuid not null references public.perfiles(id) on delete restrict,
  objetivo_tipo text not null check(objetivo_tipo in ('publicacion','comentario','perfil','reporte')),
  objetivo_id uuid not null,
  decision_state text not null check(decision_state in ('allowed','review','hidden','warning','suspended','escalated')),
  accion text not null check(accion in ('review','hide','restore','warn','limit','suspend','escalate','resolve')),
  confidence numeric(4,3) check(confidence is null or confidence between 0 and 1),
  reason_code text not null check(reason_code ~ '^[a-z][a-z0-9_]{2,79}$'),
  reason_text text not null check(char_length(btrim(reason_text)) between 3 and 1500),
  evidence jsonb not null default '{}'::jsonb,
  actor_kind text not null default 'human' check(actor_kind in ('human','ai_proposal','ai_controlled')),
  creado_en timestamptz not null default now()
);
create index if not exists idx_kombax_moderation_decisions_report_v114
  on public.kombax_moderation_decisions_v114(reporte_id,creado_en desc);
create index if not exists idx_kombax_moderation_decisions_target_v114
  on public.kombax_moderation_decisions_v114(objetivo_tipo,objetivo_id,creado_en desc);

alter table public.kombax_platform_entity_sessions enable row level security;
alter table public.kombax_platform_privileged_audit enable row level security;
alter table public.kombax_moderation_decisions_v114 enable row level security;
revoke all on public.kombax_platform_entity_sessions,public.kombax_platform_privileged_audit,public.kombax_moderation_decisions_v114 from public,anon,authenticated;

create or replace function public.app_kombax_platform_active_session_v114()
returns uuid language sql stable security definer set search_path=public,auth as $$
  select s.id from public.kombax_platform_admin_sessions s
  where s.perfil_id=auth.uid() and s.auth_session_id=nullif(auth.jwt()->>'session_id','')
    and s.terminado_en is null and s.expira_en>now()
  order by s.creado_en desc limit 1;
$$;
revoke all on function public.app_kombax_platform_active_session_v114() from public,anon,authenticated;
grant execute on function public.app_kombax_platform_active_session_v114() to service_role;

create or replace function public.app_kombax_platform_entity_exists_v114(p_tipo text,p_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select case
    when p_tipo='club' then exists(select 1 from public.clubes where id=p_id)
    when p_tipo='cuenta' then exists(select 1 from public.perfiles where id=p_id)
    when p_tipo in ('perfil_directo','competidor','marca','federacion','profesional','espectador') then
      exists(select 1 from public.perfiles_kombax_directos d where d.id=p_id and (p_tipo='perfil_directo' or d.tipo=p_tipo))
    else false end;
$$;
revoke all on function public.app_kombax_platform_entity_exists_v114(text,uuid) from public,anon,authenticated;
grant execute on function public.app_kombax_platform_entity_exists_v114(text,uuid) to service_role;

create or replace function public.app_kombax_platform_entities_v114(p_query text default '',p_limit integer default 100)
returns table(id uuid,entidad_tipo text,nombre text,estado text,referencia text,actualizado_en timestamptz)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_q text:=lower(btrim(coalesce(p_query,'')));
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  return query
  select x.id,x.entidad_tipo,x.nombre,x.estado,x.referencia,x.actualizado_en from (
    select c.id as id,'club'::text as entidad_tipo,c.nombre as nombre,c.activo::text as estado,c.slug as referencia,c.actualizado_en as actualizado_en from public.clubes c
    union all
    select d.id,d.tipo,d.nombre_publico,d.estado,d.slug,d.actualizado_en from public.perfiles_kombax_directos d
    union all
    select p.id,'cuenta',coalesce(nullif(btrim(concat_ws(' ',p.nombre,p.apellidos)),''),u.email,'Cuenta KOMBAX'),
      case when u.banned_until is not null and u.banned_until>now() then 'suspendida' else 'activa' end,
      coalesce(u.email,p.id::text),p.actualizado_en
    from public.perfiles p join auth.users u on u.id=p.id
  ) x
  where v_q='' or lower(coalesce(x.nombre,'')||' '||coalesce(x.referencia,'')||' '||x.entidad_tipo) like '%'||v_q||'%'
  order by x.actualizado_en desc
  limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_platform_entities_v114(text,integer) from public,anon;
grant execute on function public.app_kombax_platform_entities_v114(text,integer) to authenticated;

create or replace function public.app_kombax_platform_entity_session_start_v114(p_entidad_tipo text,p_entidad_id uuid,p_motivo text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_auth text:=nullif(auth.jwt()->>'session_id','');v_platform uuid;v_id uuid;v_exp timestamptz;v_tipo text:=lower(btrim(coalesce(p_entidad_tipo,'')));v_reason text:=btrim(coalesce(p_motivo,''));
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  v_platform:=public.app_kombax_platform_active_session_v114();
  if v_platform is null then raise exception 'PLATFORM_ADMIN_SESSION_REQUIRED';end if;
  if char_length(v_reason)<10 then raise exception 'PLATFORM_ADMIN_REASON_REQUIRED';end if;
  if not public.app_kombax_platform_entity_exists_v114(v_tipo,p_entidad_id) then raise exception 'PLATFORM_ENTITY_NOT_FOUND';end if;
  update public.kombax_platform_entity_sessions set terminado_en=coalesce(terminado_en,now())
    where actor_perfil_id=v_uid and auth_session_id=v_auth and terminado_en is null;
  insert into public.kombax_platform_entity_sessions(platform_session_id,actor_perfil_id,auth_session_id,entidad_tipo,entidad_id,motivo)
    values(v_platform,v_uid,v_auth,v_tipo,p_entidad_id,v_reason) returning id,expira_en into v_id,v_exp;
  insert into public.kombax_platform_privileged_audit(actor_perfil_id,auth_session_id,platform_session_id,entity_session_id,entidad_tipo,entidad_id,accion,resultado,motivo)
    values(v_uid,v_auth,v_platform,v_id,v_tipo,p_entidad_id,'admin.entity_session.start','success',v_reason);
  return jsonb_build_object('authorized',true,'entity_session_id',v_id,'entidad_tipo',v_tipo,'entidad_id',p_entidad_id,'expires_at',v_exp,'motivo',v_reason);
end $$;
revoke all on function public.app_kombax_platform_entity_session_start_v114(text,uuid,text) from public,anon;
grant execute on function public.app_kombax_platform_entity_session_start_v114(text,uuid,text) to authenticated;

create or replace function public.app_kombax_platform_entity_session_context_v114()
returns jsonb language sql stable security definer set search_path=public,auth as $$
  select coalesce((select jsonb_build_object('authorized',true,'entity_session_id',e.id,'entidad_tipo',e.entidad_tipo,'entidad_id',e.entidad_id,'motivo',e.motivo,'expires_at',least(e.expira_en,s.expira_en))
    from public.kombax_platform_entity_sessions e join public.kombax_platform_admin_sessions s on s.id=e.platform_session_id
    where e.actor_perfil_id=auth.uid() and e.auth_session_id=nullif(auth.jwt()->>'session_id','') and e.terminado_en is null
      and e.expira_en>now() and s.terminado_en is null and s.expira_en>now()
    order by e.creado_en desc limit 1),jsonb_build_object('authorized',false));
$$;
revoke all on function public.app_kombax_platform_entity_session_context_v114() from public,anon;
grant execute on function public.app_kombax_platform_entity_session_context_v114() to authenticated;

create or replace function public.app_kombax_platform_entity_detail_v114(p_entity_session_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare e public.kombax_platform_entity_sessions;v jsonb;v_auth text:=nullif(auth.jwt()->>'session_id','');
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  select x.* into e from public.kombax_platform_entity_sessions x join public.kombax_platform_admin_sessions s on s.id=x.platform_session_id
    where x.id=p_entity_session_id and x.actor_perfil_id=auth.uid() and x.auth_session_id=v_auth and x.terminado_en is null
      and x.expira_en>now() and s.terminado_en is null and s.expira_en>now();
  if e.id is null then raise exception 'PLATFORM_ENTITY_SESSION_REQUIRED';end if;
  if e.entidad_tipo='club' then
    select jsonb_build_object('entity',to_jsonb(c),'counts',jsonb_build_object(
      'members',(select count(*) from public.miembros_club m where m.club_id=c.id and m.activo),
      'groups',(select count(*) from public.grupos g where g.club_id=c.id),
      'documents',(select count(*) from public.documentos_socios d where d.club_id=c.id),
      'charges',(select count(*) from public.cuotas q where q.club_id=c.id),
      'receipts',(select count(*) from public.recibos_cuota r where r.club_id=c.id),
      'posts',(select count(*) from public.publicaciones_comunidad p where p.club_id=c.id),
      'team',(select count(*) from public.miembros_club m where m.club_id=c.id and m.activo and m.rol<>'alumno')),
      'capabilities',jsonb_build_array('perfil','equipo','miembros','grupos','documentos','finanzas','cuotas','cobros','recibos','configuracion','publicaciones','social','showcase','incidencias','mantenimiento'))
      into v from public.clubes c where c.id=e.entidad_id;
  elsif e.entidad_tipo='cuenta' then
    select jsonb_build_object('entity',jsonb_build_object('id',p.id,'nombre',p.nombre,'apellidos',p.apellidos,'telefono',p.telefono,'email',u.email,'created_at',u.created_at,'last_sign_in_at',u.last_sign_in_at,'banned_until',u.banned_until),
      'memberships',coalesce((select jsonb_agg(jsonb_build_object('club_id',m.club_id,'club',c.nombre,'rol',m.rol,'activo',m.activo)) from public.miembros_club m join public.clubes c on c.id=m.club_id where m.perfil_id=p.id),'[]'::jsonb),
      'direct_profiles',coalesce((select jsonb_agg(to_jsonb(d)-'perfil_id') from public.perfiles_kombax_directos d where d.perfil_id=p.id),'[]'::jsonb),
      'capabilities',jsonb_build_array('perfil','estado_cuenta','membresias','verificaciones','permisos','incidencias')) into v
    from public.perfiles p join auth.users u on u.id=p.id where p.id=e.entidad_id;
  else
    select jsonb_build_object('entity',to_jsonb(d),'owner',jsonb_build_object('perfil_id',p.id,'nombre',p.nombre,'apellidos',p.apellidos,'email',u.email),
      'service',public.app_kombax_perfil_servicio_v071(d.id),
      'social_profile',(select to_jsonb(sp) from public.kombax_social_perfiles sp where sp.perfil_directo_id=d.id),
      'showcase_provider',(select to_jsonb(sh) from public.kombax_showcase_marcas sh where sh.perfil_directo_id=d.id),
      'managers',coalesce((select jsonb_agg(to_jsonb(g)) from public.kombax_perfil_gestores g where g.perfil_directo_id=d.id),'[]'::jsonb),
      'capabilities',jsonb_build_array('perfil','datos_privados','verificacion','servicio','permisos','equipo','publicaciones','social','showcase','mensajes','incidencias','suspension')) into v
    from public.perfiles_kombax_directos d join public.perfiles p on p.id=d.perfil_id join auth.users u on u.id=p.id where d.id=e.entidad_id;
  end if;
  return jsonb_build_object('mode','MODO ADMINISTRADOR KOMBAX','context',to_jsonb(e)-'auth_session_id','data',coalesce(v,'{}'::jsonb));
end $$;
revoke all on function public.app_kombax_platform_entity_detail_v114(uuid) from public,anon;
grant execute on function public.app_kombax_platform_entity_detail_v114(uuid) to authenticated;

create or replace function public.app_kombax_platform_entity_session_end_v114()
returns boolean language plpgsql security definer set search_path=public,auth as $$
declare e public.kombax_platform_entity_sessions;v_auth text:=nullif(auth.jwt()->>'session_id','');
begin
  select * into e from public.kombax_platform_entity_sessions where actor_perfil_id=auth.uid() and auth_session_id=v_auth and terminado_en is null order by creado_en desc limit 1 for update;
  if e.id is null then return false;end if;
  update public.kombax_platform_entity_sessions set terminado_en=now() where id=e.id;
  insert into public.kombax_platform_privileged_audit(actor_perfil_id,auth_session_id,platform_session_id,entity_session_id,entidad_tipo,entidad_id,accion,resultado,motivo)
    values(auth.uid(),v_auth,e.platform_session_id,e.id,e.entidad_tipo,e.entidad_id,'admin.entity_session.end','success',e.motivo);
  return true;
end $$;
revoke all on function public.app_kombax_platform_entity_session_end_v114() from public,anon;
grant execute on function public.app_kombax_platform_entity_session_end_v114() to authenticated;

create or replace function public.app_kombax_platform_entity_mutate_v114(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare e public.kombax_platform_entity_sessions;v_auth text:=nullif(auth.jwt()->>'session_id','');v_result jsonb;v_state text;v_active boolean;v_reason text:=btrim(coalesce(p_payload->>'motivo',''));
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  select * into e from public.kombax_platform_entity_sessions where id=nullif(p_payload->>'entity_session_id','')::uuid and actor_perfil_id=auth.uid() and auth_session_id=v_auth and terminado_en is null and expira_en>now() for update;
  if e.id is null then raise exception 'PLATFORM_ENTITY_SESSION_REQUIRED';end if;
  if char_length(v_reason)<10 then raise exception 'PLATFORM_ADMIN_REASON_REQUIRED';end if;
  if p_operation='kombax.admin.entity.status.set' and e.entidad_tipo='club' then
    v_active:=coalesce((p_payload->>'activo')::boolean,false);update public.clubes set activo=v_active,actualizado_en=now() where id=e.entidad_id;v_result:=jsonb_build_object('activo',v_active);
  elsif p_operation='kombax.admin.entity.moderation.set' and e.entidad_tipo in ('perfil_directo','competidor','marca','federacion','profesional','espectador') then
    v_state:=lower(coalesce(p_payload->>'estado',''));if v_state not in ('normal','limited','suspended') then raise exception 'PLATFORM_ENTITY_STATE_INVALID';end if;
    update public.perfiles_kombax_directos set moderacion_estado=v_state,actualizado_en=now() where id=e.entidad_id;
    update public.kombax_social_perfiles set estado=case v_state when 'normal' then 'activo' when 'limited' then 'limitado' else 'suspendido' end,visible=(v_state<>'suspended'),publicar_habilitado=(v_state='normal'),contacto_habilitado=(v_state='normal'),actualizado_en=now() where perfil_directo_id=e.entidad_id;
    v_result:=jsonb_build_object('moderacion_estado',v_state);
  else raise exception 'PLATFORM_ENTITY_OPERATION_NOT_ALLOWED';end if;
  update public.kombax_platform_entity_sessions set ultima_actividad_en=now() where id=e.id;
  insert into public.kombax_platform_privileged_audit(actor_perfil_id,auth_session_id,platform_session_id,entity_session_id,entidad_tipo,entidad_id,accion,resultado,motivo,detalle)
    values(auth.uid(),v_auth,e.platform_session_id,e.id,e.entidad_tipo,e.entidad_id,p_operation,'success',v_reason,v_result);
  return jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',v_result);
end $$;
revoke all on function public.app_kombax_platform_entity_mutate_v114(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_platform_entity_mutate_v114(text,jsonb,uuid) to authenticated;

create or replace function public.app_kombax_moderation_queue_v114(p_limit integer default 100)
returns table(id uuid,objetivo_tipo text,objetivo_id uuid,motivo text,detalle text,estado text,creado_en timestamptz,objetivo_resumen text,autor_objetivo text,last_decision text,last_confidence numeric)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;
  return query select q.id,q.objetivo_tipo,q.objetivo_id,q.motivo,q.detalle,q.estado,q.creado_en,q.objetivo_resumen,q.autor_objetivo,d.decision_state,d.confidence
  from public.app_kombax_moderation_queue_v050(p_limit) q
  left join lateral(select x.decision_state,x.confidence from public.kombax_moderation_decisions_v114 x where x.reporte_id=q.id order by x.creado_en desc limit 1)d on true;
end $$;
revoke all on function public.app_kombax_moderation_queue_v114(integer) from public,anon;
grant execute on function public.app_kombax_moderation_queue_v114(integer) to authenticated;

create or replace function public.app_kombax_moderation_decide_v114(p_reporte_id uuid,p_decision_state text,p_reason_code text,p_reason_text text,p_confidence numeric default null,p_evidence jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare r public.kombax_social_reportes;v_state text:=lower(coalesce(p_decision_state,''));v_action text;v_reason text:=btrim(coalesce(p_reason_text,''));v_code text:=lower(btrim(coalesce(p_reason_code,'')));v_id uuid;
begin
  if not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;
  if v_state not in ('allowed','review','hidden','warning','suspended','escalated') then raise exception 'KOMBAX_MODERATION_DECISION_INVALID';end if;
  if char_length(v_reason)<3 or v_code!~'^[a-z][a-z0-9_]{2,79}$' then raise exception 'KOMBAX_MODERATION_REASON_REQUIRED';end if;
  if p_confidence is not null and (p_confidence<0 or p_confidence>1) then raise exception 'KOMBAX_MODERATION_CONFIDENCE_INVALID';end if;
  select * into r from public.kombax_social_reportes where id=p_reporte_id for update;if r.id is null then raise exception 'KOMBAX_REPORT_NOT_FOUND';end if;
  v_action:=case v_state when 'allowed' then 'restore' when 'review' then 'review' when 'hidden' then 'hide' when 'warning' then 'warn' when 'suspended' then 'suspend' else 'escalate' end;
  if v_state='hidden' then
    if r.objetivo_tipo='publicacion' then update public.kombax_social_publicaciones set estado='oculta',moderada_por=auth.uid(),moderacion_motivo=v_reason,actualizado_en=now() where id=r.objetivo_id;
    elsif r.objetivo_tipo='comentario' then update public.kombax_social_comentarios set estado='hidden',moderado_por=auth.uid(),moderacion_motivo=v_reason,actualizado_en=now() where id=r.objetivo_id;
    else raise exception 'KOMBAX_MODERATION_ACTION_TARGET_MISMATCH';end if;
  elsif v_state='allowed' then
    if r.objetivo_tipo='publicacion' then update public.kombax_social_publicaciones set estado='activa',moderada_por=auth.uid(),moderacion_motivo=v_reason,actualizado_en=now() where id=r.objetivo_id;
    elsif r.objetivo_tipo='comentario' then update public.kombax_social_comentarios set estado='active',moderado_por=auth.uid(),moderacion_motivo=v_reason,actualizado_en=now() where id=r.objetivo_id;end if;
  elsif v_state='suspended' then
    if r.objetivo_tipo<>'perfil' then raise exception 'KOMBAX_MODERATION_ACTION_TARGET_MISMATCH';end if;
    update public.kombax_social_perfiles set estado='suspendido',visible=false,publicar_habilitado=false,contacto_habilitado=false,actualizado_en=now() where id=r.objetivo_id;
  end if;
  update public.kombax_social_reportes set estado=case when v_state in ('review','escalated') then 'en_revision' else 'resuelta' end,revisado_por=auth.uid(),resolucion=v_reason,revisado_en=now() where id=r.id;
  insert into public.kombax_moderation_decisions_v114(reporte_id,moderador_id,objetivo_tipo,objetivo_id,decision_state,accion,confidence,reason_code,reason_text,evidence)
    values(r.id,auth.uid(),r.objetivo_tipo,r.objetivo_id,v_state,v_action,p_confidence,v_code,v_reason,coalesce(p_evidence,'{}'::jsonb)) returning id into v_id;
  return jsonb_build_object('ok',true,'decision_id',v_id,'report_id',r.id,'decision_state',v_state,'action',v_action,'audited',true);
end $$;
revoke all on function public.app_kombax_moderation_decide_v114(uuid,text,text,text,numeric,jsonb) from public,anon;
grant execute on function public.app_kombax_moderation_decide_v114(uuid,text,text,text,numeric,jsonb) to authenticated;

-- El cierre Owner invalida inmediatamente cualquier contexto de entidad.
create or replace function public.app_kombax_platform_admin_session_end_v108()
returns boolean language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_session_id text:=nullif(auth.jwt()->>'session_id','');
begin
  if v_uid is null then return false;end if;
  update public.kombax_platform_entity_sessions set terminado_en=coalesce(terminado_en,now()) where actor_perfil_id=v_uid and auth_session_id=v_session_id and terminado_en is null;
  update public.kombax_platform_admin_sessions set terminado_en=coalesce(terminado_en,now()) where perfil_id=v_uid and auth_session_id=v_session_id and terminado_en is null;
  return true;
end $$;
revoke all on function public.app_kombax_platform_admin_session_end_v108() from public,anon;
grant execute on function public.app_kombax_platform_admin_session_end_v108() to authenticated;

notify pgrst,'reload schema';
commit;
