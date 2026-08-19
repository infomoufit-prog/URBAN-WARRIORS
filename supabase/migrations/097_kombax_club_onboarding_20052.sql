-- KOMBAX RC13 build 20052 · Club onboarding real.
-- Convierte una solicitud Club verificada en un tenant real y permite alta directa por Administrador KOMBAX.
begin;

alter table public.kombax_solicitudes_alta
  add column if not exists club_id uuid references public.clubes(id) on delete set null;

create index if not exists idx_kombax_solicitudes_alta_club_v097
  on public.kombax_solicitudes_alta(club_id)
  where club_id is not null;

-- Núcleo interno: crea un Club real y aprovecha los triggers ya certificados de public.clubes
-- (perfil público, Social, comunidad, legal, códigos y prefijo de recibos).
create or replace function public.app_kombax_create_club_core_v097(
  p_manager_perfil_id uuid,
  p_nombre_publico text,
  p_datos_publicos jsonb,
  p_datos_verificacion jsonb,
  p_actor_perfil_id uuid
) returns uuid
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_public jsonb:=coalesce(p_datos_publicos,'{}'::jsonb);
  v_verify jsonb:=coalesce(p_datos_verificacion,'{}'::jsonb);
  v_nombre text:=btrim(coalesce(p_nombre_publico,''));
  v_slug text;
  v_club uuid;
  v_disc text;
  v_order smallint:=0;
begin
  if p_manager_perfil_id is null or not exists(select 1 from public.perfiles p where p.id=p_manager_perfil_id) then
    raise exception 'KOMBAX_CLUB_MANAGER_PROFILE_REQUIRED';
  end if;
  if p_actor_perfil_id is null or not exists(select 1 from public.perfiles p where p.id=p_actor_perfil_id) then
    raise exception 'KOMBAX_CLUB_ACTOR_PROFILE_REQUIRED';
  end if;
  if char_length(v_nombre)<2 or char_length(v_nombre)>160 then raise exception 'KOMBAX_CLUB_NAME_INVALID'; end if;
  if exists(select 1 from public.clubes c where lower(btrim(c.nombre))=lower(v_nombre)) then raise exception 'KOMBAX_CLUB_ALREADY_EXISTS'; end if;

  v_slug:=public.app_kombax_slug_v043(v_nombre);
  if char_length(coalesce(v_slug,''))<2 then raise exception 'KOMBAX_CLUB_SLUG_INVALID'; end if;
  if exists(select 1 from public.clubes c where c.slug=v_slug) then
    v_slug:=left(v_slug,50)||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,8);
  end if;

  insert into public.clubes(
    nombre,slug,lema,cif,telefono,email,direccion,web,activo,theme_id,branding_actualizado_por,branding_actualizado_en
  ) values(
    v_nombre,
    v_slug,
    left(nullif(btrim(v_public->>'lema'),''),180),
    left(nullif(btrim(coalesce(v_verify->>'cif',v_verify->>'tax_id')),''),40),
    left(nullif(btrim(v_verify->>'telefono'),''),40),
    left(nullif(btrim(coalesce(v_verify->>'email_oficial',v_verify->>'email')),''),254),
    left(nullif(btrim(v_verify->>'direccion'),''),300),
    nullif(btrim(v_public->>'web_publica'),''),
    true,'combat-dark',p_actor_perfil_id,now()
  ) returning id into v_club;

  insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
  values(v_club,p_manager_perfil_id,'direccion',true,true)
  on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=true;

  update public.perfiles_club_publicos pc set
    nombre_publico=v_nombre,
    lema=left(nullif(btrim(v_public->>'lema'),''),180),
    descripcion=left(nullif(btrim(v_public->>'descripcion'),''),1600),
    ciudad=left(nullif(btrim(v_public->>'ciudad'),''),120),
    provincia=left(nullif(btrim(v_public->>'provincia'),''),120),
    pais=left(coalesce(nullif(btrim(v_public->>'pais'),''),'España'),120),
    contacto_publico=left(nullif(btrim(v_public->>'contacto_publico'),''),180),
    web_publica=nullif(btrim(v_public->>'web_publica'),''),
    instagram=left(nullif(btrim(v_public->>'instagram'),''),180),
    tiktok=left(nullif(btrim(v_public->>'tiktok'),''),180),
    youtube=left(nullif(btrim(v_public->>'youtube'),''),180),
    visible=true,moderacion_oculta=false,actualizado_por=p_actor_perfil_id,actualizado_en=now()
  where pc.club_id=v_club;

  if jsonb_typeof(v_public->'disciplinas')='array' then
    for v_disc in
      select distinct btrim(value)
      from jsonb_array_elements_text(v_public->'disciplinas')
      where btrim(value)<>''
      limit 12
    loop
      insert into public.disciplinas(club_id,nombre,activa,orden)
      values(v_club,left(v_disc,120),true,v_order)
      on conflict(club_id,nombre) do nothing;
      v_order:=v_order+1;
    end loop;
  end if;

  insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
  values(p_actor_perfil_id,v_club,'kombax.club.provision','club',v_club,
    jsonb_build_object('manager_perfil_id',p_manager_perfil_id,'slug',v_slug,'source','club_onboarding_v097'));

  return v_club;
end;
$$;
revoke all on function public.app_kombax_create_club_core_v097(uuid,text,jsonb,jsonb,uuid) from public,anon,authenticated;

-- Al verificar una solicitud Club, se provisiona exactamente una vez.
create or replace function public.app_kombax_club_application_provision_v097()
returns trigger
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_club uuid;
  v_validation jsonb;
begin
  if new.tipo<>'club' then return new; end if;

  if new.estado='verified' and old.estado is distinct from 'verified' and new.club_id is null then
    if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
    v_validation:=public.app_kombax_application_validate_v072(new.id);
    v_club:=public.app_kombax_create_club_core_v097(new.perfil_id,new.nombre_publico,new.datos_publicos,new.datos_verificacion,auth.uid());
    new.club_id:=v_club;
    insert into public.kombax_verificacion_eventos(solicitud_id,perfil_directo_id,actor_perfil_id,evento,detalle)
    values(new.id,null,auth.uid(),'club_provisioned',jsonb_build_object('club_id',v_club,'validation',v_validation));
  elsif new.club_id is not null and new.estado in ('suspended','rejected') and old.estado is distinct from new.estado then
    update public.clubes set activo=false,actualizado_en=now() where id=new.club_id;
  elsif new.club_id is not null and new.estado='verified' and old.estado is distinct from 'verified' then
    update public.clubes set activo=true,actualizado_en=now() where id=new.club_id;
  end if;
  return new;
end;
$$;
revoke all on function public.app_kombax_club_application_provision_v097() from public,anon,authenticated;

drop trigger if exists trg_kombax_club_application_provision_v097 on public.kombax_solicitudes_alta;
create trigger trg_kombax_club_application_provision_v097
before update of estado on public.kombax_solicitudes_alta
for each row execute function public.app_kombax_club_application_provision_v097();

-- Clubes que la cuenta autenticada puede gestionar; solo datos públicos/operativos mínimos.
create or replace function public.app_kombax_mis_clubes_v097()
returns table(
  club_id uuid,slug text,nombre_publico text,lema text,descripcion text,ciudad text,provincia text,pais text,
  logo_url text,portada_url text,activo boolean,rol text,coordinacion boolean,social_profile_id uuid,disciplinas text[]
)
language sql
stable
security definer
set search_path=public,auth
as $$
  select c.id,c.slug,coalesce(pc.nombre_publico,c.nombre),pc.lema,pc.descripcion,pc.ciudad,pc.provincia,pc.pais,
    coalesce(pc.logo_url,c.logo_url),coalesce(pc.portada_url,c.portada_url),c.activo,m.rol::text,m.coordinacion,sp.id,
    coalesce((select array_agg(d.nombre order by d.orden,d.nombre) from public.disciplinas d where d.club_id=c.id and d.activa),'{}'::text[])
  from public.miembros_club m
  join public.clubes c on c.id=m.club_id
  left join public.perfiles_club_publicos pc on pc.club_id=c.id
  left join public.kombax_social_perfiles sp on sp.sujeto_tipo='club' and sp.club_id=c.id
  where auth.uid() is not null and m.perfil_id=auth.uid() and m.activo and (m.rol='direccion' or m.coordinacion)
  order by coalesce(pc.nombre_publico,c.nombre),c.id;
$$;
revoke all on function public.app_kombax_mis_clubes_v097() from public,anon;
grant execute on function public.app_kombax_mis_clubes_v097() to authenticated;

-- Alta directa por Administrador KOMBAX. El gestor debe tener ya una cuenta KOMBAX.
create or replace function public.app_kombax_platform_mutate_v097(p_operation text,p_payload jsonb,p_request_id uuid)
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
  v_manager uuid;
  v_manager_email text:=lower(btrim(coalesce(p_payload->>'manager_email','')));
  v_nombre text:=btrim(coalesce(p_payload->>'nombre_publico',''));
  v_public jsonb:=coalesce(p_payload->'datos_publicos','{}'::jsonb);
  v_verify jsonb:=coalesce(p_payload->'datos_verificacion','{}'::jsonb);
  v_club uuid;
  v_request uuid;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  if p_operation<>'kombax.platform.club.create' then raise exception 'PLATFORM_OPERATION_NOT_ALLOWED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation);
  end if;

  if v_manager_email='' then raise exception 'KOMBAX_CLUB_MANAGER_EMAIL_REQUIRED'; end if;
  select u.id into v_manager from auth.users u where lower(u.email)=v_manager_email and u.deleted_at is null order by u.created_at limit 1;
  if v_manager is null or not exists(select 1 from public.perfiles p where p.id=v_manager) then raise exception 'KOMBAX_CLUB_MANAGER_ACCOUNT_NOT_FOUND'; end if;
  if exists(select 1 from public.kombax_solicitudes_alta s where s.perfil_id=v_manager and s.tipo='club' and s.estado in ('draft','submitted','under_review','needs_information')) then
    raise exception 'KOMBAX_CLUB_MANAGER_HAS_OPEN_APPLICATION';
  end if;

  v_club:=public.app_kombax_create_club_core_v097(v_manager,v_nombre,v_public,v_verify,v_uid);

  insert into public.kombax_solicitudes_alta(
    perfil_id,tipo,perfil_directo_id,club_id,nombre_publico,datos_publicos,datos_verificacion,estado,
    schema_version,declaracion_aceptada,declaracion_en,requisitos_version,enviado_en,revisado_por,revisado_en
  ) values(
    v_manager,'club',null,v_club,v_nombre,v_public,v_verify,'verified',2,true,now(),'admin-provision-v1',now(),v_uid,now()
  ) returning id into v_request;

  insert into public.kombax_verificacion_eventos(solicitud_id,perfil_directo_id,actor_perfil_id,evento,detalle)
  values(v_request,null,v_uid,'club_admin_provisioned',jsonb_build_object('club_id',v_club,'manager_perfil_id',v_manager));

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,
    'data',jsonb_build_object('club_id',v_club,'solicitud_id',v_request,'manager_perfil_id',v_manager));
  update public.app_mutation_requests set club_id=v_club,result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end;
$$;
revoke all on function public.app_kombax_platform_mutate_v097(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_platform_mutate_v097(text,jsonb,uuid) to authenticated;

commit;
