-- KOMBAX R112 · alineación de identidad pública gratuita, verificación y capacidades.
-- Objetivo: identidad pública verificada sin exigir plan; capacidades comerciales siguen ligadas a entitlement/plan.
begin;

-- 1) La suscripción sigue gobernando capacidades de pago, pero NO la existencia pública del perfil verificado.
create or replace function public.app_kombax_reconcile_entitlements_v071(p_perfil_directo_id uuid,p_actor uuid default null)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_plan text;
  v_service boolean:=false;
  v_verified boolean:=false;
  v_type text;
begin
  select d.tipo,
         d.verificacion_estado='verificado'
         and d.workflow_estado in ('verified','limited')
         and d.estado='activo'
    into v_type,v_verified
  from public.perfiles_kombax_directos d
  where d.id=p_perfil_directo_id;

  if not found then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;

  select s.modalidad,
    s.estado in ('prueba','activa')
      and (s.inicia_en is null or s.inicia_en<=now())
      and (s.termina_en is null or s.termina_en>now())
  into v_plan,v_service
  from public.kombax_suscripciones s
  join public.kombax_planes p on p.codigo=s.modalidad and p.activo
  where s.sujeto_tipo='perfil_directo'
    and s.sujeto_id=p_perfil_directo_id
    and s.estado in ('prueba','activa','pausada')
  order by s.actualizado_en desc
  limit 1;

  update public.kombax_entitlements
  set activa=false,
      termina_en=coalesce(termina_en,greatest(clock_timestamp(),inicia_en+interval '1 microsecond'))
  where sujeto_tipo='perfil_directo'
    and sujeto_id=p_perfil_directo_id
    and origen='suscripcion'
    and activa;

  if v_verified and coalesce(v_service,false) and v_plan is not null then
    insert into public.kombax_entitlements(
      sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,inicia_en,asignada_por
    )
    select 'perfil_directo',p_perfil_directo_id,pc.capacidad_clave,true,'suscripcion',now(),p_actor
    from public.kombax_plan_capacidades pc
    where pc.plan_codigo=v_plan
    on conflict do nothing;
  end if;

  update public.perfiles_kombax_directos
  set publico=(v_verified and v_type in ('competidor','marca','federacion','profesional','media')),
      actualizado_en=now()
  where id=p_perfil_directo_id;
end $$;
revoke all on function public.app_kombax_reconcile_entitlements_v071(uuid,uuid) from public,anon,authenticated;

-- 2) Perfil Social directo: visibilidad gratuita tras revisión/verificación.
--    Publicar/contactar exige además activación Social y los gates R109; el badge mantiene semántica R102.
create or replace function public.app_kombax_social_sync_directo_v041()
returns trigger
language plpgsql
security definer
set search_path=public
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

  if new.tipo not in ('competidor','marca','federacion','profesional','media') then
    update public.kombax_social_perfiles
    set verificado=false,visible=false,publicar_habilitado=false,contacto_habilitado=false,
        estado='limitado',actualizado_en=now()
    where sujeto_tipo='perfil_directo' and perfil_directo_id=new.id;
    return new;
  end if;

  v_verified:=new.verificacion_estado='verificado'
    and new.workflow_estado in ('verified','limited')
    and new.estado='activo';
  v_visible:=coalesce(new.publico,false) and v_verified;
  v_social_ready:=v_visible and coalesce(new.social_activo,false);

  v_badge:=case
    when new.tipo='competidor' then v_verified
    when new.tipo in ('marca','federacion') then v_verified
      and public.app_kombax_subscription_paid_v102('perfil_directo',new.id)
    else false
  end;

  insert into public.kombax_social_perfiles(
    sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,
    verificado,visible,publicar_habilitado,contacto_habilitado,estado
  ) values(
    'perfil_directo',new.id,new.slug,new.nombre_publico,new.descripcion,new.avatar_path,new.banner_path,
    v_badge,v_visible,v_social_ready,v_social_ready,
    case
      when new.estado='suspendido' then 'suspendido'
      when new.estado='cerrado' then 'cerrado'
      when v_visible then 'activo'
      else 'limitado'
    end
  )
  on conflict(perfil_directo_id) where sujeto_tipo='perfil_directo' do update set
    slug=excluded.slug,
    nombre_publico=excluded.nombre_publico,
    bio=excluded.bio,
    avatar_path=excluded.avatar_path,
    banner_path=excluded.banner_path,
    verificado=excluded.verificado,
    visible=excluded.visible,
    publicar_habilitado=excluded.publicar_habilitado,
    contacto_habilitado=excluded.contacto_habilitado,
    estado=excluded.estado,
    actualizado_en=now();

  return new;
end $$;
revoke all on function public.app_kombax_social_sync_directo_v041() from public,anon,authenticated;

-- 3) Continuidad Miembro -> Competidor: no requiere suscripción; conserva el mismo perfil Social/red.
create or replace function public.app_kombax_social_switch_competitor_v072(p_perfil_directo_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_d public.perfiles_kombax_directos;
  v_i public.identidades_sociales;
  v_s public.socios;
  v_member public.kombax_social_perfiles;
  v_direct public.kombax_social_perfiles;
  v_id uuid;
  v_official boolean:=false;
  v_adult boolean:=false;
  v_publish boolean:=false;
begin
  select * into v_d
  from public.perfiles_kombax_directos
  where id=p_perfil_directo_id and tipo='competidor';
  if v_d.id is null then return null; end if;

  v_official:=v_d.verificacion_estado='verificado'
    and v_d.workflow_estado in ('verified','limited')
    and v_d.estado='activo'
    and coalesce(v_d.publico,false);
  v_publish:=v_official and coalesce(v_d.social_activo,false);

  if v_d.fecha_nacimiento_verificada is not null then
    v_adult:=extract(year from age(current_date,v_d.fecha_nacimiento_verificada))>=18;
  end if;

  if v_d.origen_identidad_social_id is not null then
    select * into v_i from public.identidades_sociales where id=v_d.origen_identidad_social_id;
    if v_i.id is not null then
      select * into v_s from public.socios where id=v_i.socio_origen_id and club_id=v_i.club_origen_id;
      if not v_adult then
        v_adult:=v_s.fecha_nacimiento is not null and extract(year from age(current_date,v_s.fecha_nacimiento))>=18;
      end if;
    end if;
  end if;

  select * into v_member
  from public.kombax_social_perfiles
  where sujeto_tipo='miembro' and identidad_social_id=v_d.origen_identidad_social_id
  limit 1;

  select * into v_direct
  from public.kombax_social_perfiles
  where sujeto_tipo='perfil_directo' and perfil_directo_id=v_d.id
  limit 1;

  if v_official then
    if v_member.id is not null and v_direct.id is not null and v_member.id<>v_direct.id then
      raise exception 'KOMBAX_COMPETITOR_SOCIAL_DUPLICATE';
    end if;

    if v_member.id is not null then
      update public.kombax_social_perfiles
      set sujeto_tipo='perfil_directo',identidad_social_id=null,perfil_directo_id=v_d.id,
          nombre_publico=v_d.nombre_publico,bio=coalesce(v_d.descripcion,bio),
          avatar_path=coalesce(v_d.avatar_path,avatar_path),banner_path=coalesce(v_d.banner_path,banner_path),
          verificado=true,visible=true,publicar_habilitado=v_publish,
          contacto_habilitado=(v_publish and v_adult),estado='activo',actualizado_en=now()
      where id=v_member.id
      returning id into v_id;

      insert into public.kombax_verificacion_eventos(
        perfil_directo_id,actor_perfil_id,evento,detalle
      )
      select v_d.id,v_d.perfil_id,'member_promoted',
             jsonb_build_object('social_id',v_id,'identity_social_id',v_d.origen_identidad_social_id)
      where not exists(
        select 1 from public.kombax_verificacion_eventos e
        where e.perfil_directo_id=v_d.id and e.evento='member_promoted'
      );
    elsif v_direct.id is not null then
      update public.kombax_social_perfiles
      set nombre_publico=v_d.nombre_publico,bio=v_d.descripcion,
          avatar_path=v_d.avatar_path,banner_path=v_d.banner_path,
          verificado=true,visible=true,publicar_habilitado=v_publish,
          contacto_habilitado=(v_publish and v_adult),estado='activo',actualizado_en=now()
      where id=v_direct.id
      returning id into v_id;
    else
      insert into public.kombax_social_perfiles(
        sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,
        verificado,visible,publicar_habilitado,contacto_habilitado,estado
      ) values(
        'perfil_directo',v_d.id,v_d.slug,v_d.nombre_publico,v_d.descripcion,v_d.avatar_path,v_d.banner_path,
        true,true,v_publish,(v_publish and v_adult),'activo'
      ) returning id into v_id;
    end if;
  else
    if v_d.origen_identidad_social_id is not null and v_i.id is not null then
      if v_direct.id is not null and v_member.id is not null and v_direct.id<>v_member.id then
        raise exception 'KOMBAX_COMPETITOR_SOCIAL_DUPLICATE';
      end if;
      if v_direct.id is not null then
        update public.kombax_social_perfiles
        set sujeto_tipo='miembro',perfil_directo_id=null,identidad_social_id=v_i.id,
            slug=v_i.slug,nombre_publico=v_i.nombre_publico,verificado=false,
            visible=v_i.estado='activa',publicar_habilitado=v_i.estado='activa',
            contacto_habilitado=v_i.estado='activa' and v_adult,
            estado=case v_i.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end,
            actualizado_en=now()
        where id=v_direct.id
        returning id into v_id;
      elsif v_member.id is not null then
        update public.kombax_social_perfiles
        set verificado=false,visible=v_i.estado='activa',publicar_habilitado=v_i.estado='activa',
            contacto_habilitado=v_i.estado='activa' and v_adult,
            estado=case v_i.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end,
            actualizado_en=now()
        where id=v_member.id
        returning id into v_id;
      else
        insert into public.kombax_social_perfiles(
          sujeto_tipo,identidad_social_id,slug,nombre_publico,verificado,visible,
          publicar_habilitado,contacto_habilitado,estado
        ) values(
          'miembro',v_i.id,v_i.slug,v_i.nombre_publico,false,v_i.estado='activa',
          v_i.estado='activa',v_i.estado='activa' and v_adult,
          case v_i.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end
        ) returning id into v_id;
      end if;
    elsif v_direct.id is not null then
      update public.kombax_social_perfiles
      set verificado=false,visible=false,publicar_habilitado=false,contacto_habilitado=false,
          estado='limitado',actualizado_en=now()
      where id=v_direct.id
      returning id into v_id;
    end if;
  end if;

  return v_id;
end $$;
revoke all on function public.app_kombax_social_switch_competitor_v072(uuid) from public,anon,authenticated;

-- 4) Lectura del álbum: la identidad verificada pública se puede ver sin plan.
create or replace function public.app_kombax_album_v072(p_perfil_directo_id uuid)
returns table(id uuid,tipo text,storage_path text,mime_type text,bytes bigint,width integer,height integer,duration_seconds numeric,"position" integer,estado text,creado_en timestamptz)
language plpgsql
stable
security definer
set search_path=public,auth
as $$
declare
  v_public boolean;
  v_official boolean;
  v_manage boolean;
begin
  select d.publico,
         (d.workflow_estado in ('verified','limited') and d.estado='activo' and d.verificacion_estado='verificado'),
         public.app_kombax_puede_gestionar_perfil_v070(d.id,'read')
  into v_public,v_official,v_manage
  from public.perfiles_kombax_directos d
  where d.id=p_perfil_directo_id;

  if not found then raise exception 'KOMBAX_PROFILE_NOT_FOUND'; end if;
  if not v_manage and not public.app_kombax_es_moderador_v041() and not(v_public and v_official) then
    raise exception 'KOMBAX_PROFILE_NOT_PUBLIC';
  end if;

  return query
  select m.id,m.tipo,m.storage_path,m.mime_type,m.bytes,m.width,m.height,
         m.duration_seconds,m.position,m.estado,m.creado_en
  from public.kombax_perfil_media m
  where m.perfil_directo_id=p_perfil_directo_id
    and (v_manage or public.app_kombax_es_moderador_v041() or m.estado='active')
  order by case m.tipo when 'avatar' then 0 when 'banner' then 1 when 'photo' then 2 else 3 end,
           m.position,m.creado_en;
end $$;
revoke all on function public.app_kombax_album_v072(uuid) from public,anon;
grant execute on function public.app_kombax_album_v072(uuid) to authenticated;

-- 5) Multimedia básica del perfil no exige suscripción. Los límites de foto/vídeo siguen en app_kombax_media_guard_v043,
--    por lo que un perfil sin plan no adquiere álbum premium por esta corrección.
create or replace function public.app_kombax_media_mutate_v072(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_existing public.app_mutation_requests;
  v_result jsonb;
  v_profile uuid;
  v_id uuid;
  v_media public.kombax_perfil_media;
  v_type text;
  v_path text;
  v_mime text;
  v_bytes bigint;
  v_duration numeric;
  v_state text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,null,p_operation);
  end if;

  if p_operation='kombax.media.add' then
    v_profile:=public.app_kombax_uuid_or_null_v070(v_payload->>'perfil_directo_id');
    if not public.app_kombax_puede_gestionar_perfil_v070(v_profile,'edit') then raise exception 'KOMBAX_PROFILE_MEDIA_FORBIDDEN'; end if;
    if not exists(
      select 1 from public.perfiles_kombax_directos d
      where d.id=v_profile
        and d.workflow_estado in ('verified','limited')
        and d.verificacion_estado='verificado'
        and d.estado='activo'
    ) then raise exception 'KOMBAX_PROFILE_VERIFIED_REQUIRED'; end if;

    v_type:=lower(btrim(coalesce(v_payload->>'tipo','')));
    if v_type not in ('avatar','banner','photo','video') then raise exception 'KOMBAX_MEDIA_TYPE_INVALID'; end if;
    v_path:=btrim(coalesce(v_payload->>'storage_path',''));
    if v_path='' or split_part(v_path,'/',1)<>v_uid::text or split_part(v_path,'/',2)<>v_profile::text then raise exception 'KOMBAX_MEDIA_PATH_INVALID'; end if;
    v_mime:=lower(btrim(coalesce(v_payload->>'mime_type','')));
    begin v_bytes:=(v_payload->>'bytes')::bigint; exception when others then raise exception 'KOMBAX_MEDIA_SIZE_INVALID'; end;
    begin v_duration:=nullif(v_payload->>'duration_seconds','')::numeric; exception when others then raise exception 'KOMBAX_MEDIA_DURATION_INVALID'; end;
    if v_type='video' and (v_duration is null or v_duration<=0 or v_duration>60.2) then raise exception 'KOMBAX_VIDEO_MAX_60_SECONDS'; end if;

    if v_type in ('avatar','banner') then
      update public.kombax_perfil_media
      set estado='removed',actualizado_en=now()
      where perfil_directo_id=v_profile and tipo=v_type and estado in ('active','pending_review');
    end if;

    insert into public.kombax_perfil_media(
      perfil_directo_id,tipo,storage_path,mime_type,bytes,width,height,duration_seconds,position,estado,creado_por
    ) values(
      v_profile,v_type,v_path,v_mime,v_bytes,
      nullif(v_payload->>'width','')::integer,nullif(v_payload->>'height','')::integer,
      v_duration,coalesce(nullif(v_payload->>'position','')::integer,0),'active',v_uid
    ) returning * into v_media;

    if v_type='avatar' then
      update public.perfiles_kombax_directos set avatar_path=v_path,actualizado_en=now() where id=v_profile;
    elsif v_type='banner' then
      update public.perfiles_kombax_directos set banner_path=v_path,actualizado_en=now() where id=v_profile;
    end if;
    v_result:=to_jsonb(v_media);

  elsif p_operation='kombax.media.remove' then
    v_id:=public.app_kombax_uuid_or_null_v070(v_payload->>'media_id');
    select m.* into v_media from public.kombax_perfil_media m where m.id=v_id for update;
    if v_media.id is null or (
      not public.app_kombax_puede_gestionar_perfil_v070(v_media.perfil_directo_id,'edit')
      and not public.app_kombax_es_moderador_v041()
    ) then raise exception 'KOMBAX_MEDIA_NOT_FOUND'; end if;
    update public.kombax_perfil_media set estado='removed',actualizado_en=now() where id=v_id returning * into v_media;
    update public.perfiles_kombax_directos
    set avatar_path=case when avatar_path=v_media.storage_path then null else avatar_path end,
        banner_path=case when banner_path=v_media.storage_path then null else banner_path end,
        actualizado_en=now()
    where id=v_media.perfil_directo_id;
    v_result:=jsonb_build_object('id',v_media.id,'storage_path',v_media.storage_path,'estado',v_media.estado);

  elsif p_operation='kombax.media.moderate' then
    if not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED'; end if;
    v_id:=public.app_kombax_uuid_or_null_v070(v_payload->>'media_id');
    v_state:=lower(btrim(coalesce(v_payload->>'estado','')));
    if v_state not in ('active','hidden','removed') then raise exception 'KOMBAX_MEDIA_STATE_INVALID'; end if;
    update public.kombax_perfil_media
    set estado=v_state,moderacion_motivo=left(nullif(btrim(v_payload->>'motivo'),''),1000),actualizado_en=now()
    where id=v_id returning * into v_media;
    if v_media.id is null then raise exception 'KOMBAX_MEDIA_NOT_FOUND'; end if;
    v_result:=jsonb_build_object('id',v_media.id,'estado',v_media.estado);
  else
    raise exception 'KOMBAX_MEDIA_OPERATION_NOT_ALLOWED';
  end if;

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_media_mutate_v072(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_media_mutate_v072(text,jsonb,uuid) to authenticated;

-- 6) Backfill no destructivo: solo alinea perfiles directos ya verificados.
update public.perfiles_kombax_directos
set publico=true,actualizado_en=now()
where tipo in ('competidor','marca','federacion','profesional','media')
  and verificacion_estado='verificado'
  and workflow_estado in ('verified','limited')
  and estado='activo'
  and publico is distinct from true;

notify pgrst,'reload schema';
commit;
