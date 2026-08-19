-- KOMBAX build 20028 · 051 · identidad social separada, actuar como Club y permisos de equipo.
-- Miembro ≠ perfil deportivo ≠ Competidor KOMBAX. Las acciones públicas conservan actor real.
begin;

alter table public.kombax_social_perfiles
  add column if not exists avatar_path text,
  add column if not exists banner_path text;
alter table public.identidades_sociales
  add column if not exists bio_publica text;

create table if not exists public.kombax_club_team_permissions(
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  permiso text not null check(permiso in ('social.act_as_club','profile.public.manage','showcase.manage','relations.manage','contacts.manage')),
  activo boolean not null default true,
  concedido_por uuid references public.perfiles(id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique(club_id,perfil_id,permiso)
);
create index if not exists idx_kombax_team_permissions_v051 on public.kombax_club_team_permissions(club_id,perfil_id,activo,permiso);
alter table public.kombax_club_team_permissions enable row level security;
revoke all on public.kombax_club_team_permissions from public,anon,authenticated;

create table if not exists public.kombax_actor_audit(
  id bigserial primary key,
  actor_perfil_id uuid not null references public.perfiles(id) on delete restrict,
  public_social_id uuid references public.kombax_social_perfiles(id) on delete set null,
  club_id uuid references public.clubes(id) on delete set null,
  accion text not null check(char_length(accion) between 3 and 120),
  objeto_tipo text,
  objeto_id uuid,
  detalle jsonb not null default '{}'::jsonb check(jsonb_typeof(detalle)='object'),
  creado_en timestamptz not null default now()
);
create index if not exists idx_kombax_actor_audit_v051 on public.kombax_actor_audit(club_id,creado_en desc,actor_perfil_id);
alter table public.kombax_actor_audit enable row level security;
revoke all on public.kombax_actor_audit from public,anon,authenticated;

-- Conserva los permisos que ya existían en 041/045, pero desde ahora son explícitos y editables.
insert into public.kombax_club_team_permissions(club_id,perfil_id,permiso,concedido_por)
select distinct m.club_id,m.perfil_id,p,null::uuid
from public.miembros_club m
cross join unnest(array['social.act_as_club','profile.public.manage','showcase.manage','relations.manage','contacts.manage']) p
where m.activo and (m.rol='direccion' or coalesce(m.coordinacion,false))
on conflict(club_id,perfil_id,permiso) do nothing;
insert into public.kombax_club_team_permissions(club_id,perfil_id,permiso,concedido_por)
select distinct m.club_id,m.perfil_id,'social.act_as_club',null::uuid
from public.miembros_club m
where m.activo and m.rol in ('secretaria','comunicacion')
on conflict(club_id,perfil_id,permiso) do nothing;

create or replace function public.app_kombax_club_permiso_v051(p_club_id uuid,p_permiso text)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select auth.uid() is not null and exists(
    select 1 from public.miembros_club m
    where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo
      and (
        m.rol='direccion' or coalesce(m.coordinacion,false)
        or exists(select 1 from public.kombax_club_team_permissions kp where kp.club_id=m.club_id and kp.perfil_id=m.perfil_id and kp.permiso=p_permiso and kp.activo)
      )
  );
$$;
revoke all on function public.app_kombax_club_permiso_v051(uuid,text) from public,anon;
grant execute on function public.app_kombax_club_permiso_v051(uuid,text) to authenticated;

create or replace function public.app_kombax_club_team_v051(p_club_id uuid)
returns table(perfil_id uuid,nombre text,rol text,coordinacion boolean,permisos text[])
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null or not public.app_kombax_club_permiso_v051(p_club_id,'profile.public.manage') then raise exception 'KOMBAX_CLUB_TEAM_FORBIDDEN';end if;
  return query
  select m.perfil_id,trim(concat_ws(' ',p.nombre,p.apellidos)),m.rol::text,coalesce(m.coordinacion,false),
    coalesce((select array_agg(k.permiso order by k.permiso) from public.kombax_club_team_permissions k where k.club_id=m.club_id and k.perfil_id=m.perfil_id and k.activo),array[]::text[])
  from public.miembros_club m join public.perfiles p on p.id=m.perfil_id
  where m.club_id=p_club_id and m.activo
  order by case when m.rol='direccion' then 0 when coalesce(m.coordinacion,false) then 1 else 2 end,p.nombre,p.apellidos;
end $$;
revoke all on function public.app_kombax_club_team_v051(uuid) from public,anon;
grant execute on function public.app_kombax_club_team_v051(uuid) to authenticated;

create or replace function public.app_kombax_social_tipo_v051(p_social_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select case
    when sp.sujeto_tipo='club' then 'club'
    when sp.sujeto_tipo='miembro' then 'miembro'
    else coalesce(d.tipo,'profesional') end
  from public.kombax_social_perfiles sp
  left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  where sp.id=p_social_id;
$$;
revoke all on function public.app_kombax_social_tipo_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_tipo_v051(uuid) to authenticated;

create or replace function public.app_kombax_social_puede_actuar_v051(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.publicar_habilitado and (
      (sp.sujeto_tipo='miembro' and exists(
        select 1 from public.identidades_sociales i
        where i.id=sp.identidad_social_id and i.perfil_id=auth.uid() and i.estado='activa'
          and public.app_kombax_capacidad_club_v041(i.club_origen_id,'social.publish')
      ))
      or (sp.sujeto_tipo='club' and public.app_kombax_capacidad_club_v041(sp.club_id,'social.publish') and public.app_kombax_club_permiso_v051(sp.club_id,'social.act_as_club'))
      or (sp.sujeto_tipo='perfil_directo' and exists(
        select 1 from public.perfiles_kombax_directos d
        where d.id=sp.perfil_directo_id and d.perfil_id=auth.uid() and d.estado='activo' and d.verificacion_estado='verificado' and d.social_activo
          and (
            d.tipo in ('marca','federacion')
            or (d.tipo in ('competidor','profesional') and exists(
              select 1 from public.identidades_sociales i join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
              where i.perfil_id=d.perfil_id and i.estado='activa' and s.fecha_nacimiento is not null and extract(year from age(current_date,s.fecha_nacimiento))>=14
            ))
          )
      ))
    )
  );
$$;
revoke all on function public.app_kombax_social_puede_actuar_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_actuar_v051(uuid) to authenticated;

-- Compatibilidad: todos los RPC 041–050 que preguntan "puede publicar" heredan la regla 20028.
create or replace function public.app_kombax_social_puede_publicar_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_social_puede_actuar_v051(p_social_id);
$$;
revoke all on function public.app_kombax_social_puede_publicar_v041(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_publicar_v041(uuid) to authenticated;

create or replace function public.app_kombax_social_contactable_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.contacto_habilitado and (
      sp.sujeto_tipo='club'
      or (sp.sujeto_tipo='miembro' and exists(
        select 1 from public.identidades_sociales i join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
        where i.id=sp.identidad_social_id and i.estado='activa' and s.fecha_nacimiento is not null and extract(year from age(current_date,s.fecha_nacimiento))>=18
      ))
      or (sp.sujeto_tipo='perfil_directo' and exists(
        select 1 from public.perfiles_kombax_directos d where d.id=sp.perfil_directo_id and d.estado='activo' and d.verificacion_estado='verificado' and d.social_activo and (
          d.tipo in ('marca','federacion') or (d.tipo in ('competidor','profesional') and exists(
            select 1 from public.identidades_sociales i join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
            where i.perfil_id=d.perfil_id and i.estado='activa' and s.fecha_nacimiento is not null and extract(year from age(current_date,s.fecha_nacimiento))>=18
          ))
        )
      ))
    )
  );
$$;
revoke all on function public.app_kombax_social_contactable_v041(uuid) from public,anon;
grant execute on function public.app_kombax_social_contactable_v041(uuid) to authenticated;

-- Sincroniza el perfil público del Club con su identidad KOMBAX Social.
create or replace function public.app_kombax_social_sync_club_public_v051()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  update public.kombax_social_perfiles set
    slug=new.slug,nombre_publico=new.nombre_publico,bio=new.descripcion,
    avatar_url=coalesce(new.logo_url,avatar_url),banner_url=coalesce(new.portada_url,banner_url),
    visible=new.visible and not new.moderacion_oculta,
    publicar_habilitado=new.visible and not new.moderacion_oculta,
    estado=case when new.visible and not new.moderacion_oculta then 'activo' else 'limitado' end,
    actualizado_en=now()
  where sujeto_tipo='club' and club_id=new.club_id;
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_club_public_v051() from public,anon,authenticated;
drop trigger if exists club_public_sync_kombax_social_v051 on public.perfiles_club_publicos;
create trigger club_public_sync_kombax_social_v051 after insert or update on public.perfiles_club_publicos for each row execute function public.app_kombax_social_sync_club_public_v051();

-- Backfill conservador: si el branding del Club es posterior a la última edición de su perfil público,
-- conserva el logo/portada más recientes del Club; si el perfil público fue editado después, respeta esa edición.
update public.kombax_social_perfiles sp set
  nombre_publico=pc.nombre_publico,bio=pc.descripcion,slug=pc.slug,
  avatar_url=coalesce(
    case when coalesce(c.branding_actualizado_en,c.actualizado_en,c.creado_en) >= coalesce(pc.actualizado_en,pc.creado_en) then c.logo_url else pc.logo_url end,
    pc.logo_url,c.logo_url,sp.avatar_url
  ),
  banner_url=coalesce(
    case when coalesce(c.branding_actualizado_en,c.actualizado_en,c.creado_en) >= coalesce(pc.actualizado_en,pc.creado_en) then c.portada_url else pc.portada_url end,
    pc.portada_url,c.portada_url,sp.banner_url
  ),
  visible=pc.visible and not pc.moderacion_oculta,
  publicar_habilitado=pc.visible and not pc.moderacion_oculta,
  estado=case when pc.visible and not pc.moderacion_oculta then 'activo' else 'limitado' end,
  actualizado_en=now()
from public.perfiles_club_publicos pc
join public.clubes c on c.id=pc.club_id
where sp.sujeto_tipo='club' and sp.club_id=pc.club_id;

-- El perfil directo mantiene avatar/banner propios y no se mezcla con el perfil deportivo del club.
create or replace function public.app_kombax_social_sync_directo_v041()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.kombax_social_perfiles(sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
  values('perfil_directo',new.id,new.slug,new.nombre_publico,new.descripcion,new.avatar_path,new.banner_path,new.verificacion_estado='verificado',new.publico and new.estado='activo',new.publico and new.estado='activo' and new.verificacion_estado='verificado',new.publico and new.estado='activo' and new.verificacion_estado='verificado',case when new.estado='activo' then 'activo' when new.estado='suspendido' then 'suspendido' when new.estado='cerrado' then 'cerrado' else 'limitado' end)
  on conflict(perfil_directo_id) where sujeto_tipo='perfil_directo' do update set
    slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,avatar_path=excluded.avatar_path,banner_path=excluded.banner_path,
    verificado=excluded.verificado,visible=excluded.visible,publicar_habilitado=excluded.publicar_habilitado,contacto_habilitado=excluded.contacto_habilitado,estado=excluded.estado,actualizado_en=now();
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_directo_v041() from public,anon,authenticated;

update public.kombax_social_perfiles sp set avatar_path=d.avatar_path,banner_path=d.banner_path,actualizado_en=now()
from public.perfiles_kombax_directos d where sp.sujeto_tipo='perfil_directo' and sp.perfil_directo_id=d.id;

create or replace function public.app_kombax_social_mis_perfiles_v051(p_club_id uuid default null)
returns table(id uuid,sujeto_tipo text,nombre_publico text,slug text,avatar_url text,avatar_path text,banner_url text,banner_path text,verificado boolean,contacto_habilitado boolean,perfil_directo_id uuid,perfil_tipo text,club_id uuid,club_nombre text,identity_label text)
language sql stable security definer set search_path=public,auth as $$
  select sp.id,sp.sujeto_tipo,sp.nombre_publico,sp.slug,sp.avatar_url,sp.avatar_path,sp.banner_url,sp.banner_path,sp.verificado,public.app_kombax_social_contactable_v041(sp.id),sp.perfil_directo_id,
    public.app_kombax_social_tipo_v051(sp.id),
    coalesce(sp.club_id,i.club_origen_id),c.nombre,
    case
      when sp.sujeto_tipo='club' then c.nombre||' · Club'
      when sp.sujeto_tipo='miembro' then sp.nombre_publico||' · Miembro'||case when c.nombre is not null then ' de '||c.nombre else '' end
      else sp.nombre_publico||' · '||initcap(public.app_kombax_social_tipo_v051(sp.id)) end
  from public.kombax_social_perfiles sp
  left join public.identidades_sociales i on i.id=sp.identidad_social_id
  left join public.clubes c on c.id=coalesce(sp.club_id,i.club_origen_id)
  where public.app_kombax_social_puede_actuar_v051(sp.id)
    and (p_club_id is null or sp.sujeto_tipo<>'club' or sp.club_id=p_club_id)
  order by case
    when p_club_id is not null and sp.sujeto_tipo='club' and sp.club_id=p_club_id then 0
    when sp.sujeto_tipo='miembro' then 1
    else 2 end,sp.nombre_publico;
$$;
revoke all on function public.app_kombax_social_mis_perfiles_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_mis_perfiles_v051(uuid) to authenticated;

create or replace function public.app_kombax_social_estado_v051(p_club_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_club_social uuid;v_identity public.identidades_sociales;v_socio public.socios;v_age integer;v_min integer:=14;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_club_id is not null and public.app_kombax_club_permiso_v051(p_club_id,'social.act_as_club') then
    select id into v_club_social from public.kombax_social_perfiles where sujeto_tipo='club' and club_id=p_club_id and visible and estado='activo';
    if v_club_social is not null then return jsonb_build_object('status','activa','eligible',true,'scope','club','social_profile_id',v_club_social,'reason','Puedes participar en KOMBAX Social utilizando la identidad pública del club.');end if;
  end if;
  select * into v_identity from public.identidades_sociales where perfil_id=auth.uid();
  if v_identity.id is not null then return jsonb_build_object('status',case when v_identity.estado='activa' then 'activa' else 'inactiva' end,'eligible',v_identity.estado='activa','scope','member','social_profile_id',(select id from public.kombax_social_perfiles where identidad_social_id=v_identity.id),'reason',case when v_identity.estado='activa' then 'Tu identidad Social de miembro está activa.' else 'Tu identidad Social está suspendida o cerrada.' end);end if;
  if p_club_id is null then return public.app_kombax_social_estado_v049(null);end if;
  select * into v_socio from public.socios where club_id=p_club_id and perfil_id=auth.uid() and estado='activo' order by creado_en desc limit 1;
  if v_socio.id is null then return jsonb_build_object('status','inactiva','eligible',false,'scope','member','reason','Tu cuenta no dispone todavía de una identidad Social de miembro en este club.');end if;
  if v_socio.fecha_nacimiento is null then return jsonb_build_object('status','inactiva','eligible',false,'scope','member','reason','El club debe verificar tu edad antes de activar KOMBAX Social.');end if;
  v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento))::integer;
  begin v_min:=public.app_edad_min_comunidad_general_v036(p_club_id);exception when others then v_min:=14;end;
  return jsonb_build_object('status','inactiva','eligible',v_age>=v_min,'scope','member','reason',case when v_age>=v_min then 'Puedes activar voluntariamente tu identidad Social de miembro.' else 'No cumples la edad mínima para KOMBAX Social.' end,'age_verified',true,'min_age',v_min);
end $$;
revoke all on function public.app_kombax_social_estado_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_estado_v051(uuid) to authenticated;

create or replace function public.app_kombax_identity_mutate_v051(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_club uuid;v_target uuid;v_perm text;v_active boolean;v_socio public.socios;v_identity public.identidades_sociales;v_name text;v_texto uuid;v_min integer:=14;v_age integer;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid;exception when others then raise exception 'KOMBAX_CLUB_ID_INVALID';end;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation);end if;

  if p_operation='kombax.identity.member.activate' then
    if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MEMBERSHIP_REQUIRED';end if;
    select * into v_socio from public.socios where club_id=v_club and perfil_id=v_uid and estado='activo' order by creado_en desc limit 1;
    if v_socio.id is null or v_socio.fecha_nacimiento is null then raise exception 'KOMBAX_SOCIAL_AGE_VERIFICATION_REQUIRED';end if;
    v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento))::integer;begin v_min:=public.app_edad_min_comunidad_general_v036(v_club);exception when others then v_min:=14;end;
    if v_age<v_min then raise exception 'KOMBAX_SOCIAL_MINIMUM_AGE';end if;
    if coalesce((v_payload->>'acepta_normas')::boolean,false) is not true or coalesce((v_payload->>'acepta_privacidad')::boolean,false) is not true then raise exception 'KOMBAX_SOCIAL_CONSENT_REQUIRED';end if;
    select coalesce(nullif(pd.apodo,''),trim(concat_ws(' ',v_socio.nombre,v_socio.apellidos))) into v_name from public.perfiles_deportivos pd where pd.club_id=v_club and pd.socio_id=v_socio.id;
    v_name:=coalesce(v_name,trim(concat_ws(' ',v_socio.nombre,v_socio.apellidos)));
    select id into v_texto from public.textos_legales where club_id=v_club and tipo='comunidad_general' and vigente order by creado_en desc limit 1;
    if v_texto is not null then
      insert into public.aceptaciones_legales(club_id,perfil_id,socio_id,texto_legal_id,tipo,version,aceptado,aceptado_en,revocado_en,user_agent)
      select v_club,v_uid,v_socio.id,v_texto,'comunidad_general',t.version,true,now(),null,left(coalesce(v_payload->>'user_agent',''),500) from public.textos_legales t where t.id=v_texto
      on conflict do nothing;
    end if;
    insert into public.identidades_sociales(perfil_id,club_origen_id,socio_origen_id,tipo,slug,nombre_publico,estado,version_normas,activada_en,actualizado_en)
    values(v_uid,v_club,v_socio.id,'miembro','miembro-'||replace(v_uid::text,'-',''),v_name,'activa','1.1.0',now(),now())
    on conflict(perfil_id) do update set club_origen_id=excluded.club_origen_id,socio_origen_id=excluded.socio_origen_id,nombre_publico=excluded.nombre_publico,estado='activa',version_normas='1.1.0',suspendida_en=null,suspension_motivo=null,actualizado_en=now()
    returning * into v_identity;
    v_result:=jsonb_build_object('identidad_social_id',v_identity.id,'status','activa');

  elsif p_operation='kombax.identity.member.profile.update' then
    select * into v_identity from public.identidades_sociales where perfil_id=v_uid;
    if v_identity.id is null or v_identity.estado<>'activa' then raise exception 'KOMBAX_MEMBER_SOCIAL_IDENTITY_REQUIRED';end if;
    if v_club is not null and v_identity.club_origen_id<>v_club then raise exception 'KOMBAX_MEMBER_SOCIAL_CLUB_MISMATCH';end if;
    if char_length(coalesce(v_payload->>'bio_publica',''))>800 then raise exception 'KOMBAX_MEMBER_SOCIAL_BIO_TOO_LONG';end if;
    update public.identidades_sociales set bio_publica=nullif(btrim(v_payload->>'bio_publica'),''),actualizado_en=now() where id=v_identity.id returning * into v_identity;
    update public.kombax_social_perfiles set bio=v_identity.bio_publica,actualizado_en=now() where sujeto_tipo='miembro' and identidad_social_id=v_identity.id;
    insert into public.kombax_actor_audit(actor_perfil_id,public_social_id,club_id,accion,objeto_tipo,objeto_id,detalle)
      select v_uid,sp.id,v_identity.club_origen_id,'social.member.profile.update','social_profile',sp.id,jsonb_build_object('bio_updated',true)
      from public.kombax_social_perfiles sp where sp.sujeto_tipo='miembro' and sp.identidad_social_id=v_identity.id;
    v_result:=jsonb_build_object('identidad_social_id',v_identity.id,'bio_publica',v_identity.bio_publica);

  elsif p_operation='kombax.club.permission.set' then
    if v_club is null or not exists(select 1 from public.miembros_club m where m.club_id=v_club and m.perfil_id=v_uid and m.activo and m.rol='direccion') then raise exception 'KOMBAX_CLUB_OWNER_REQUIRED';end if;
    begin v_target:=(v_payload->>'perfil_id')::uuid;exception when others then raise exception 'KOMBAX_TEAM_PROFILE_INVALID';end;
    if not exists(select 1 from public.miembros_club where club_id=v_club and perfil_id=v_target and activo) then raise exception 'KOMBAX_TEAM_MEMBER_REQUIRED';end if;
    v_perm:=lower(coalesce(v_payload->>'permiso',''));if v_perm not in ('social.act_as_club','profile.public.manage','showcase.manage','relations.manage','contacts.manage') then raise exception 'KOMBAX_TEAM_PERMISSION_INVALID';end if;
    v_active:=coalesce((v_payload->>'activo')::boolean,true);
    insert into public.kombax_club_team_permissions(club_id,perfil_id,permiso,activo,concedido_por,actualizado_en) values(v_club,v_target,v_perm,v_active,v_uid,now())
    on conflict(club_id,perfil_id,permiso) do update set activo=excluded.activo,concedido_por=excluded.concedido_por,actualizado_en=now();
    v_result:=jsonb_build_object('club_id',v_club,'perfil_id',v_target,'permiso',v_perm,'activo',v_active);
  else raise exception 'KOMBAX_IDENTITY_OPERATION_NOT_ALLOWED';end if;

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_identity_mutate_v051(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_identity_mutate_v051(text,jsonb,uuid) to authenticated;


-- Las relaciones dejan de interpretar un Miembro como Competidor.
create or replace function public.app_kombax_social_tipo_v045(p_social_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select public.app_kombax_social_tipo_v051(p_social_id);
$$;
revoke all on function public.app_kombax_social_tipo_v045(uuid) from public,anon,authenticated;
grant execute on function public.app_kombax_social_tipo_v045(uuid) to authenticated;

create or replace function public.app_kombax_contact_reason_allowed_v044(p_from uuid,p_to uuid,p_reason text)
returns boolean language plpgsql stable security definer set search_path=public as $$
declare at text:=public.app_kombax_social_tipo_v051(p_from);bt text:=public.app_kombax_social_tipo_v051(p_to);r text:=lower(coalesce(p_reason,''));
begin
  if at is null or bt is null then return false;end if;
  if at='miembro' or bt='miembro' then return r in ('entrenamiento','evento','informacion','otro');end if;
  if (at='club' and bt='competidor') or (at='competidor' and bt='club') then return r in ('evento','competicion','entrenamiento','informacion');end if;
  if (at='marca' and bt in ('club','competidor')) or (bt='marca' and at in ('club','competidor')) then return r in ('patrocinio','colaboracion','informacion');end if;
  if at='federacion' or bt='federacion' then return r in ('competicion','evento','informacion');end if;
  if at='profesional' or bt='profesional' then return r in ('colaboracion','evento','informacion');end if;
  return r in ('informacion','otro');
end $$;
revoke all on function public.app_kombax_contact_reason_allowed_v044(uuid,uuid,text) from public,anon;
grant execute on function public.app_kombax_contact_reason_allowed_v044(uuid,uuid,text) to authenticated;

notify pgrst,'reload schema';
commit;
