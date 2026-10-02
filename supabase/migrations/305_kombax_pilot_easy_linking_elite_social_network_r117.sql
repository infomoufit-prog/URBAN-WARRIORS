-- KOMBAX R117 Pilot Hotfix · easy account/club linking + Elite Social network continuity
-- Applied live in pilot as backend hotfixes r117_13/r117_14.

alter table public.kombax_club_interest_threads_r58
  add column if not exists request_kind text not null default 'member',
  add column if not exists target_socio_id uuid null references public.socios(id) on delete set null,
  add column if not exists resolved_by uuid null references public.perfiles(id) on delete set null,
  add column if not exists resolved_at timestamptz null,
  add column if not exists resolution text null;

do $$ begin
  if not exists(select 1 from pg_constraint where conrelid='public.kombax_club_interest_threads_r58'::regclass and conname='kombax_club_interest_threads_r117_request_kind_check') then
    alter table public.kombax_club_interest_threads_r58 add constraint kombax_club_interest_threads_r117_request_kind_check check(request_kind in ('member','family'));
  end if;
end $$;

create table if not exists public.kombax_member_private_r117(
  perfil_id uuid primary key references public.perfiles(id) on delete cascade,
  fecha_nacimiento date null,
  age_gate_version text not null default 'r117',
  actualizado_en timestamptz not null default now()
);
alter table public.kombax_member_private_r117 enable row level security;
revoke all on table public.kombax_member_private_r117 from public,anon,authenticated;

create or replace function public.app_kombax_social_network_actor_allowed_v255(p_social_id uuid)
returns boolean language sql stable security definer set search_path to 'public','auth' as $$
  select auth.uid() is not null and exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible=true and sp.estado='activo' and (
      public.app_kombax_social_puede_gestionar_perfil_publico_r117(sp.id)
      or (sp.sujeto_tipo='club' and sp.club_id is not null and public.app_kombax_club_permiso_v051(sp.club_id,'social.act_as_club'))
    )
  );
$$;
revoke all on function public.app_kombax_social_network_actor_allowed_v255(uuid) from public,anon;
grant execute on function public.app_kombax_social_network_actor_allowed_v255(uuid) to authenticated;

create or replace function public.app_kombax_my_social_actor_ids_v106()
returns table(social_id uuid) language sql stable security definer set search_path to 'public','auth' as $$
  with candidates as (
    select sp.id from public.kombax_social_perfiles sp join public.identidades_sociales i on i.id=sp.identidad_social_id
      where sp.sujeto_tipo='miembro' and i.perfil_id=auth.uid()
    union
    select sp.id from public.kombax_social_perfiles sp where sp.sujeto_tipo='club'
      and exists(select 1 from public.miembros_club mc where mc.club_id=sp.club_id and mc.perfil_id=auth.uid() and mc.activo)
    union
    select sp.id from public.kombax_social_perfiles sp join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
      where sp.sujeto_tipo='perfil_directo' and (d.perfil_id=auth.uid() or exists(select 1 from public.kombax_perfil_gestores g where g.perfil_directo_id=d.id and g.perfil_id=auth.uid() and g.estado='activo'))
  )
  select c.id from candidates c where public.app_kombax_social_network_actor_allowed_v255(c.id);
$$;

create or replace function public.app_kombax_social_contactable_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path to 'public','auth' as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and (
      sp.sujeto_tipo='club'
      or (sp.sujeto_tipo='miembro' and exists(
        select 1 from public.identidades_sociales i
        left join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
        left join public.kombax_member_private_r117 priv on priv.perfil_id=i.perfil_id
        where i.id=sp.identidad_social_id and i.estado='activa' and (
          (s.fecha_nacimiento is not null and extract(year from age(current_date,s.fecha_nacimiento))>=18)
          or (priv.fecha_nacimiento is not null and extract(year from age(current_date,priv.fecha_nacimiento))>=18)
        )
      ))
      or (sp.sujeto_tipo='perfil_directo' and exists(
        select 1 from public.perfiles_kombax_directos d
        left join public.kombax_perfil_persona_privada_v196 priv on priv.perfil_directo_id=d.id
        where d.id=sp.perfil_directo_id and d.estado not in ('suspendido','cerrado') and (
          (d.tipo='espectador' and priv.fecha_nacimiento is not null and public.app_kombax_profile_age_v196(priv.fecha_nacimiento)>=18)
          or (d.tipo in ('marca','federacion','media') and d.verificacion_estado='verificado' and d.social_activo)
          or (d.tipo='competidor' and d.verificacion_estado='verificado' and d.social_activo and d.fecha_nacimiento_verificada is not null and d.fecha_nacimiento_verificada<=current_date-interval '18 years')
          or (d.tipo='profesional' and d.verificacion_estado='verificado' and d.social_activo and priv.fecha_nacimiento is not null and public.app_kombax_profile_age_v196(priv.fecha_nacimiento)>=18)
        )
      ))
    )
  );
$$;

create or replace function public.app_kombax_social_sync_miembro_v041()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_comp uuid;v_socio public.socios;v_adulto boolean:=false;v_membership_confirmed boolean:=false;
begin
  select d.id into v_comp from public.perfiles_kombax_directos d where d.tipo='competidor' and d.origen_identidad_social_id=new.id order by d.creado_en limit 1;
  if v_comp is not null then perform public.app_kombax_social_switch_competitor_v072(v_comp); return new; end if;
  if new.socio_origen_id is not null then
    select * into v_socio from public.socios s where s.id=new.socio_origen_id and (new.club_origen_id is null or s.club_id=new.club_origen_id);
    v_adulto:=v_socio.fecha_nacimiento is not null and extract(year from age(current_date,v_socio.fecha_nacimiento))>=18;
  end if;
  if not v_adulto then
    select exists(select 1 from public.kombax_member_private_r117 p where p.perfil_id=new.perfil_id and p.fecha_nacimiento is not null and extract(year from age(current_date,p.fecha_nacimiento))>=18) into v_adulto;
  end if;
  select exists(
    select 1 from public.socios s join public.miembros_club mc on mc.club_id=s.club_id and mc.perfil_id=new.perfil_id and mc.rol='alumno' and mc.activo
    where s.perfil_id=new.perfil_id and s.estado='activo' and s.kombax_acceso_estado='activo'
      and (new.club_origen_id is null or s.club_id=new.club_origen_id) and (new.socio_origen_id is null or s.id=new.socio_origen_id)
  ) into v_membership_confirmed;
  insert into public.kombax_social_perfiles(sujeto_tipo,identidad_social_id,slug,nombre_publico,bio,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
  values('miembro',new.id,new.slug,new.nombre_publico,new.bio_publica,false,new.estado='activa',new.estado='activa' and v_membership_confirmed,new.estado='activa' and v_adulto,
    case new.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end)
  on conflict(identidad_social_id) where sujeto_tipo='miembro' do update set
    slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,verificado=false,visible=excluded.visible,
    publicar_habilitado=excluded.publicar_habilitado,contacto_habilitado=excluded.contacto_habilitado,estado=excluded.estado,actualizado_en=now();
  return new;
end $$;

create or replace function public.app_kombax_social_sync_directo_v041()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_verified boolean:=false;v_visible boolean:=false;v_social_ready boolean:=false;v_badge boolean:=false;v_adult boolean:=false;
begin
  if new.tipo='competidor' and new.origen_identidad_social_id is not null then perform public.app_kombax_social_switch_competitor_v072(new.id);return new;end if;
  if new.tipo='espectador' then
    select exists(select 1 from public.kombax_perfil_persona_privada_v196 p where p.perfil_directo_id=new.id and p.fecha_nacimiento is not null and public.app_kombax_profile_age_v196(p.fecha_nacimiento)>=18) into v_adult;
    insert into public.kombax_social_perfiles(sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
    values('perfil_directo',new.id,new.slug,new.nombre_publico,new.descripcion,new.avatar_path,new.banner_path,false,new.estado not in ('suspendido','cerrado'),false,v_adult,
      case when new.estado='suspendido' then 'suspendido' when new.estado='cerrado' then 'cerrado' else 'activo' end)
    on conflict(perfil_directo_id) where sujeto_tipo='perfil_directo' do update set
      slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,avatar_path=excluded.avatar_path,banner_path=excluded.banner_path,
      verificado=false,visible=excluded.visible,publicar_habilitado=false,contacto_habilitado=excluded.contacto_habilitado,estado=excluded.estado,actualizado_en=now();
    return new;
  end if;
  if new.tipo not in ('competidor','marca','federacion','profesional','media') then
    update public.kombax_social_perfiles set verificado=false,visible=false,publicar_habilitado=false,contacto_habilitado=false,estado='limitado',actualizado_en=now()
    where sujeto_tipo='perfil_directo' and perfil_directo_id=new.id;return new;
  end if;
  v_verified:=new.verificacion_estado='verificado' and new.workflow_estado in ('verified','limited') and new.estado='activo';
  v_visible:=coalesce(new.publico,false) and v_verified;v_social_ready:=v_visible and coalesce(new.social_activo,false);
  v_badge:=case when new.tipo='competidor' then v_verified when new.tipo in ('marca','federacion') then v_verified and public.app_kombax_subscription_paid_v102('perfil_directo',new.id) else false end;
  insert into public.kombax_social_perfiles(sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
  values('perfil_directo',new.id,new.slug,new.nombre_publico,new.descripcion,new.avatar_path,new.banner_path,v_badge,v_visible,v_social_ready,v_social_ready,
    case when new.estado='suspendido' then 'suspendido' when new.estado='cerrado' then 'cerrado' when v_visible then 'activo' else 'limitado' end)
  on conflict(perfil_directo_id) where sujeto_tipo='perfil_directo' do update set
    slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,avatar_path=excluded.avatar_path,banner_path=excluded.banner_path,
    verificado=excluded.verificado,visible=excluded.visible,publicar_habilitado=excluded.publicar_habilitado,contacto_habilitado=excluded.contacto_habilitado,estado=excluded.estado,actualizado_en=now();
  return new;
end $$;

-- Member public profile DOB is private and only drives age-gated features.
do $$ declare d text; begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_identity_mutate_v124' and p.prokind='f';
  if position('kombax_member_private_r117' in d)=0 then
    d:=replace(d,
      'if coalesce((p_payload->>''acepta_normas'')::boolean,false) is not true',
      'if nullif(p_payload->>''fecha_nacimiento'','''') is not null then'||chr(10)||
      '    begin insert into public.kombax_member_private_r117(perfil_id,fecha_nacimiento,age_gate_version,actualizado_en)'||chr(10)||
      '      values(v_uid,(p_payload->>''fecha_nacimiento'')::date,''r117'',now()) on conflict(perfil_id) do update set fecha_nacimiento=excluded.fecha_nacimiento,age_gate_version=''r117'',actualizado_en=now();'||chr(10)||
      '    exception when others then raise exception ''KOMBAX_PROFILE_BIRTH_DATE_INVALID''; end;'||chr(10)||
      '  end if;'||chr(10)||chr(10)||'  if coalesce((p_payload->>''acepta_normas'')::boolean,false) is not true');
    execute d;
  end if;
end $$;

-- Commenting/network/chat ownership no longer depends on feed-publish capability.
do $$ declare d text; begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='app_kombax_social_mutate_v044' and p.prokind='f';
  d:=replace(d,'if not public.app_kombax_social_puede_publicar_v041(v_actor) then raise exception ''KOMBAX_COMMENT_PROFILE_NOT_ALLOWED'';end if;','if not public.app_kombax_social_network_actor_allowed_v255(v_actor) then raise exception ''KOMBAX_COMMENT_PROFILE_NOT_ALLOWED'';end if;');
  d:=replace(d,'if not public.app_kombax_social_puede_publicar_v041(v_comment.autor_social_id) and not public.app_kombax_es_moderador_v041() then raise exception ''KOMBAX_COMMENT_DELETE_FORBIDDEN'';end if;','if not public.app_kombax_social_network_actor_allowed_v255(v_comment.autor_social_id) and not public.app_kombax_es_moderador_v041() then raise exception ''KOMBAX_COMMENT_DELETE_FORBIDDEN'';end if;');
  execute d;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='app_kombax_social_network_mutate_v104' and p.prokind='f';
  d:=replace(d,'if not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception ''KOMBAX_CONTACT_SOURCE_NOT_OWNED'';end if;','if not public.app_kombax_social_network_actor_allowed_v255(v_actor) then raise exception ''KOMBAX_CONTACT_SOURCE_NOT_OWNED'';end if;');
  d:=replace(d,'or not public.app_kombax_social_puede_actuar_v051(v_actor) then','or not public.app_kombax_social_network_actor_allowed_v255(v_actor) then');execute d;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='app_kombax_social_network_mutate_v107' and p.prokind='f';
  d:=replace(d,'if not public.app_kombax_social_puede_actuar_v051(v_actor) then','if not public.app_kombax_social_network_actor_allowed_v255(v_actor) then');execute d;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='app_kombax_contact_can_access_v067' and p.prokind='f';
  d:=replace(d,'public.app_kombax_social_puede_actuar_v051(c.remitente_social_id)','public.app_kombax_social_network_actor_allowed_v255(c.remitente_social_id)');
  d:=replace(d,'public.app_kombax_social_puede_actuar_v051(c.destinatario_social_id)','public.app_kombax_social_network_actor_allowed_v255(c.destinatario_social_id)');execute d;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='app_kombax_contact_mensajes_v104' and p.prokind='f';
  d:=replace(d,'public.app_kombax_social_puede_actuar_v051(m.autor_social_id)','public.app_kombax_social_network_actor_allowed_v255(m.autor_social_id)');
  d:=replace(d,'public.app_kombax_social_puede_actuar_v051(p.autor_social_id)','public.app_kombax_social_network_actor_allowed_v255(p.autor_social_id)');execute d;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='app_kombax_contactos_v104' and p.prokind='f';
  d:=replace(d,'if not public.app_kombax_social_acceso_v041() then'||chr(10)||'    raise exception ''SOCIAL_ACCESS_REQUIRED'';'||chr(10)||'  end if;','if auth.uid() is null then raise exception ''AUTH_REQUIRED''; end if;');
  d:=replace(d,'public.app_kombax_social_puede_actuar_v051(c.destinatario_social_id)','public.app_kombax_social_network_actor_allowed_v255(c.destinatario_social_id)');
  d:=replace(d,'public.app_kombax_social_puede_actuar_v051(c.remitente_social_id)','public.app_kombax_social_network_actor_allowed_v255(c.remitente_social_id)');
  d:=replace(d,'not public.app_kombax_social_puede_actuar_v051(um.autor_social_id)','not public.app_kombax_social_network_actor_allowed_v255(um.autor_social_id)');execute d;
end $$;

create or replace function public.app_kombax_club_link_request_r117(p_club_id uuid,p_request_kind text default 'member',p_mensaje text default null,p_target_socio_id uuid default null)
returns jsonb language plpgsql security definer set search_path to 'public','auth' as $$
declare v_uid uuid:=auth.uid();v_kind text:=lower(btrim(coalesce(p_request_kind,'member')));v_text text:=btrim(coalesce(p_mensaje,''));v_thread uuid;v_msg uuid;v_name text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if v_kind not in ('member','family') then raise exception 'KOMBAX_CLUB_LINK_REQUEST_KIND_INVALID';end if;
  if char_length(v_text)<2 or char_length(v_text)>1000 then raise exception 'KOMBAX_CLUB_INTEREST_TEXT_INVALID';end if;
  if not exists(select 1 from public.clubes where id=p_club_id and activo) then raise exception 'KOMBAX_CLUB_NOT_AVAILABLE';end if;
  if p_target_socio_id is not null and not exists(select 1 from public.socios where id=p_target_socio_id and club_id=p_club_id) then raise exception 'KOMBAX_STUDENT_NOT_FOUND';end if;
  insert into public.perfiles(id,nombre,apellidos) values(v_uid,coalesce(auth.jwt()->'user_metadata'->>'nombre',split_part(coalesce(auth.jwt()->>'email','usuario'),'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos','')) on conflict(id) do nothing;
  select btrim(concat_ws(' ',p.nombre,p.apellidos)) into v_name from public.perfiles p where p.id=v_uid;
  insert into public.kombax_club_interest_threads_r58(club_id,account_id,estado,request_kind,target_socio_id,resolved_by,resolved_at,resolution)
    values(p_club_id,v_uid,'abierta',v_kind,p_target_socio_id,null,null,null)
    on conflict(club_id,account_id) do update set estado='abierta',request_kind=excluded.request_kind,target_socio_id=excluded.target_socio_id,resolved_by=null,resolved_at=null,resolution=null,actualizada_en=now()
    returning id into v_thread;
  insert into public.kombax_club_interest_messages_r58(thread_id,autor_perfil_id,texto) values(v_thread,v_uid,v_text) returning id into v_msg;
  insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  select p_club_id,rol,'club-link-'||v_thread::text||'-'||rol::text,'inscripcion',case when v_kind='family' then 'Solicitud de vinculación familiar' else 'Solicitud de vinculación como miembro' end,
    coalesce(nullif(v_name,''),'Una cuenta KOMBAX')||' solicita autorización del club.','members',jsonb_build_object('thread_id',v_thread,'account_id',v_uid,'message_id',v_msg,'kind','club_link_request','request_kind',v_kind,'target_socio_id',p_target_socio_id),v_uid
  from unnest(array['direccion','secretaria']::public.rol_club[]) rol
  on conflict (club_id,rol_destino,clave) where (clave is not null and rol_destino is not null)
  do update set titulo=excluded.titulo,cuerpo=excluded.cuerpo,ruta=excluded.ruta,datos=excluded.datos,leida=false,leida_en=null,ciclo_estado='activo',archivado_en=null,archivado_por=null,papelera_en=null,papelera_por=null,creado_en=now();
  return jsonb_build_object('ok',true,'thread_id',v_thread,'message_id',v_msg,'request_kind',v_kind,'membership_created',false,'club_notified',true,'code_required',false,'club_authorization_required',true);
end $$;
revoke all on function public.app_kombax_club_link_request_r117(uuid,text,text,uuid) from public,anon;
grant execute on function public.app_kombax_club_link_request_r117(uuid,text,text,uuid) to authenticated;

create or replace function public.app_kombax_club_interest_send_r58(p_club_id uuid,p_mensaje text)
returns jsonb language sql security definer set search_path to 'public','auth' as $$ select public.app_kombax_club_link_request_r117(p_club_id,'member',p_mensaje,null); $$;
revoke all on function public.app_kombax_club_interest_send_r58(uuid,text) from public,anon;
grant execute on function public.app_kombax_club_interest_send_r58(uuid,text) to authenticated;

drop function if exists public.app_kombax_club_interest_list_r98(uuid);
create function public.app_kombax_club_interest_list_r98(p_club_id uuid)
returns table(thread_id uuid,account_id uuid,account_name text,account_email text,message text,sent_at timestamptz,request_kind text,target_socio_id uuid)
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not(public.tiene_rol_club(p_club_id,'direccion','secretaria') or exists(select 1 from public.miembros_club mc where mc.club_id=p_club_id and mc.perfil_id=auth.uid() and mc.activo and mc.coordinacion)) then raise exception 'KOMBAX_CLUB_INTEREST_FORBIDDEN' using errcode='42501';end if;
  return query select t.id,t.account_id,btrim(concat_ws(' ',p.nombre,p.apellidos)),lower(coalesce(u.email,'')),m.texto,m.creado_en,t.request_kind,t.target_socio_id
  from public.kombax_club_interest_threads_r58 t join public.perfiles p on p.id=t.account_id left join auth.users u on u.id=t.account_id
  join lateral(select x.texto,x.creado_en from public.kombax_club_interest_messages_r58 x where x.thread_id=t.id order by x.creado_en desc limit 1)m on true
  where t.club_id=p_club_id and t.estado='abierta' order by m.creado_en desc limit 100;
end $$;
revoke all on function public.app_kombax_club_interest_list_r98(uuid) from public,anon,service_role;
grant execute on function public.app_kombax_club_interest_list_r98(uuid) to authenticated;

create or replace function public.app_kombax_club_link_resolve_r117(p_thread_id uuid,p_approve boolean,p_socio_id uuid default null)
returns jsonb language plpgsql security definer set search_path to 'public','auth' as $$
declare v_uid uuid:=auth.uid();v_thread public.kombax_club_interest_threads_r58;v_account uuid;v_email text;v_confirmed timestamptz;v_profile public.perfiles;v_socio public.socios;v_other uuid;v_mode text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  select * into v_thread from public.kombax_club_interest_threads_r58 where id=p_thread_id for update;
  if v_thread.id is null then raise exception 'KOMBAX_CLUB_LINK_REQUEST_NOT_FOUND';end if;
  if v_thread.estado<>'abierta' then raise exception 'KOMBAX_CLUB_LINK_REQUEST_ALREADY_RESOLVED';end if;
  if not(public.tiene_rol_club(v_thread.club_id,'direccion','secretaria') or exists(select 1 from public.miembros_club mc where mc.club_id=v_thread.club_id and mc.perfil_id=v_uid and mc.activo and mc.coordinacion)) then raise exception 'KOMBAX_CLUB_LINK_REQUEST_FORBIDDEN';end if;
  if not p_approve then update public.kombax_club_interest_threads_r58 set estado='cerrada',resolved_by=v_uid,resolved_at=now(),resolution='rejected',actualizada_en=now() where id=v_thread.id;return jsonb_build_object('ok',true,'estado','rechazada','thread_id',v_thread.id);end if;
  v_account:=v_thread.account_id;select lower(coalesce(u.email,'')),u.email_confirmed_at into v_email,v_confirmed from auth.users u where u.id=v_account and u.deleted_at is null;
  if v_confirmed is null then raise exception 'KOMBAX_EMAIL_VERIFICATION_REQUIRED';end if;select * into v_profile from public.perfiles where id=v_account;if v_profile.id is null then raise exception 'KOMBAX_PROFILE_REQUIRED';end if;
  if v_thread.request_kind='family' then
    select * into v_socio from public.socios where id=coalesce(p_socio_id,v_thread.target_socio_id) and club_id=v_thread.club_id for update;
    if v_socio.id is null then raise exception 'KOMBAX_FAMILY_STUDENT_REQUIRED';end if;if v_socio.estado in ('baja','suspendido') then raise exception 'KOMBAX_STUDENT_NOT_ACTIVE';end if;
    insert into public.tutores_socios(club_id,tutor_perfil_id,socio_id,parentesco,contacto_principal) values(v_thread.club_id,v_account,v_socio.id,'Familiar / tutor autorizado',true)
      on conflict(club_id,tutor_perfil_id,socio_id) do update set contacto_principal=true;
    insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion) values(v_thread.club_id,v_account,'familia',true,false) on conflict(club_id,perfil_id,rol) do update set activo=true;
    update public.socios set kombax_acceso_estado='activo',kombax_acceso_email=coalesce(kombax_acceso_email,v_email),kombax_acceso_modo='tutor',kombax_acceso_actualizado_en=now(),kombax_vinculado_en=coalesce(kombax_vinculado_en,now()) where id=v_socio.id;
    v_mode:='familia';
  else
    if p_socio_id is not null then select * into v_socio from public.socios where id=p_socio_id and club_id=v_thread.club_id for update;
    else select * into v_socio from public.socios s where s.club_id=v_thread.club_id and(s.perfil_id=v_account or(s.perfil_id is null and lower(btrim(coalesce(s.email,'')))=v_email)) order by(s.perfil_id=v_account)desc,s.creado_en asc limit 1 for update;end if;
    if v_socio.id is null then
      insert into public.socios(club_id,perfil_id,nombre,apellidos,email,estado,kombax_acceso_estado,kombax_acceso_email,kombax_acceso_modo,kombax_acceso_actualizado_en,kombax_vinculado_en)
      values(v_thread.club_id,v_account,coalesce(nullif(btrim(v_profile.nombre),''),split_part(v_email,'@',1)),coalesce(nullif(btrim(v_profile.apellidos),''),'—'),v_email,'activo','activo',v_email,'alumno',now(),now()) returning * into v_socio;
    else
      if v_socio.perfil_id is not null and v_socio.perfil_id<>v_account then raise exception 'KOMBAX_STUDENT_ALREADY_LINKED_TO_OTHER_ACCOUNT';end if;
      select id into v_other from public.socios where club_id=v_thread.club_id and perfil_id=v_account and id<>v_socio.id limit 1;if v_other is not null then raise exception 'KOMBAX_ACCOUNT_ALREADY_HAS_STUDENT_MEMBERSHIP_IN_CLUB';end if;
      update public.socios set perfil_id=v_account,email=coalesce(nullif(email,''),v_email),kombax_acceso_estado='activo',kombax_acceso_email=v_email,kombax_acceso_modo='alumno',kombax_acceso_actualizado_en=now(),kombax_vinculado_en=coalesce(kombax_vinculado_en,now()),actualizado_en=now() where id=v_socio.id returning * into v_socio;
    end if;
    insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion) values(v_thread.club_id,v_account,'alumno',true,false) on conflict(club_id,perfil_id,rol) do update set activo=true;
    update public.identidades_sociales set club_origen_id=v_thread.club_id,socio_origen_id=v_socio.id,actualizado_en=now() where perfil_id=v_account and estado='activa';v_mode:='miembro';
  end if;
  update public.kombax_club_interest_threads_r58 set estado='respondida',target_socio_id=v_socio.id,resolved_by=v_uid,resolved_at=now(),resolution='approved',actualizada_en=now() where id=v_thread.id;
  insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  values(v_thread.club_id,v_account,'club-link-approved-'||v_thread.id,'inscripcion','Vinculación aprobada',case when v_mode='familia' then 'El club ha autorizado tu acceso familiar.' else 'El club ha confirmado tu membresía.' end,case when v_mode='familia' then 'students' else 'social' end,jsonb_build_object('thread_id',v_thread.id,'club_id',v_thread.club_id,'socio_id',v_socio.id,'mode',v_mode),v_uid) on conflict do nothing;
  return jsonb_build_object('ok',true,'estado','aprobada','thread_id',v_thread.id,'club_id',v_thread.club_id,'socio_id',v_socio.id,'mode',v_mode,'private_club_access_enabled',true);
end $$;
revoke all on function public.app_kombax_club_link_resolve_r117(uuid,boolean,uuid) from public,anon;
grant execute on function public.app_kombax_club_link_resolve_r117(uuid,boolean,uuid) to authenticated;

create or replace function public.app_kombax_member_private_sync_r117() returns trigger language plpgsql security definer set search_path to 'public' as $$ begin update public.identidades_sociales set actualizado_en=now() where perfil_id=new.perfil_id and estado='activa';return new;end $$;
drop trigger if exists trg_kombax_member_private_sync_r117 on public.kombax_member_private_r117;
create trigger trg_kombax_member_private_sync_r117 after insert or update of fecha_nacimiento on public.kombax_member_private_r117 for each row execute function public.app_kombax_member_private_sync_r117();

create or replace function public.app_kombax_direct_private_social_sync_r117() returns trigger language plpgsql security definer set search_path to 'public' as $$ begin update public.perfiles_kombax_directos set actualizado_en=now() where id=new.perfil_directo_id and tipo='espectador';return new;end $$;
drop trigger if exists trg_kombax_direct_private_social_sync_r117 on public.kombax_perfil_persona_privada_v196;
create trigger trg_kombax_direct_private_social_sync_r117 after insert or update of fecha_nacimiento on public.kombax_perfil_persona_privada_v196 for each row execute function public.app_kombax_direct_private_social_sync_r117();

notify pgrst,'reload schema';

create or replace function public.app_kombax_social_mis_perfiles_r117(p_club_id uuid default null)
returns table(
  id uuid,sujeto_tipo text,nombre_publico text,slug text,
  avatar_url text,avatar_path text,banner_url text,banner_path text,
  verificado boolean,contacto_habilitado boolean,perfil_directo_id uuid,
  perfil_tipo text,club_id uuid,club_nombre text,identity_label text,
  publication_enabled boolean,network_enabled boolean,album_enabled boolean
)
language sql stable security definer set search_path to 'public','auth' as $$
  select sp.id,sp.sujeto_tipo,sp.nombre_publico,sp.slug,
    public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),
    public.app_kombax_social_banner_url_v063(sp.id),public.app_kombax_social_banner_path_v058(sp.id),
    sp.verificado,public.app_kombax_social_contactable_v041(sp.id),sp.perfil_directo_id,
    public.app_kombax_social_tipo_v051(sp.id),coalesce(sp.club_id,i.club_origen_id),c.nombre,
    case when sp.sujeto_tipo='club' then c.nombre||' · Club'
         when sp.sujeto_tipo='miembro' then sp.nombre_publico||' · Miembro'||case when c.nombre is not null then ' de '||c.nombre else '' end
         else sp.nombre_publico||' · '||initcap(public.app_kombax_social_tipo_v051(sp.id)) end,
    public.app_kombax_social_puede_actuar_v051(sp.id),public.app_kombax_social_network_actor_allowed_v255(sp.id),
    case when public.app_kombax_social_tipo_v051(sp.id)='espectador' then false else true end
  from public.kombax_social_perfiles sp left join public.identidades_sociales i on i.id=sp.identidad_social_id
  left join public.clubes c on c.id=coalesce(sp.club_id,i.club_origen_id)
  where public.app_kombax_social_network_actor_allowed_v255(sp.id)
    and (p_club_id is null or sp.sujeto_tipo<>'club' or sp.club_id=p_club_id)
  order by case when p_club_id is not null and sp.sujeto_tipo='club' and sp.club_id=p_club_id then 0 when sp.sujeto_tipo='miembro' then 1 else 2 end,sp.nombre_publico;
$$;
revoke all on function public.app_kombax_social_mis_perfiles_r117(uuid) from public,anon;
grant execute on function public.app_kombax_social_mis_perfiles_r117(uuid) to authenticated;

notify pgrst,'reload schema';
