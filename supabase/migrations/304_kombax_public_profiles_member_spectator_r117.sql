-- KOMBAX R117 pilot hotfix
-- Public identity != feed publishing permission.
-- Member/Practitioner can own a public profile + album without a Club.
-- Feed publishing for Member remains gated by confirmed Club membership.
-- Spectator has a basic public profile, avatar/banner and info, but no album and no feed publishing.

alter table public.identidades_sociales
  alter column club_origen_id drop not null;

create or replace function public.app_kombax_social_puede_gestionar_perfil_publico_r117(p_social_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public','auth'
as $$
  select auth.uid() is not null and exists(
    select 1
    from public.kombax_social_perfiles sp
    left join public.identidades_sociales i
      on sp.sujeto_tipo='miembro' and i.id=sp.identidad_social_id
    left join public.perfiles_kombax_directos d
      on sp.sujeto_tipo='perfil_directo' and d.id=sp.perfil_directo_id
    where sp.id=p_social_id
      and sp.estado in ('activo','limitado')
      and (
        (sp.sujeto_tipo='miembro' and i.perfil_id=auth.uid() and i.estado='activa')
        or
        (sp.sujeto_tipo='perfil_directo' and d.perfil_id=auth.uid() and d.estado not in ('suspendido','cerrado'))
        or public.app_kombax_social_puede_actuar_v051(sp.id)
      )
  );
$$;

revoke all on function public.app_kombax_social_puede_gestionar_perfil_publico_r117(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_gestionar_perfil_publico_r117(uuid) to authenticated;

create or replace function public.app_kombax_social_sync_miembro_v041()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_comp uuid;
  v_socio public.socios;
  v_adulto boolean:=false;
  v_membership_confirmed boolean:=false;
begin
  select d.id into v_comp
  from public.perfiles_kombax_directos d
  where d.tipo='competidor' and d.origen_identidad_social_id=new.id
  order by d.creado_en limit 1;

  if v_comp is not null then
    perform public.app_kombax_social_switch_competitor_v072(v_comp);
    return new;
  end if;

  if new.socio_origen_id is not null then
    select * into v_socio
    from public.socios s
    where s.id=new.socio_origen_id
      and (new.club_origen_id is null or s.club_id=new.club_origen_id);
    v_adulto:=v_socio.fecha_nacimiento is not null
      and extract(year from age(current_date,v_socio.fecha_nacimiento))>=18;
  end if;

  select exists(
    select 1
    from public.socios s
    join public.miembros_club mc
      on mc.club_id=s.club_id
     and mc.perfil_id=new.perfil_id
     and mc.rol='alumno'
     and mc.activo
    where s.perfil_id=new.perfil_id
      and s.estado='activo'
      and s.kombax_acceso_estado='activo'
      and (new.club_origen_id is null or s.club_id=new.club_origen_id)
      and (new.socio_origen_id is null or s.id=new.socio_origen_id)
  ) into v_membership_confirmed;

  insert into public.kombax_social_perfiles(
    sujeto_tipo,identidad_social_id,slug,nombre_publico,bio,
    verificado,visible,publicar_habilitado,contacto_habilitado,estado
  ) values(
    'miembro',new.id,new.slug,new.nombre_publico,new.bio_publica,
    false,new.estado='activa',new.estado='activa' and v_membership_confirmed,
    new.estado='activa' and v_membership_confirmed and v_adulto,
    case new.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end
  )
  on conflict(identidad_social_id) where sujeto_tipo='miembro'
  do update set
    slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,verificado=false,
    visible=excluded.visible,publicar_habilitado=excluded.publicar_habilitado,
    contacto_habilitado=excluded.contacto_habilitado,estado=excluded.estado,actualizado_en=now();
  return new;
end $$;

create or replace function public.app_kombax_social_sync_directo_v041()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_verified boolean:=false;
  v_visible boolean:=false;
  v_social_ready boolean:=false;
  v_badge boolean:=false;
begin
  if new.tipo='competidor' and new.origen_identidad_social_id is not null then
    perform public.app_kombax_social_switch_competitor_v072(new.id);
    return new;
  end if;

  if new.tipo='espectador' then
    insert into public.kombax_social_perfiles(
      sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,
      verificado,visible,publicar_habilitado,contacto_habilitado,estado
    ) values(
      'perfil_directo',new.id,new.slug,new.nombre_publico,new.descripcion,new.avatar_path,new.banner_path,
      false,new.estado not in ('suspendido','cerrado'),false,false,
      case when new.estado='suspendido' then 'suspendido' when new.estado='cerrado' then 'cerrado' else 'activo' end
    )
    on conflict(perfil_directo_id) where sujeto_tipo='perfil_directo'
    do update set
      slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,
      avatar_path=excluded.avatar_path,banner_path=excluded.banner_path,
      verificado=false,visible=excluded.visible,publicar_habilitado=false,contacto_habilitado=false,
      estado=excluded.estado,actualizado_en=now();
    return new;
  end if;

  if new.tipo not in ('competidor','marca','federacion','profesional','media') then
    update public.kombax_social_perfiles
    set verificado=false,visible=false,publicar_habilitado=false,contacto_habilitado=false,
        estado='limitado',actualizado_en=now()
    where sujeto_tipo='perfil_directo' and perfil_directo_id=new.id;
    return new;
  end if;

  v_verified:=new.verificacion_estado='verificado'
    and new.workflow_estado in ('verified','limited') and new.estado='activo';
  v_visible:=coalesce(new.publico,false) and v_verified;
  v_social_ready:=v_visible and coalesce(new.social_activo,false);
  v_badge:=case
    when new.tipo='competidor' then v_verified
    when new.tipo in ('marca','federacion') then v_verified
      and public.app_kombax_subscription_paid_v102('perfil_directo',new.id)
    else false end;

  insert into public.kombax_social_perfiles(
    sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,
    verificado,visible,publicar_habilitado,contacto_habilitado,estado
  ) values(
    'perfil_directo',new.id,new.slug,new.nombre_publico,new.descripcion,new.avatar_path,new.banner_path,
    v_badge,v_visible,v_social_ready,v_social_ready,
    case when new.estado='suspendido' then 'suspendido' when new.estado='cerrado' then 'cerrado'
         when v_visible then 'activo' else 'limitado' end
  )
  on conflict(perfil_directo_id) where sujeto_tipo='perfil_directo'
  do update set
    slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,
    avatar_path=excluded.avatar_path,banner_path=excluded.banner_path,
    verificado=excluded.verificado,visible=excluded.visible,
    publicar_habilitado=excluded.publicar_habilitado,contacto_habilitado=excluded.contacto_habilitado,
    estado=excluded.estado,actualizado_en=now();
  return new;
end $$;

create or replace function public.app_kombax_identity_mutate_v124(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_uid uuid:=auth.uid();
  v_club uuid;
  v_existing public.app_mutation_requests;
  v_identity public.identidades_sociales;
  v_profile public.perfiles;
  v_social_id uuid;
  v_locked text;
  v_name text;
  v_rules text:='1.2.0';
  v_result jsonb;
begin
  if p_operation not in ('kombax.identity.member.activate','kombax.identity.member.profile.update') then
    return public.app_kombax_identity_mutate_v123(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(p_payload->>'club_id','')::uuid; exception when others then v_club:=null; end;

  if p_operation='kombax.identity.member.profile.update' then
    return public.app_kombax_identity_mutate_v123(p_operation,p_payload,p_request_id);
  end if;

  if public.app_kombax_member_membership_confirmed_r115(v_club) then
    return public.app_kombax_identity_mutate_v123(p_operation,p_payload,p_request_id);
  end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,null,p_operation);
  end if;

  if coalesce((p_payload->>'acepta_normas')::boolean,false) is not true
     or coalesce((p_payload->>'acepta_privacidad')::boolean,false) is not true then
    raise exception 'KOMBAX_SOCIAL_CONSENT_REQUIRED';
  end if;

  select account_type into v_locked from public.kombax_account_types_r100 where user_id=v_uid for update;
  if v_locked is null then
    insert into public.kombax_account_types_r100(user_id,account_type)
    values(v_uid,'miembro') on conflict(user_id) do nothing;
  elsif v_locked not in ('miembro','competidor') then
    raise exception 'KOMBAX_ACCOUNT_TYPE_IMMUTABLE';
  end if;

  select * into v_profile from public.perfiles where id=v_uid;
  if v_profile.id is null then raise exception 'KOMBAX_PROFILE_REQUIRED'; end if;

  select * into v_identity from public.identidades_sociales where perfil_id=v_uid for update;
  if v_identity.id is not null and v_identity.estado in ('suspendida','cerrada') then
    raise exception 'KOMBAX_SOCIAL_REACTIVATION_REQUIRES_REVIEW';
  end if;

  select t.version into v_rules from public.textos_legales t
  where t.tipo='comunidad_general' and t.vigente order by t.creado_en desc limit 1;
  v_rules:=coalesce(v_rules,'1.2.0');

  v_name:=btrim(concat_ws(' ',nullif(v_profile.nombre,''),nullif(v_profile.apellidos,'')));
  if v_name='' then v_name:=split_part(coalesce(auth.jwt()->>'email','usuario'),'@',1); end if;

  if v_identity.id is null then
    insert into public.identidades_sociales(
      perfil_id,club_origen_id,socio_origen_id,tipo,slug,nombre_publico,
      estado,version_normas,activada_en,actualizado_en
    ) values(
      v_uid,null,null,'miembro','miembro-'||replace(v_uid::text,'-',''),
      left(v_name,160),'activa',v_rules,now(),now()
    ) returning * into v_identity;
  else
    update public.identidades_sociales
       set nombre_publico=left(v_name,160),version_normas=coalesce(version_normas,v_rules),actualizado_en=now()
     where id=v_identity.id returning * into v_identity;
  end if;

  select sp.id into v_social_id from public.kombax_social_perfiles sp
  where sp.sujeto_tipo='miembro' and sp.identidad_social_id=v_identity.id;
  if v_social_id is null then raise exception 'KOMBAX_SOCIAL_PROFILE_NOT_CREATED'; end if;

  insert into public.kombax_actor_audit(actor_perfil_id,public_social_id,club_id,accion,objeto_tipo,objeto_id,detalle)
  values(v_uid,v_social_id,null,'social.member.public_profile.activate','social_profile',v_social_id,
    jsonb_build_object('membership_confirmed',false,'publication_enabled',false,'album_enabled',true,'source','self_service_no_club_r117'));

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,
    'data',jsonb_build_object('identidad_social_id',v_identity.id,'social_profile_id',v_social_id,'status','activa',
      'membership_confirmed',false,'publication_enabled',false,'album_enabled',true,'rules_version',v_rules));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;

create or replace function public.app_kombax_social_estado_v124(p_club_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public','auth'
as $$
declare
  v jsonb;
  v_uid uuid:=auth.uid();
  v_confirmed boolean:=false;
  v_identity public.identidades_sociales;
  v_account_type text;
begin
  v:=public.app_kombax_social_estado_v123(p_club_id);
  if v_uid is null then return v; end if;
  select * into v_identity from public.identidades_sociales where perfil_id=v_uid limit 1;
  if v_identity.id is not null then
    v_confirmed:=public.app_kombax_member_membership_confirmed_r115(p_club_id);
    return v||jsonb_build_object(
      'scope','member','status',case when v_identity.estado='activa' then 'activa' else 'inactiva' end,
      'eligible',v_identity.estado='activa','membership_confirmed',v_confirmed,
      'publication_enabled',v_confirmed and v_identity.estado='activa',
      'album_enabled',v_identity.estado='activa','profile_enabled',v_identity.estado='activa',
      'reason',case when v_identity.estado<>'activa' then 'Tu perfil público está suspendido o cerrado.'
        when v_confirmed then 'Tu perfil público está activo y tu club ha confirmado la membresía.'
        else 'Tu perfil público está activo. Podrás publicar en KOMBAX Social cuando un club confirme tu membresía.' end
    );
  end if;
  select account_type into v_account_type from public.kombax_account_types_r100 where user_id=v_uid;
  if v_account_type='miembro' then
    return v||jsonb_build_object(
      'scope','member','status','inactiva','eligible',true,'membership_confirmed',false,
      'publication_enabled',false,'album_enabled',true,'profile_enabled',true,
      'reason','Puedes crear tu perfil público de Miembro/Practicante aunque todavía no tengas un club confirmado.'
    );
  end if;
  return v;
end $$;

create or replace function public.app_kombax_member_public_profile_r117()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public','auth'
as $$
declare v_uid uuid:=auth.uid();v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select jsonb_build_object(
    'id',sp.id,'sujeto_tipo','miembro','nombre_publico',sp.nombre_publico,'slug',sp.slug,
    'avatar_url',public.app_kombax_social_avatar_url_v063(sp.id),'avatar_path',public.app_kombax_social_avatar_path_v058(sp.id),
    'banner_url',public.app_kombax_social_banner_url_v063(sp.id),'banner_path',public.app_kombax_social_banner_path_v058(sp.id),
    'club_id',i.club_origen_id,'membership_confirmed',public.app_kombax_member_membership_confirmed_r115(i.club_origen_id),
    'publication_enabled',public.app_kombax_social_puede_actuar_v051(sp.id),'album_enabled',true,'profile_enabled',i.estado='activa'
  ) into v_result
  from public.identidades_sociales i
  join public.kombax_social_perfiles sp on sp.sujeto_tipo='miembro' and sp.identidad_social_id=i.id
  where i.perfil_id=v_uid limit 1;
  return coalesce(v_result,'{}'::jsonb);
end $$;

revoke all on function public.app_kombax_member_public_profile_r117() from public,anon;
grant execute on function public.app_kombax_member_public_profile_r117() to authenticated;

create or replace function public.app_kombax_member_identity_attach_r117()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.perfil_id is not null and new.estado='activo' and new.kombax_acceso_estado='activo'
     and exists(select 1 from public.miembros_club mc where mc.club_id=new.club_id and mc.perfil_id=new.perfil_id and mc.rol='alumno' and mc.activo) then
    update public.identidades_sociales i
       set club_origen_id=new.club_id,socio_origen_id=new.id,actualizado_en=now()
     where i.perfil_id=new.perfil_id and i.estado='activa'
       and (i.club_origen_id is null or i.club_origen_id=new.club_id);
  end if;
  return new;
end $$;

drop trigger if exists trg_kombax_member_identity_attach_r117 on public.socios;
create trigger trg_kombax_member_identity_attach_r117
after insert or update of perfil_id,kombax_acceso_estado,estado on public.socios
for each row execute function public.app_kombax_member_identity_attach_r117();

create or replace function public.app_kombax_social_media_guard_v053()
returns trigger
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare v_count integer;v_subject text;v_direct_type text;
begin
  if not public.app_kombax_social_puede_gestionar_perfil_publico_r117(new.social_profile_id)
     and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_SOCIAL_MEDIA_FORBIDDEN'; end if;
  select sp.sujeto_tipo,d.tipo into v_subject,v_direct_type
  from public.kombax_social_perfiles sp left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  where sp.id=new.social_profile_id;
  if v_direct_type='espectador' and new.tipo in ('photo','video') then raise exception 'KOMBAX_SPECTATOR_ALBUM_DISABLED'; end if;
  if new.en_album and new.tipo in ('photo','video') and new.estado in ('active','pending_review') and v_subject='miembro' then
    select count(*) into v_count from public.kombax_social_media m
    where m.social_profile_id=new.social_profile_id and m.tipo=new.tipo and m.en_album
      and m.estado in ('active','pending_review') and m.id<>new.id;
    if new.tipo='photo' and v_count>=10 then raise exception 'KOMBAX_SOCIAL_ALBUM_PHOTO_LIMIT_10'; end if;
    if new.tipo='video' and v_count>=3 then raise exception 'KOMBAX_SOCIAL_ALBUM_VIDEO_LIMIT_3'; end if;
  end if;
  new.actualizado_en:=now();return new;
end $$;

-- Existing R117 APIs are retained, but public-profile management is separated from feed publishing.
do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_social_mutate_v053' and p.prokind='f';
  d:=replace(d,
    'if not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception ''KOMBAX_SOCIAL_MEDIA_FORBIDDEN'';end if;',
    'if not public.app_kombax_social_puede_gestionar_perfil_publico_r117(v_actor) then raise exception ''KOMBAX_SOCIAL_MEDIA_FORBIDDEN'';end if;');
  d:=replace(d,
    'select * into v_media from public.kombax_social_media where id=v_media_id for update;if v_media.id is null or not public.app_kombax_social_puede_actuar_v051(v_media.social_profile_id) then raise exception ''KOMBAX_SOCIAL_MEDIA_NOT_OWNED'';end if;',
    'select * into v_media from public.kombax_social_media where id=v_media_id for update;if v_media.id is null or not public.app_kombax_social_puede_gestionar_perfil_publico_r117(v_media.social_profile_id) then raise exception ''KOMBAX_SOCIAL_MEDIA_NOT_OWNED'';end if;');
  execute d;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_social_media_v085' and p.prokind='f';
  d:=replace(d,'declare v_manage boolean:=public.app_kombax_social_puede_actuar_v051(p_social_id);',
               'declare v_manage boolean:=public.app_kombax_social_puede_gestionar_perfil_publico_r117(p_social_id);');
  execute d;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_social_banner_position_v131' and p.prokind='f';
  d:=replace(d,
    'if not public.app_kombax_social_puede_actuar_v051(p_social_id) then raise exception ''KOMBAX_SOCIAL_PROFILE_FORBIDDEN''; end if;',
    'if not public.app_kombax_social_puede_gestionar_perfil_publico_r117(p_social_id) then raise exception ''KOMBAX_SOCIAL_PROFILE_FORBIDDEN''; end if;');
  execute d;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_social_network_mutate_v065' and p.prokind='f';
  d:=replace(d,
    'if not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception ''KOMBAX_AFFILIATION_FORBIDDEN'';end if;',
    'if not public.app_kombax_social_puede_gestionar_perfil_publico_r117(v_actor) then raise exception ''KOMBAX_AFFILIATION_FORBIDDEN'';end if;');
  execute d;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_media_presentation_set_v187' and p.prokind='f';
  d:=replace(d,
    'if v_social is null or not public.app_kombax_social_puede_actuar_v051(v_social) then raise exception ''KOMBAX_SOCIAL_MEDIA_FORBIDDEN''; end if;',
    'if v_social is null or not public.app_kombax_social_puede_gestionar_perfil_publico_r117(v_social) then raise exception ''KOMBAX_SOCIAL_MEDIA_FORBIDDEN''; end if;');
  execute d;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_media_presentations_v187' and p.prokind='f';
  d:=replace(d,'public.app_kombax_social_puede_actuar_v051(m.social_profile_id)',
               'public.app_kombax_social_puede_gestionar_perfil_publico_r117(m.social_profile_id)');
  execute d;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_media_mutate_v072' and p.prokind='f';
  d:=replace(d,
    'if not exists('||chr(10)||
    '      select 1 from public.perfiles_kombax_directos d'||chr(10)||
    '      where d.id=v_profile'||chr(10)||
    '        and d.workflow_estado in (''verified'',''limited'')'||chr(10)||
    '        and d.verificacion_estado=''verificado'''||chr(10)||
    '        and d.estado=''activo'''||chr(10)||
    '    ) then raise exception ''KOMBAX_PROFILE_VERIFIED_REQUIRED''; end if;',
    'if not exists('||chr(10)||
    '      select 1 from public.perfiles_kombax_directos d'||chr(10)||
    '      where d.id=v_profile and ('||chr(10)||
    '        (d.tipo=''espectador'' and d.estado not in (''suspendido'',''cerrado''))'||chr(10)||
    '        or (d.workflow_estado in (''verified'',''limited'') and d.verificacion_estado=''verificado'' and d.estado=''activo'')'||chr(10)||
    '      )'||chr(10)||
    '    ) then raise exception ''KOMBAX_PROFILE_VERIFIED_REQUIRED''; end if;');
  d:=replace(d,
    'if v_type not in (''avatar'',''banner'',''photo'',''video'') then raise exception ''KOMBAX_MEDIA_TYPE_INVALID''; end if;',
    'if v_type not in (''avatar'',''banner'',''photo'',''video'') then raise exception ''KOMBAX_MEDIA_TYPE_INVALID''; end if;'||chr(10)||
    '    if v_type in (''photo'',''video'') and exists(select 1 from public.perfiles_kombax_directos d where d.id=v_profile and d.tipo=''espectador'') then raise exception ''KOMBAX_SPECTATOR_ALBUM_DISABLED''; end if;');
  execute d;
end $$;

create or replace function public.app_kombax_perfil_publico_v052(p_social_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public','auth'
as $$
declare
  sp public.kombax_social_perfiles;v_type text;v_core jsonb:='{}'::jsonb;v_album jsonb:='[]'::jsonb;
  v_posts jsonb:='[]'::jsonb;v_rel jsonb:='[]'::jsonb;v_showcase jsonb:='[]'::jsonb;v_club uuid;v_direct uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into sp from public.kombax_social_perfiles where id=p_social_id and visible and estado='activo';
  if sp.id is null then raise exception 'KOMBAX_PUBLIC_PROFILE_NOT_AVAILABLE'; end if;
  if exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id) then raise exception 'KOMBAX_PROFILE_BLOCKED'; end if;
  v_type:=public.app_kombax_social_tipo_v051(sp.id);v_club:=sp.club_id;v_direct:=sp.perfil_directo_id;

  if sp.sujeto_tipo='club' then
    select coalesce(to_jsonb(pc)-'actualizado_por','{}'::jsonb) into v_core from public.perfiles_club_publicos pc where pc.club_id=sp.club_id;
    select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'tipo',m.tipo,'storage_path',m.storage_path,'mime_type',m.mime_type,'duration_seconds',m.duration_seconds,'position',m.position)
      order by case m.tipo when 'photo' then 0 else 1 end,m.position,m.creado_en),'[]'::jsonb)
      into v_album from public.kombax_club_media m where m.club_id=sp.club_id and m.estado='active';
  elsif sp.sujeto_tipo='miembro' then
    select i.club_origen_id into v_club from public.identidades_sociales i where i.id=sp.identidad_social_id;
    select jsonb_build_object('club_id',i.club_origen_id,'club_nombre',c.nombre,'bio_publica',coalesce(i.bio_publica,sp.bio),'tipo','miembro')
      into v_core from public.identidades_sociales i left join public.clubes c on c.id=i.club_origen_id where i.id=sp.identidad_social_id;
  else
    select coalesce(to_jsonb(d)-'perfil_id'-'moderacion_estado','{}'::jsonb) into v_core from public.perfiles_kombax_directos d where d.id=sp.perfil_directo_id;
    if v_type<>'espectador' then
      select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'tipo',m.tipo,'storage_path',m.storage_path,'mime_type',m.mime_type,'duration_seconds',m.duration_seconds,'position',m.position)
        order by case m.tipo when 'avatar' then 0 when 'banner' then 1 when 'photo' then 2 else 3 end,m.position,m.creado_en),'[]'::jsonb)
        into v_album from public.kombax_perfil_media m
        where m.perfil_directo_id=sp.perfil_directo_id and m.estado='active' and m.tipo in ('photo','video');
    else v_album:='[]'::jsonb; end if;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'tipo',p.tipo,'texto',p.texto,'likes_count',p.likes_count,'comentarios_count',p.comentarios_count,'creado_en',p.creado_en,'comentarios_estado',p.comentarios_estado)
    order by p.creado_en desc),'[]'::jsonb) into v_posts
  from (select * from public.kombax_social_publicaciones where autor_perfil_id=sp.id and estado='activa' order by creado_en desc limit 20) p;

  select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'tipo',r.tipo,
    'otro_id',case when r.origen_social_id=sp.id then r.destino_social_id else r.origen_social_id end,
    'otro_nombre',case when r.origen_social_id=sp.id then d.nombre_publico else o.nombre_publico end,
    'confirmado_en',r.confirmado_en) order by r.confirmado_en desc),'[]'::jsonb) into v_rel
  from public.kombax_relaciones r
  join public.kombax_social_perfiles o on o.id=r.origen_social_id
  join public.kombax_social_perfiles d on d.id=r.destino_social_id
  where r.estado='confirmed' and (r.origen_social_id=sp.id or r.destino_social_id=sp.id);

  if sp.sujeto_tipo='club' then
    select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'nombre',e.nombre,'resumen',e.resumen,'imagen_url',e.imagen_url,'precio_orientativo',e.precio_orientativo,'moneda',e.moneda,'visitar_url',e.visitar_url,'contacto_url',e.contacto_url,'donde_encontrar_url',e.donde_encontrar_url)
      order by e.destacado desc,e.publicado_en desc),'[]'::jsonb) into v_showcase
    from public.kombax_showcase_marcas m join public.kombax_showcase_elementos e on e.marca_id=m.id and e.estado='publicado'
    where m.sujeto_tipo='club' and m.club_id=sp.club_id and m.estado='publicada';
  elsif sp.sujeto_tipo='perfil_directo' and v_type='marca' then
    select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'nombre',e.nombre,'resumen',e.resumen,'imagen_url',e.imagen_url,'precio_orientativo',e.precio_orientativo,'moneda',e.moneda,'visitar_url',e.visitar_url,'contacto_url',e.contacto_url,'donde_encontrar_url',e.donde_encontrar_url)
      order by e.destacado desc,e.publicado_en desc),'[]'::jsonb) into v_showcase
    from public.kombax_showcase_marcas m join public.kombax_showcase_elementos e on e.marca_id=m.id and e.estado='publicado'
    where m.sujeto_tipo='marca' and m.perfil_directo_id=sp.perfil_directo_id and m.estado='publicada';
  end if;

  return jsonb_build_object(
    'id',sp.id,'sujeto_tipo',sp.sujeto_tipo,'perfil_tipo',v_type,'slug',sp.slug,'nombre_publico',sp.nombre_publico,'bio',sp.bio,
    'avatar_url',sp.avatar_url,'avatar_path',sp.avatar_path,'banner_url',sp.banner_url,'banner_path',sp.banner_path,'verificado',sp.verificado,
    'contactable',public.app_kombax_social_contactable_v041(sp.id),
    'own',public.app_kombax_social_puede_gestionar_perfil_publico_r117(sp.id),
    'profile_manage_enabled',public.app_kombax_social_puede_gestionar_perfil_publico_r117(sp.id),
    'publication_enabled',sp.publicar_habilitado and public.app_kombax_social_puede_actuar_v051(sp.id),
    'album_enabled',case when v_type='espectador' then false when sp.sujeto_tipo='miembro' then true else true end,
    'club_id',v_club,'perfil_directo_id',v_direct,'core',coalesce(v_core,'{}'::jsonb),'album',coalesce(v_album,'[]'::jsonb),
    'posts',coalesce(v_posts,'[]'::jsonb),'relations',coalesce(v_rel,'[]'::jsonb),'showcase',coalesce(v_showcase,'[]'::jsonb)
  );
end $$;

-- Spectator product contract and managed hub: public basic profile, no album/feed.
do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_profile_taxonomy_v196' and p.prokind='f';
  d:=replace(d,
    '''code'',''espectador'',''kind'',''direct'',''min_age'',16,''verification'',''none'',''public_profile_default'',false',
    '''code'',''espectador'',''kind'',''direct'',''min_age'',16,''verification'',''none'',''public_profile_default'',true');
  execute d;

  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_managed_profile_hub_v197' and p.prokind='f';
  d:=replace(d,
    'when ''espectador'' then ''["overview","saved","event_interests","notifications","privacy_support"]''::jsonb',
    'when ''espectador'' then ''["overview","public_profile","saved","event_interests","notifications","privacy_support"]''::jsonb');
  d:=replace(d,'''spectator_public_profile_default'',false','''spectator_public_profile_default'',true');
  d:=replace(d,
    '''avatar_path'',d.avatar_path,''banner_path'',d.banner_path,'||chr(10)||
    '           ''moderacion_estado'',d.moderacion_estado,''actualizado_en'',d.actualizado_en',
    '''avatar_path'',d.avatar_path,''banner_path'',d.banner_path,'||chr(10)||
    '           ''social_profile_id'',(select sp.id from public.kombax_social_perfiles sp where sp.perfil_directo_id=d.id limit 1),'||chr(10)||
    '           ''moderacion_estado'',d.moderacion_estado,''actualizado_en'',d.actualizado_en');
  execute d;
end $$;

notify pgrst,'reload schema';
