-- KOMBAX RC13 build 20033 · 060 · códigos permanentes de acceso por club.
-- Diseño aprobado:
-- - dos códigos reutilizables por club: alumnado/familias y equipo;
-- - códigos numéricos cortos (4-5 dígitos), 5 dígitos por defecto;
-- - el QR/enlace aporta el contexto de club (?club=<slug>), por lo que el código solo debe ser único dentro del club;
-- - Gestor y Coordinación pueden consultar, definir y rotar ambos códigos;
-- - cambiar un código invalida inmediatamente el anterior;
-- - alumnado/familias entra por el flujo ordinario de alta (16+ autónomo; menores por tutor/club);
-- - el código de equipo NUNCA concede rol: crea una solicitud pendiente de revisión;
-- - solo el Gestor puede conceder Coordinación; nunca se concede Dirección mediante código.
-- DEPRECATED_MAIN_OPERATION: invitacion.crear
-- DEPRECATED_MAIN_OPERATION: invitacion.aceptar
begin;

-- 059 queda descontinuada: revocamos invitaciones individuales pendientes y sus RPC públicas.
update public.invitaciones_club
   set estado='revocada'
 where estado='pendiente'
   and tipo_invitacion in ('alumno','equipo');

do $$ begin
  if to_regprocedure('public.app_kombax_invitacion_crear_v059(uuid,text,text,text,text,integer)') is not null then
    revoke all on function public.app_kombax_invitacion_crear_v059(uuid,text,text,text,text,integer) from public,anon,authenticated;
  end if;
  if to_regprocedure('public.app_kombax_invitacion_validar_v059(text,text)') is not null then
    revoke all on function public.app_kombax_invitacion_validar_v059(text,text) from public,anon,authenticated;
  end if;
  if to_regprocedure('public.app_kombax_invitacion_aceptar_equipo_v059(text)') is not null then
    revoke all on function public.app_kombax_invitacion_aceptar_equipo_v059(text) from public,anon,authenticated;
  end if;
  if to_regprocedure('public.app_kombax_invitacion_email_payload_v059(uuid)') is not null then
    revoke all on function public.app_kombax_invitacion_email_payload_v059(uuid) from public,anon,authenticated;
  end if;
  if to_regprocedure('public.app_kombax_invitacion_email_estado_v059(uuid,text,text)') is not null then
    revoke all on function public.app_kombax_invitacion_email_estado_v059(uuid,text,text) from public,anon,authenticated;
  end if;
end $$;

create table if not exists public.kombax_codigos_acceso_club(
  club_id uuid primary key references public.clubes(id) on delete cascade,
  codigo_alumnos text not null,
  codigo_equipo text not null,
  alumnos_version integer not null default 1,
  equipo_version integer not null default 1,
  alumnos_actualizado_por uuid references auth.users(id),
  equipo_actualizado_por uuid references auth.users(id),
  alumnos_actualizado_en timestamptz not null default now(),
  equipo_actualizado_en timestamptz not null default now(),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  constraint kombax_codigos_alumnos_formato_v060 check(codigo_alumnos ~ '^[0-9]{4,5}$'),
  constraint kombax_codigos_equipo_formato_v060 check(codigo_equipo ~ '^[0-9]{4,5}$'),
  constraint kombax_codigos_distintos_v060 check(codigo_alumnos<>codigo_equipo)
);
alter table public.kombax_codigos_acceso_club enable row level security;
revoke all on public.kombax_codigos_acceso_club from public,anon,authenticated;

create table if not exists public.kombax_codigos_acceso_audit(
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  tipo text not null check(tipo in ('alumnos','equipo')),
  codigo_anterior text,
  codigo_nuevo text not null,
  actor_id uuid not null references auth.users(id),
  creado_en timestamptz not null default now()
);
alter table public.kombax_codigos_acceso_audit enable row level security;
revoke all on public.kombax_codigos_acceso_audit from public,anon,authenticated;

create table if not exists public.kombax_solicitudes_equipo_club(
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  perfil_id uuid not null references auth.users(id) on delete cascade,
  email text,
  estado text not null default 'pendiente' check(estado in ('pendiente','aprobada','rechazada','cancelada')),
  codigo_version integer not null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  revisado_en timestamptz,
  revisado_por uuid references auth.users(id),
  rol_asignado public.rol_club,
  coordinacion boolean not null default false,
  nota_revision text,
  unique(club_id,perfil_id)
);
alter table public.kombax_solicitudes_equipo_club enable row level security;
revoke all on public.kombax_solicitudes_equipo_club from public,anon,authenticated;

-- El usuario puede consultar su propia solicitud; Gestor/Coordinación las del club.
drop policy if exists kombax_solicitud_equipo_select_v060 on public.kombax_solicitudes_equipo_club;
create policy kombax_solicitud_equipo_select_v060 on public.kombax_solicitudes_equipo_club
for select to authenticated using(
  perfil_id=auth.uid() or public.app_puede_gestionar_perfil_club_v035(club_id)
);
grant select on public.kombax_solicitudes_equipo_club to authenticated;

create or replace function public.app_kombax_codigo_numero_v060()
returns text language sql volatile security definer set search_path=public as $$
  select lpad(mod((hashtextextended(gen_random_uuid()::text,0) & 2147483647),100000)::text,5,'0');
$$;
revoke all on function public.app_kombax_codigo_numero_v060() from public,anon,authenticated;

-- Inicializa códigos para clubes actuales. Evita que ambos códigos coincidan.
do $$ declare r record; a text; e text; begin
  for r in select c.id from public.clubes c where c.activo loop
    if not exists(select 1 from public.kombax_codigos_acceso_club k where k.club_id=r.id) then
      a:=public.app_kombax_codigo_numero_v060();
      loop e:=public.app_kombax_codigo_numero_v060(); exit when e<>a; end loop;
      insert into public.kombax_codigos_acceso_club(club_id,codigo_alumnos,codigo_equipo)
      values(r.id,a,e);
    end if;
  end loop;
end $$;

-- Los clubes nuevos reciben códigos automáticamente.
create or replace function public.app_kombax_codigos_club_init_v060()
returns trigger language plpgsql security definer set search_path=public as $$
declare a text; e text;
begin
  a:=public.app_kombax_codigo_numero_v060();
  loop e:=public.app_kombax_codigo_numero_v060(); exit when e<>a; end loop;
  insert into public.kombax_codigos_acceso_club(club_id,codigo_alumnos,codigo_equipo)
  values(new.id,a,e) on conflict(club_id) do nothing;
  return new;
end $$;
revoke all on function public.app_kombax_codigos_club_init_v060() from public,anon,authenticated;
drop trigger if exists kombax_codigos_club_init_v060 on public.clubes;
create trigger kombax_codigos_club_init_v060 after insert on public.clubes
for each row execute function public.app_kombax_codigos_club_init_v060();

create or replace function public.app_kombax_codigos_club_v060(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare k public.kombax_codigos_acceso_club;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_puede_gestionar_perfil_club_v035(p_club_id) then raise exception 'No tienes permiso para gestionar los códigos del club';end if;
  select * into k from public.kombax_codigos_acceso_club where club_id=p_club_id;
  if k.club_id is null then raise exception 'Códigos del club no disponibles';end if;
  return jsonb_build_object(
    'club_id',k.club_id,
    'alumnos',jsonb_build_object('codigo',k.codigo_alumnos,'version',k.alumnos_version,'actualizado_en',k.alumnos_actualizado_en),
    'equipo',jsonb_build_object('codigo',k.codigo_equipo,'version',k.equipo_version,'actualizado_en',k.equipo_actualizado_en)
  );
end $$;
revoke all on function public.app_kombax_codigos_club_v060(uuid) from public,anon;
grant execute on function public.app_kombax_codigos_club_v060(uuid) to authenticated;

create or replace function public.app_kombax_codigo_rotar_v060(p_club_id uuid,p_tipo text,p_codigo text default null)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare t text:=lower(trim(coalesce(p_tipo,''))); c text:=trim(coalesce(p_codigo,'')); k public.kombax_codigos_acceso_club; old_code text; tries integer:=0;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_puede_gestionar_perfil_club_v035(p_club_id) then raise exception 'Solo Gestor o Coordinación pueden cambiar los códigos del club';end if;
  if t not in ('alumnos','equipo') then raise exception 'Tipo de código no válido';end if;
  select * into k from public.kombax_codigos_acceso_club where club_id=p_club_id for update;
  if k.club_id is null then raise exception 'Códigos del club no disponibles';end if;

  if c='' then
    loop
      tries:=tries+1;c:=public.app_kombax_codigo_numero_v060();
      exit when (t='alumnos' and c<>k.codigo_equipo and c<>k.codigo_alumnos) or (t='equipo' and c<>k.codigo_alumnos and c<>k.codigo_equipo);
      if tries>30 then raise exception 'No se pudo generar un código distinto';end if;
    end loop;
  elsif c !~ '^[0-9]{4,5}$' then
    raise exception 'El código debe tener 4 o 5 dígitos numéricos';
  end if;

  if t='alumnos' then
    if c=k.codigo_equipo then raise exception 'El código de alumnos no puede coincidir con el de equipo';end if;
    old_code:=k.codigo_alumnos;
    update public.kombax_codigos_acceso_club set codigo_alumnos=c,alumnos_version=alumnos_version+1,alumnos_actualizado_por=auth.uid(),alumnos_actualizado_en=now(),actualizado_en=now() where club_id=p_club_id returning * into k;
  else
    if c=k.codigo_alumnos then raise exception 'El código de equipo no puede coincidir con el de alumnos';end if;
    old_code:=k.codigo_equipo;
    update public.kombax_codigos_acceso_club set codigo_equipo=c,equipo_version=equipo_version+1,equipo_actualizado_por=auth.uid(),equipo_actualizado_en=now(),actualizado_en=now() where club_id=p_club_id returning * into k;
  end if;
  insert into public.kombax_codigos_acceso_audit(club_id,tipo,codigo_anterior,codigo_nuevo,actor_id) values(p_club_id,t,old_code,c,auth.uid());
  return jsonb_build_object('club_id',p_club_id,'tipo',t,'codigo',c,'version',case when t='alumnos' then k.alumnos_version else k.equipo_version end,'actualizado_en',now());
end $$;
revoke all on function public.app_kombax_codigo_rotar_v060(uuid,text,text) from public,anon;
grant execute on function public.app_kombax_codigo_rotar_v060(uuid,text,text) to authenticated;

-- Validación pública: el contexto del QR/enlace identifica el club.
create or replace function public.app_kombax_codigo_validar_v060(p_club_slug text,p_tipo text,p_codigo text)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare t text:=lower(trim(coalesce(p_tipo,''))); c text:=trim(coalesce(p_codigo,'')); club public.clubes; k public.kombax_codigos_acceso_club; ok boolean:=false; ver integer;
begin
  if t not in ('alumnos','equipo') or c !~ '^[0-9]{4,5}$' then return jsonb_build_object('valid',false);end if;
  select * into club from public.clubes x where lower(x.slug)=lower(trim(coalesce(p_club_slug,''))) and x.activo limit 1;
  if club.id is null then return jsonb_build_object('valid',false);end if;
  select * into k from public.kombax_codigos_acceso_club where club_id=club.id;
  if k.club_id is null then return jsonb_build_object('valid',false);end if;
  if t='alumnos' then ok:=c=k.codigo_alumnos;ver:=k.alumnos_version;else ok:=c=k.codigo_equipo;ver:=k.equipo_version;end if;
  if not ok then return jsonb_build_object('valid',false);end if;
  return jsonb_build_object('valid',true,'tipo',t,'club_id',club.id,'club_slug',club.slug,'club_nombre',club.nombre,'version',ver);
end $$;
revoke all on function public.app_kombax_codigo_validar_v060(text,text,text) from public;
grant execute on function public.app_kombax_codigo_validar_v060(text,text,text) to anon,authenticated;

-- Código de equipo: solo crea/renueva una solicitud; jamás membresía o rol.
create or replace function public.app_kombax_equipo_solicitar_v060(p_club_slug text,p_codigo text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare uid uuid:=auth.uid(); chk jsonb; cid uuid; ver integer; row public.kombax_solicitudes_equipo_club; mail text:=lower(coalesce(auth.jwt()->>'email',''));
begin
  if uid is null then raise exception 'AUTH_REQUIRED';end if;
  chk:=public.app_kombax_codigo_validar_v060(p_club_slug,'equipo',p_codigo);
  if coalesce((chk->>'valid')::boolean,false) is not true then raise exception 'Código de equipo no válido';end if;
  cid:=(chk->>'club_id')::uuid;ver:=(chk->>'version')::integer;
  if exists(select 1 from public.miembros_club m where m.club_id=cid and m.perfil_id=uid and m.activo) then raise exception 'Tu cuenta ya pertenece a este club';end if;
  insert into public.perfiles(id,nombre,apellidos)
  values(uid,coalesce(nullif(auth.jwt()->'user_metadata'->>'nombre',''),split_part(mail,'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos',''))
  on conflict(id) do nothing;
  insert into public.kombax_solicitudes_equipo_club(club_id,perfil_id,email,estado,codigo_version,creado_en,actualizado_en,revisado_en,revisado_por,rol_asignado,coordinacion,nota_revision)
  values(cid,uid,mail,'pendiente',ver,now(),now(),null,null,null,false,null)
  on conflict(club_id,perfil_id) do update set email=excluded.email,estado='pendiente',codigo_version=excluded.codigo_version,actualizado_en=now(),revisado_en=null,revisado_por=null,rol_asignado=null,coordinacion=false,nota_revision=null
  returning * into row;
  return jsonb_build_object('id',row.id,'club_id',row.club_id,'club_slug',chk->>'club_slug','club_nombre',chk->>'club_nombre','estado',row.estado,'creado_en',row.creado_en);
end $$;
revoke all on function public.app_kombax_equipo_solicitar_v060(text,text) from public,anon;
grant execute on function public.app_kombax_equipo_solicitar_v060(text,text) to authenticated;

create or replace function public.app_kombax_solicitudes_equipo_v060(p_club_id uuid)
returns table(id uuid,perfil_id uuid,email text,nombre text,apellidos text,estado text,creado_en timestamptz,revisado_en timestamptz,rol_asignado text,coordinacion boolean)
language sql stable security definer set search_path=public,auth as $$
  select s.id,s.perfil_id,s.email,p.nombre,p.apellidos,s.estado,s.creado_en,s.revisado_en,s.rol_asignado::text,s.coordinacion
  from public.kombax_solicitudes_equipo_club s
  left join public.perfiles p on p.id=s.perfil_id
  where s.club_id=p_club_id and public.app_puede_gestionar_perfil_club_v035(p_club_id)
  order by case s.estado when 'pendiente' then 0 else 1 end,s.creado_en desc;
$$;
revoke all on function public.app_kombax_solicitudes_equipo_v060(uuid) from public,anon;
grant execute on function public.app_kombax_solicitudes_equipo_v060(uuid) to authenticated;

create or replace function public.app_kombax_solicitud_equipo_resolver_v060(p_solicitud_id uuid,p_estado text,p_rol text default null,p_nota text default null)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare s public.kombax_solicitudes_equipo_club; st text:=lower(trim(coalesce(p_estado,''))); role text:=lower(trim(coalesce(p_rol,''))); db_role public.rol_club; is_coord boolean:=false;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  select * into s from public.kombax_solicitudes_equipo_club where id=p_solicitud_id for update;
  if s.id is null then raise exception 'Solicitud no encontrada';end if;
  if not public.app_puede_gestionar_perfil_club_v035(s.club_id) then raise exception 'No tienes permiso para revisar esta solicitud';end if;
  if st not in ('aprobada','rechazada') then raise exception 'Estado no válido';end if;
  if s.estado<>'pendiente' then raise exception 'La solicitud ya ha sido revisada';end if;

  if st='aprobada' then
    if role not in ('coordinacion','secretaria','economia','comunicacion','monitor') then raise exception 'Selecciona un rol de equipo válido';end if;
    is_coord:=role='coordinacion';
    if is_coord and not public.tiene_rol_club(s.club_id,'direccion') then raise exception 'Solo el Gestor puede conceder Coordinación';end if;
    if is_coord then
      insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion) values
        (s.club_id,s.perfil_id,'secretaria',true,true),(s.club_id,s.perfil_id,'economia',true,true),(s.club_id,s.perfil_id,'comunicacion',true,true)
      on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=true;
      db_role:='secretaria';
    else
      db_role:=role::public.rol_club;
      insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
      values(s.club_id,s.perfil_id,db_role,true,false)
      on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=false;
    end if;
  end if;

  update public.kombax_solicitudes_equipo_club
     set estado=st,revisado_en=now(),revisado_por=auth.uid(),rol_asignado=case when st='aprobada' then db_role else null end,coordinacion=case when st='aprobada' then is_coord else false end,nota_revision=left(nullif(trim(coalesce(p_nota,'')),''),1000),actualizado_en=now()
   where id=s.id;
  return jsonb_build_object('id',s.id,'club_id',s.club_id,'perfil_id',s.perfil_id,'estado',st,'rol',case when is_coord then 'coordinacion' when st='aprobada' then db_role::text else null end);
end $$;
revoke all on function public.app_kombax_solicitud_equipo_resolver_v060(uuid,text,text,text) from public,anon;
grant execute on function public.app_kombax_solicitud_equipo_resolver_v060(uuid,text,text,text) to authenticated;

-- Sustituye el interceptor 059. Cuando hay código de alumnos, 060 valida por club y
-- lo elimina antes de delegar, de modo que 059 no intenta consumir una invitación individual.
do $$ begin
  if to_regprocedure('public.app_mutate_v160_pre_access_codes_060(text,jsonb,uuid)') is null
     and to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_access_codes_060;
  end if;
end $$;
revoke all on function public.app_mutate_v160_pre_access_codes_060(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare payload jsonb:=coalesce(p_payload,'{}'::jsonb); code text:=trim(coalesce(payload->>'invite_code','')); slug text:=trim(coalesce(payload->>'club_slug','')); chk jsonb; result jsonb;
begin
  if p_operation in ('invitacion.crear','invitacion.aceptar') then
    raise exception 'INVITATION_FLOW_DEPRECATED: usa los códigos permanentes del club';
  end if;
  if p_operation='cuenta.registrar' and code<>'' then
    chk:=public.app_kombax_codigo_validar_v060(slug,'alumnos',code);
    if coalesce((chk->>'valid')::boolean,false) is not true then raise exception 'Código de alumnos/familias no válido para este club';end if;
    payload:=jsonb_set(payload,'{invite_code}','null'::jsonb,true);
    result:=public.app_mutate_v160_pre_access_codes_060(p_operation,payload,p_request_id);
    result:=jsonb_set(result,'{data,club_access_code}',jsonb_build_object('tipo','alumnos','version',(chk->>'version')::integer),true);
    update public.app_mutation_requests set result=result where request_id=p_request_id;
    return result;
  end if;
  return public.app_mutate_v160_pre_access_codes_060(p_operation,p_payload,p_request_id);
end $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- El contrato operativo deja de anunciar las invitaciones individuales históricas.
do $$ begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_access_codes_060(uuid)') is null
     and to_regprocedure('public.app_runtime_contract_v160(uuid)') is not null then
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_access_codes_060;
  end if;
end $$;
revoke all on function public.app_runtime_contract_v160_pre_access_codes_060(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare base jsonb; ops jsonb;
begin
  base:=public.app_runtime_contract_v160_pre_access_codes_060(p_club_id);
  select coalesce(jsonb_agg(value),'[]'::jsonb) into ops
  from jsonb_array_elements(coalesce(base->'operations','[]'::jsonb)) value
  where value<>to_jsonb('invitacion.crear'::text) and value<>to_jsonb('invitacion.aceptar'::text);
  return jsonb_set(base,'{operations}',ops,true)||jsonb_build_object('club_access_codes_rpc','app_kombax_codigo_validar_v060','club_access_codes_schema',60);
end $$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

-- Contrato visible para Platform Admin.
create or replace function public.app_kombax_release_contract_v056()
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  return jsonb_build_object('ok',true,'build',20033,
    'identity_context',to_regprocedure('public.app_kombax_social_mis_perfiles_v051(uuid)') is not null,
    'public_profiles',to_regprocedure('public.app_kombax_perfil_publico_v052(uuid)') is not null,
    'social_media',to_regprocedure('public.app_kombax_social_mutate_v053(text,jsonb,uuid)') is not null,
    'showcase_actions',to_regprocedure('public.app_kombax_showcase_mutate_v054(text,jsonb,uuid)') is not null,
    'platform_admin',to_regprocedure('public.app_kombax_platform_dashboard_v055()') is not null,
    'club_access_codes',to_regprocedure('public.app_kombax_codigo_validar_v060(text,text,text)') is not null,
    'team_access_requests',to_regprocedure('public.app_kombax_equipo_solicitar_v060(text,text)') is not null,
    'tables',jsonb_build_object('club_access_codes',to_regclass('public.kombax_codigos_acceso_club') is not null,'team_access_requests',to_regclass('public.kombax_solicitudes_equipo_club') is not null,'social_media',to_regclass('public.kombax_social_media') is not null,'showcase_saved',to_regclass('public.kombax_showcase_guardados') is not null,'team_permissions',to_regclass('public.kombax_club_team_permissions') is not null,'actor_audit',to_regclass('public.kombax_actor_audit') is not null,'platform_admins',to_regclass('public.kombax_platform_admins') is not null));
end $$;
revoke all on function public.app_kombax_release_contract_v056() from public,anon;
grant execute on function public.app_kombax_release_contract_v056() to authenticated;

notify pgrst,'reload schema';
commit;
