-- KOMBAX RC13 build 20044 · 071 · planes, capacidades y separación verificación/suscripción.
-- Pagar/activar servicio no verifica identidad; verificar identidad no concede automáticamente capacidades premium.

begin;

insert into public.kombax_capacidades(clave,descripcion,sensible) values
  ('profile.card.share','Tarjeta pública compartible del perfil oficial',false),
  ('profile.qr','QR público del perfil oficial',false),
  ('competitor.profile.advanced','Ficha deportiva avanzada de Competidor',false),
  ('competitor.record.manage','Gestión de trayectoria y resultados declarados',true),
  ('competitor.opportunities.receive','Recepción voluntaria de oportunidades deportivas',true),
  ('competitor.analytics.read','Analítica básica del perfil Competidor',true),
  ('federation.clubs.directory','Directorio institucional de clubes afiliados',true),
  ('federation.calendar.publish','Publicación de calendario federativo',true),
  ('federation.documents.publish','Publicación de documentos y reglamentos',true),
  ('federation.results.official','Publicación futura de resultados oficiales',true),
  ('brand.profile.corporate','Perfil corporativo avanzado de Marca',false),
  ('brand.opportunities.publish','Publicación futura de oportunidades para Competidores/Clubes',true),
  ('brand.analytics.read','Analítica comercial agregada de Marca',true)
on conflict(clave) do nothing;

create table if not exists public.kombax_planes(
  codigo text primary key check(codigo ~ '^[a-z][a-z0-9_.-]{2,80}$'),
  perfil_tipo text not null check(perfil_tipo in ('club','competidor','marca','federacion')),
  nombre text not null check(char_length(nombre) between 3 and 120),
  modalidad text not null check(modalidad in ('subscription','institutional','manual')),
  requiere_checkout boolean not null default false,
  descripcion text not null,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
create table if not exists public.kombax_plan_capacidades(
  plan_codigo text not null references public.kombax_planes(codigo) on delete cascade,
  capacidad_clave text not null references public.kombax_capacidades(clave) on delete restrict,
  primary key(plan_codigo,capacidad_clave)
);
create table if not exists public.kombax_plan_limites(
  plan_codigo text not null references public.kombax_planes(codigo) on delete cascade,
  recurso text not null check(recurso in ('album.photos','album.videos','showcase.items','opportunities.active')),
  limite integer not null check(limite>=0 and limite<=10000),
  primary key(plan_codigo,recurso)
);
alter table public.kombax_planes enable row level security;
alter table public.kombax_plan_capacidades enable row level security;
alter table public.kombax_plan_limites enable row level security;
revoke all on public.kombax_planes,public.kombax_plan_capacidades,public.kombax_plan_limites from public,anon,authenticated;

insert into public.kombax_planes(codigo,perfil_tipo,nombre,modalidad,requiere_checkout,descripcion) values
  ('competidor_premium','competidor','KOMBAX Competidor','subscription',true,'Perfil deportivo oficial con trayectoria, multimedia y oportunidades.'),
  ('marca_profesional','marca','KOMBAX Marca','subscription',true,'Presencia corporativa oficial, Showcase y herramientas de colaboración.'),
  ('federacion_institucional','federacion','KOMBAX Institutional','institutional',false,'Perfil institucional con calendario, clubes, documentos y resultados oficiales futuros.'),
  ('club_saas','club','KOMBAX Club','subscription',true,'Gestión integral de club y presencia oficial KOMBAX.')
on conflict(codigo) do update set nombre=excluded.nombre,modalidad=excluded.modalidad,requiere_checkout=excluded.requiere_checkout,descripcion=excluded.descripcion,activo=true,actualizado_en=now();

insert into public.kombax_plan_capacidades(plan_codigo,capacidad_clave) values
  ('competidor_premium','social.read'),('competidor_premium','social.publish'),('competidor_premium','contact.request'),
  ('competidor_premium','profile.album.publish'),('competidor_premium','profile.verified.badge'),('competidor_premium','profile.card.share'),('competidor_premium','profile.qr'),
  ('competidor_premium','competitor.profile.advanced'),('competidor_premium','competitor.record.manage'),('competidor_premium','competitor.opportunities.receive'),('competidor_premium','competitor.analytics.read'),
  ('marca_profesional','social.read'),('marca_profesional','social.publish'),('marca_profesional','contact.request'),
  ('marca_profesional','profile.album.publish'),('marca_profesional','profile.verified.badge'),('marca_profesional','profile.card.share'),('marca_profesional','profile.qr'),
  ('marca_profesional','showcase.publish'),('marca_profesional','brand.profile.corporate'),('marca_profesional','brand.opportunities.publish'),('marca_profesional','brand.analytics.read'),
  ('federacion_institucional','social.read'),('federacion_institucional','social.publish'),('federacion_institucional','contact.request'),
  ('federacion_institucional','profile.album.publish'),('federacion_institucional','profile.verified.badge'),('federacion_institucional','profile.card.share'),('federacion_institucional','profile.qr'),
  ('federacion_institucional','federation.clubs.directory'),('federacion_institucional','federation.calendar.publish'),('federacion_institucional','federation.documents.publish'),('federacion_institucional','federation.results.official')
on conflict do nothing;

insert into public.kombax_plan_limites(plan_codigo,recurso,limite) values
  ('competidor_premium','album.photos',10),('competidor_premium','album.videos',3),
  ('marca_profesional','album.photos',15),('marca_profesional','album.videos',5),('marca_profesional','showcase.items',30),('marca_profesional','opportunities.active',5),
  ('federacion_institucional','album.photos',15),('federacion_institucional','album.videos',5),('federacion_institucional','opportunities.active',10),
  ('club_saas','album.photos',10),('club_saas','album.videos',3),('club_saas','showcase.items',15)
on conflict(plan_codigo,recurso) do update set limite=excluded.limite;

-- Un único servicio abierto por sujeto. Históricos cancelados pueden coexistir.
create unique index if not exists uq_kombax_suscripcion_abierta_v071
  on public.kombax_suscripciones(sujeto_tipo,sujeto_id)
  where estado in ('prueba','activa','pausada');

create or replace function public.app_kombax_perfil_servicio_v071(p_perfil_directo_id uuid)
returns jsonb language sql stable security definer set search_path=public as $$
  select coalesce((
    select jsonb_build_object(
      'suscripcion_id',s.id,'estado',s.estado,'plan_codigo',s.modalidad,'inicia_en',s.inicia_en,'termina_en',s.termina_en,
      'activo',s.estado in ('prueba','activa') and (s.inicia_en is null or s.inicia_en<=now()) and (s.termina_en is null or s.termina_en>now())
    )
    from public.kombax_suscripciones s
    join public.kombax_planes p on p.codigo=s.modalidad and p.activo
    where s.sujeto_tipo='perfil_directo' and s.sujeto_id=p_perfil_directo_id
      and s.estado in ('prueba','activa','pausada')
    order by s.actualizado_en desc,s.creado_en desc limit 1
  ),jsonb_build_object('estado','inactiva','plan_codigo',null,'activo',false));
$$;
revoke all on function public.app_kombax_perfil_servicio_v071(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_servicio_v071(uuid) to authenticated;

create or replace function public.app_kombax_perfil_servicio_activo_v071(p_perfil_directo_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce((public.app_kombax_perfil_servicio_v071(p_perfil_directo_id)->>'activo')::boolean,false);
$$;
revoke all on function public.app_kombax_perfil_servicio_activo_v071(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_servicio_activo_v071(uuid) to authenticated;

create or replace function public.app_kombax_plan_limite_v071(p_perfil_directo_id uuid,p_recurso text)
returns integer language sql stable security definer set search_path=public as $$
  select coalesce((
    select l.limite
    from public.kombax_suscripciones s
    join public.kombax_planes p on p.codigo=s.modalidad and p.activo
    join public.kombax_plan_limites l on l.plan_codigo=p.codigo and l.recurso=p_recurso
    where s.sujeto_tipo='perfil_directo' and s.sujeto_id=p_perfil_directo_id
      and s.estado in ('prueba','activa')
      and (s.inicia_en is null or s.inicia_en<=now()) and (s.termina_en is null or s.termina_en>now())
    order by s.actualizado_en desc limit 1
  ),0);
$$;
revoke all on function public.app_kombax_plan_limite_v071(uuid,text) from public,anon;
grant execute on function public.app_kombax_plan_limite_v071(uuid,text) to authenticated;

create or replace function public.app_kombax_reconcile_entitlements_v071(p_perfil_directo_id uuid,p_actor uuid default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_plan text;v_service boolean:=false;v_verified boolean:=false;
begin
  select d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited') and d.estado='activo'
    into v_verified from public.perfiles_kombax_directos d where d.id=p_perfil_directo_id;
  if not found then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;

  select s.modalidad,
    s.estado in ('prueba','activa') and (s.inicia_en is null or s.inicia_en<=now()) and (s.termina_en is null or s.termina_en>now())
  into v_plan,v_service
  from public.kombax_suscripciones s join public.kombax_planes p on p.codigo=s.modalidad and p.activo
  where s.sujeto_tipo='perfil_directo' and s.sujeto_id=p_perfil_directo_id and s.estado in ('prueba','activa','pausada')
  order by s.actualizado_en desc limit 1;

  update public.kombax_entitlements set activa=false,termina_en=coalesce(termina_en,greatest(clock_timestamp(),inicia_en+interval '1 microsecond'))
  where sujeto_tipo='perfil_directo' and sujeto_id=p_perfil_directo_id and origen='suscripcion' and activa;

  if v_verified and coalesce(v_service,false) and v_plan is not null then
    insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,inicia_en,asignada_por)
    select 'perfil_directo',p_perfil_directo_id,pc.capacidad_clave,true,'suscripcion',now(),p_actor
    from public.kombax_plan_capacidades pc where pc.plan_codigo=v_plan
    on conflict do nothing;
  end if;

  update public.perfiles_kombax_directos set
    publico=(v_verified and coalesce(v_service,false)),actualizado_en=now()
  where id=p_perfil_directo_id;
end $$;
revoke all on function public.app_kombax_reconcile_entitlements_v071(uuid,uuid) from public,anon,authenticated;

-- Los grants heredados de 043 dejan de equivaler a «verificado = premium».
update public.kombax_entitlements e set activa=false,termina_en=coalesce(e.termina_en,greatest(clock_timestamp(),e.inicia_en+interval '1 microsecond'))
where e.sujeto_tipo='perfil_directo' and e.activa and e.origen='manual'
  and e.capacidad_clave in ('social.read','social.publish','contact.request','profile.album.publish','showcase.publish')
  and exists(select 1 from public.perfiles_kombax_directos d where d.id=e.sujeto_id);

-- La insignia directa exige identidad verificada + servicio oficial activo.
create or replace function public.app_kombax_badge_tipo_v069(p_social_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select case
    when sp.sujeto_tipo='club' and sp.club_id is not null then 'club'
    when sp.sujeto_tipo='perfil_directo'
      and d.tipo in ('competidor','marca','federacion')
      and d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited') and d.estado='activo'
      and public.app_kombax_perfil_servicio_activo_v071(d.id)
      then d.tipo
    else null end
  from public.kombax_social_perfiles sp
  left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  where sp.id=p_social_id;
$$;

create or replace function public.app_kombax_social_badge_guard_v069()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_valid boolean:=false;
begin
  if new.sujeto_tipo='club' then
    v_valid:=new.club_id is not null and exists(select 1 from public.clubes c where c.id=new.club_id);
  elsif new.sujeto_tipo='perfil_directo' and new.perfil_directo_id is not null then
    v_valid:=exists(
      select 1 from public.perfiles_kombax_directos d
      where d.id=new.perfil_directo_id and d.tipo in ('competidor','marca','federacion')
        and d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited') and d.estado='activo'
        and public.app_kombax_perfil_servicio_activo_v071(d.id)
    );
  end if;
  new.verificado:=coalesce(v_valid,false);return new;
end $$;
revoke all on function public.app_kombax_social_badge_guard_v069() from public,anon,authenticated;

create or replace function public.app_kombax_social_sync_directo_v041()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_service boolean:=false;v_badge boolean:=false;
begin
  v_service:=public.app_kombax_perfil_servicio_activo_v071(new.id);
  v_badge:=new.tipo in ('competidor','marca','federacion') and new.verificacion_estado='verificado'
    and new.workflow_estado in ('verified','limited') and new.estado='activo' and v_service;
  insert into public.kombax_social_perfiles(
    sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,verificado,visible,publicar_habilitado,contacto_habilitado,estado
  ) values(
    'perfil_directo',new.id,new.slug,new.nombre_publico,new.descripcion,new.avatar_path,new.banner_path,v_badge,
    new.publico and v_service and new.estado='activo',new.publico and v_service and new.estado='activo' and new.verificacion_estado='verificado',
    new.publico and v_service and new.estado='activo' and new.verificacion_estado='verificado',
    case when new.estado='activo' and v_service then 'activo' when new.estado='suspendido' then 'suspendido' when new.estado='cerrado' then 'cerrado' else 'limitado' end
  )
  on conflict(perfil_directo_id) where sujeto_tipo='perfil_directo' do update set
    slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,avatar_path=excluded.avatar_path,banner_path=excluded.banner_path,
    verificado=excluded.verificado,visible=excluded.visible,publicar_habilitado=excluded.publicar_habilitado,contacto_habilitado=excluded.contacto_habilitado,estado=excluded.estado,actualizado_en=now();
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_directo_v041() from public,anon,authenticated;

-- Límites de multimedia dependen del plan, con techo técnico de 15 fotos / 5 vídeos.
create or replace function public.app_kombax_media_guard_v043()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_count integer;v_limit integer;
begin
  if not exists(select 1 from public.perfiles_kombax_directos where id=new.perfil_directo_id) then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;
  if auth.uid() is not null and not public.app_kombax_puede_gestionar_perfil_v070(new.perfil_directo_id,'edit') and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MEDIA_FORBIDDEN';end if;
  if new.tipo='photo' and new.estado in ('active','pending_review') then
    v_limit:=least(public.app_kombax_plan_limite_v071(new.perfil_directo_id,'album.photos'),15);
    if v_limit<=0 then raise exception 'KOMBAX_PROFILE_PLAN_REQUIRED';end if;
    select count(*) into v_count from public.kombax_perfil_media where perfil_directo_id=new.perfil_directo_id and tipo='photo' and estado in ('active','pending_review') and id<>new.id;
    if v_count>=v_limit then raise exception 'KOMBAX_ALBUM_PHOTO_LIMIT_%',v_limit;end if;
  elsif new.tipo='video' and new.estado in ('active','pending_review') then
    v_limit:=least(public.app_kombax_plan_limite_v071(new.perfil_directo_id,'album.videos'),5);
    if v_limit<=0 then raise exception 'KOMBAX_PROFILE_PLAN_REQUIRED';end if;
    select count(*) into v_count from public.kombax_perfil_media where perfil_directo_id=new.perfil_directo_id and tipo='video' and estado in ('active','pending_review') and id<>new.id;
    if v_count>=v_limit then raise exception 'KOMBAX_ALBUM_VIDEO_LIMIT_%',v_limit;end if;
  end if;
  new.actualizado_en:=now();return new;
end $$;
revoke all on function public.app_kombax_media_guard_v043() from public,anon,authenticated;

create or replace function public.app_kombax_subscription_mutate_v071(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_profile uuid;v_plan text;v_state text;v_type text;v_sub public.kombax_suscripciones;v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  if p_operation<>'kombax.subscription.set' then raise exception 'KOMBAX_SUBSCRIPTION_OPERATION_NOT_ALLOWED';end if;
  begin v_profile:=(p_payload->>'perfil_directo_id')::uuid;exception when others then raise exception 'KOMBAX_PROFILE_ID_INVALID';end;
  v_plan:=lower(btrim(coalesce(p_payload->>'plan_codigo','')));v_state:=lower(btrim(coalesce(p_payload->>'estado','activa')));
  if v_state not in ('inactiva','prueba','activa','pausada','cancelada') then raise exception 'KOMBAX_SUBSCRIPTION_STATE_INVALID';end if;
  select tipo into v_type from public.perfiles_kombax_directos where id=v_profile;
  if v_type is null then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;
  if v_state not in ('inactiva','cancelada') then
    if not exists(select 1 from public.kombax_planes p where p.codigo=v_plan and p.perfil_tipo=v_type and p.activo) then raise exception 'KOMBAX_PLAN_PROFILE_MISMATCH';end if;
    update public.kombax_suscripciones set estado='cancelada',termina_en=coalesce(termina_en,greatest(clock_timestamp(),inicia_en+interval '1 microsecond')),actualizado_en=now()
    where sujeto_tipo='perfil_directo' and sujeto_id=v_profile and estado in ('prueba','activa','pausada');
    insert into public.kombax_suscripciones(sujeto_tipo,sujeto_id,estado,modalidad,proveedor,referencia_externa,inicia_en,termina_en)
    values('perfil_directo',v_profile,v_state,v_plan,coalesce(nullif(p_payload->>'proveedor',''),'manual'),nullif(p_payload->>'referencia_externa',''),
      coalesce(nullif(p_payload->>'inicia_en','')::timestamptz,now()),nullif(p_payload->>'termina_en','')::timestamptz)
    returning * into v_sub;
  else
    update public.kombax_suscripciones set estado=v_state,termina_en=coalesce(termina_en,greatest(clock_timestamp(),inicia_en+interval '1 microsecond')),actualizado_en=now()
    where sujeto_tipo='perfil_directo' and sujeto_id=v_profile and estado in ('prueba','activa','pausada') returning * into v_sub;
  end if;
  perform public.app_kombax_reconcile_entitlements_v071(v_profile,v_uid);
  insert into public.kombax_verificacion_eventos(perfil_directo_id,actor_perfil_id,evento,detalle)
  values(v_profile,v_uid,case when v_state in ('prueba','activa') then 'service_activated' else 'service_deactivated' end,
    jsonb_build_object('plan_codigo',nullif(v_plan,''),'estado',v_state));
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('perfil_directo_id',v_profile,'plan_codigo',nullif(v_plan,''),'estado',v_state));
  return v_result;
end $$;
revoke all on function public.app_kombax_subscription_mutate_v071(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_subscription_mutate_v071(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
