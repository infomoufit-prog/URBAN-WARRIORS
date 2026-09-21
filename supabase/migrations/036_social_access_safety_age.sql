-- Urban Warriors RC13 build 20018 · 036
-- Base de alta opcional para futura Comunidad General, autorregistro alumno 16+,
-- denuncia/bloqueo/moderación UGC. No crea todavía el feed social global.

begin;

-- --------------------------------------------------------------------------
-- 1. TEXTO ESPECÍFICO DE LA CAPA SOCIAL GENERAL (separado de Comunidad interna)
-- --------------------------------------------------------------------------
update public.textos_legales set vigente=false
where tipo='comunidad_general' and version<>'1.0.0' and vigente;
insert into public.textos_legales(club_id,tipo,version,cuerpo,vigente)
select c.id,'comunidad_general','1.0.0',
E'NORMAS DE COMUNIDAD GENERAL · BASE MVP\n\nLa Comunidad General es un servicio social opcional y separado de las funciones de gestión del club. Tener una cuenta de gestión de un club no activa automáticamente este servicio.\n\nAcceso. En esta fase solo puede activar el alta social una cuenta con rol de alumno, vinculada a un socio del club, con fecha de nacimiento verificada y que alcance la edad mínima configurada para esta capa social, que nunca será inferior a 14 años. Las cuentas de padre, madre o tutor no pueden activar esta capa social.\n\nContenido. Se permite contenido deportivo y de competición, incluidos entrenamientos y combates, siempre dentro de un contexto legítimo. No se permite acoso, amenazas, odio o discriminación, sexualización o explotación de menores, violencia ilícita, publicación de datos privados de terceros, suplantación, spam ni contenido ilegal.\n\nSeguridad. Cualquier usuario podrá denunciar contenido o perfiles y bloquear a otros usuarios. El club/plataforma podrá ocultar contenido, revisar denuncias y suspender el acceso social.\n\nPrivacidad. La identidad social es distinta del expediente administrativo del club. La fecha de nacimiento, email, teléfono, domicilio, documentación, finanzas y relaciones familiares no se publican en el perfil social.\n\nEsta versión prepara el modelo de acceso y seguridad. El feed general se habilitará en una fase posterior.',true
from public.clubes c
on conflict(club_id,tipo,version) do update set cuerpo=excluded.cuerpo,vigente=true;

-- Umbral configurable por tenant. RC13 fija un suelo de producto de 14 años,
-- pero evita enterrar el valor en frontend o en una única condición inmutable.
insert into public.config_club(club_id,clave,valor,descripcion)
select c.id,'edad_min_comunidad_general','14'::jsonb,'Edad mínima para activar la capa social general (mínimo de producto: 14)'
from public.clubes c
on conflict(club_id,clave) do nothing;

-- Lectura defensiva del umbral: una configuración dañada o manipulada nunca
-- debe romper el login/perfil ni rebajar el suelo de producto de 14 años.
create or replace function public.app_edad_min_comunidad_general_v036(p_club_id uuid)
returns integer
language plpgsql stable security definer set search_path=public,auth
as $$
declare v_raw text;v_age integer:=14;
begin
  select c.valor#>>'{}' into v_raw
  from public.config_club c
  where c.club_id=p_club_id and c.clave='edad_min_comunidad_general';
  if v_raw ~ '^[0-9]{1,3}$' then
    v_age:=v_raw::integer;
  end if;
  return greatest(14,least(99,coalesce(v_age,14)));
end
$$;
revoke all on function public.app_edad_min_comunidad_general_v036(uuid) from public,anon,authenticated;

-- Si en una fase posterior se crea otro tenant, hereda la plantilla social sin
-- convertir todavía esta RC en una experiencia multiclub visible.
create or replace function public.app_seed_comunidad_general_new_club_v036()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_cuerpo text;
begin
  select cuerpo into v_cuerpo from public.textos_legales
  where tipo='comunidad_general' and version='1.0.0' and vigente and club_id<>new.id
  order by creado_en,id limit 1;
  if v_cuerpo is not null then
    insert into public.textos_legales(club_id,tipo,version,cuerpo,vigente)
    values(new.id,'comunidad_general','1.0.0',v_cuerpo,true)
    on conflict(club_id,tipo,version) do update set cuerpo=excluded.cuerpo,vigente=true;
  end if;
  insert into public.config_club(club_id,clave,valor,descripcion)
  values(new.id,'edad_min_comunidad_general','14'::jsonb,'Edad mínima para activar la capa social general (mínimo de producto: 14)')
  on conflict(club_id,clave) do nothing;
  return new;
end
$$;
revoke all on function public.app_seed_comunidad_general_new_club_v036() from public,anon,authenticated;
drop trigger if exists clubes_seed_comunidad_general_v036 on public.clubes;
create trigger clubes_seed_comunidad_general_v036 after insert on public.clubes
for each row execute function public.app_seed_comunidad_general_new_club_v036();

-- --------------------------------------------------------------------------
-- 2. ALTA / IDENTIDAD SOCIAL OPCIONAL DEL MIEMBRO
-- Esta tabla representa solo la identidad social de un miembro en esta fase.
-- Competidor independiente, club, federación, marca y tienda conservarán sus
-- propios modelos y se normalizarán mediante la capa pública de 035; no se
-- fuerzan aquí en una tabla genérica.
-- --------------------------------------------------------------------------
create table if not exists public.identidades_sociales (
  id uuid primary key default gen_random_uuid(),
  perfil_id uuid not null unique references public.perfiles(id) on delete cascade,
  club_origen_id uuid not null references public.clubes(id) on delete restrict,
  -- El socio puede desaparecer del registro operativo sin destruir por ello la
  -- identidad social histórica. El club de origen se conserva por separado.
  socio_origen_id uuid references public.socios(id) on delete set null,
  tipo text not null default 'miembro' check(tipo='miembro'),
  slug text not null unique,
  nombre_publico text not null,
  estado text not null default 'activa' check(estado in ('activa','suspendida','cerrada')),
  version_normas text not null,
  activada_en timestamptz not null default now(),
  suspendida_en timestamptz,
  suspension_motivo text,
  actualizado_en timestamptz not null default now(),
  check(slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  check(char_length(nombre_publico) between 1 and 160),
  check(char_length(coalesce(suspension_motivo,''))<=1000)
);
create index if not exists idx_identidades_sociales_estado_tipo_v036 on public.identidades_sociales(estado,tipo,club_origen_id);
alter table public.identidades_sociales enable row level security;
revoke all on public.identidades_sociales from public,anon,authenticated;

-- Auditoría separada de los cambios de estado social. Una suspensión no debe
-- quedar como un simple UPDATE sin trazabilidad del moderador y el motivo.
create table if not exists public.moderacion_accesos_sociales (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  identidad_social_id uuid not null references public.identidades_sociales(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  moderado_por uuid not null references public.perfiles(id) on delete restrict,
  estado_anterior text not null check(estado_anterior in ('activa','suspendida','cerrada')),
  estado_nuevo text not null check(estado_nuevo in ('activa','suspendida','cerrada')),
  motivo text not null,
  creado_en timestamptz not null default now(),
  check(estado_anterior<>estado_nuevo),
  check(char_length(trim(motivo)) between 3 and 1000)
);
create index if not exists idx_moderacion_accesos_sociales_perfil_v036
  on public.moderacion_accesos_sociales(club_id,perfil_id,creado_en desc);
alter table public.moderacion_accesos_sociales enable row level security;
revoke all on public.moderacion_accesos_sociales from public,anon,authenticated;

create table if not exists public.bloqueos_comunidad (
  id uuid primary key default gen_random_uuid(),
  club_contexto_id uuid not null references public.clubes(id) on delete cascade,
  bloqueador_perfil_id uuid not null references public.perfiles(id) on delete cascade,
  bloqueado_perfil_id uuid not null references public.perfiles(id) on delete cascade,
  creado_en timestamptz not null default now(),
  unique(club_contexto_id,bloqueador_perfil_id,bloqueado_perfil_id),
  check(bloqueador_perfil_id<>bloqueado_perfil_id)
);
create index if not exists idx_bloqueos_comunidad_bloqueador_v036 on public.bloqueos_comunidad(bloqueador_perfil_id,creado_en desc);
alter table public.bloqueos_comunidad enable row level security;
revoke all on public.bloqueos_comunidad from public,anon,authenticated;

create table if not exists public.reportes_comunidad (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  reportado_por uuid not null references public.perfiles(id) on delete cascade,
  ambito text not null default 'club' check(ambito in ('club','general')),
  objetivo_tipo text not null check(objetivo_tipo in ('publicacion','perfil')),
  objetivo_id uuid not null,
  motivo text not null check(motivo in ('acoso','odio_discriminacion','violencia','sexual_menores','privacidad','spam','suplantacion','otro')),
  detalle text,
  estado text not null default 'pendiente' check(estado in ('pendiente','en_revision','resuelta','descartada')),
  revisado_por uuid references public.perfiles(id) on delete set null,
  resolucion text,
  creado_en timestamptz not null default now(),
  revisado_en timestamptz,
  check(char_length(coalesce(detalle,''))<=1500),
  check(char_length(coalesce(resolucion,''))<=1500)
);
create unique index if not exists uq_reporte_pendiente_objetivo_v036
  on public.reportes_comunidad(reportado_por,ambito,objetivo_tipo,objetivo_id) where estado in ('pendiente','en_revision');
create index if not exists idx_reportes_comunidad_club_estado_v036 on public.reportes_comunidad(club_id,estado,creado_en desc);
alter table public.reportes_comunidad enable row level security;
revoke all on public.reportes_comunidad from public,anon,authenticated;

create or replace function public.app_puede_moderar_comunidad_v036(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth
as $$
  select exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo
    and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false)));
$$;
revoke all on function public.app_puede_moderar_comunidad_v036(uuid) from public,anon;
grant execute on function public.app_puede_moderar_comunidad_v036(uuid) to authenticated;

create or replace function public.app_comunidad_bloqueados_v036(p_club_id uuid)
returns table(perfil_id uuid,nombre text)
language sql stable security definer set search_path=public,auth
as $$
  select b.bloqueado_perfil_id,trim(concat_ws(' ',p.nombre,p.apellidos))
  from public.bloqueos_comunidad b
  left join public.perfiles p on p.id=b.bloqueado_perfil_id
  where b.club_contexto_id=p_club_id and b.bloqueador_perfil_id=auth.uid() and public.es_miembro_club(p_club_id)
  order by b.creado_en desc;
$$;
revoke all on function public.app_comunidad_bloqueados_v036(uuid) from public,anon;
grant execute on function public.app_comunidad_bloqueados_v036(uuid) to authenticated;

create or replace function public.app_comunidad_general_estado_v036(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();v_socio public.socios;v_age integer;v_min_age integer:=14;v_identity public.identidades_sociales;v_is_student boolean;
begin
  if v_uid is null or not public.es_miembro_club(p_club_id) then raise exception 'MEMBERSHIP_REQUIRED'; end if;
  select exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=v_uid and m.activo and m.rol='alumno') into v_is_student;
  v_min_age:=public.app_edad_min_comunidad_general_v036(p_club_id);
  select * into v_socio from public.socios s where s.club_id=p_club_id and s.perfil_id=v_uid and s.estado='activo' order by s.creado_en desc limit 1;
  if v_socio.id is not null and v_socio.fecha_nacimiento is not null then v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento))::integer; end if;
  select * into v_identity from public.identidades_sociales i where i.perfil_id=v_uid;
  return jsonb_build_object(
    'eligible',coalesce(v_is_student,false) and v_socio.id is not null and v_age>=v_min_age,
    'age_verified',v_socio.id is not null and v_socio.fecha_nacimiento is not null,
    'minimum_age',v_min_age,
    'role_student',coalesce(v_is_student,false),
    'status',coalesce(v_identity.estado,'no_activada'),
    'identity_id',v_identity.id,
    'activated_at',v_identity.activada_en,
    'reason',case
      when v_identity.estado='suspendida' then coalesce(nullif(v_identity.suspension_motivo,''),'El acceso social está suspendido por moderación.')
      when v_identity.estado='cerrada' then 'La identidad social está cerrada y requiere un flujo específico de reapertura.'
      when not coalesce(v_is_student,false) then 'Solo las cuentas de alumno pueden activar la Comunidad General en esta fase.'
      when v_socio.id is null then 'La cuenta todavía no está vinculada a un alumno aprobado por el club.'
      when v_socio.fecha_nacimiento is null then 'El club debe disponer de una fecha de nacimiento verificada.'
      when v_age<v_min_age then 'No alcanzas la edad mínima configurada para esta capa social.'
      else null end
  );
end
$$;
revoke all on function public.app_comunidad_general_estado_v036(uuid) from public,anon;
grant execute on function public.app_comunidad_general_estado_v036(uuid) to authenticated;

create or replace function public.app_comunidad_reportes_v036(p_club_id uuid)
returns table(
  id uuid,ambito text,objetivo_tipo text,objetivo_id uuid,motivo text,detalle text,estado text,creado_en timestamptz,
  reportado_por uuid,objetivo_nombre text,objetivo_resumen text,objetivo_perfil_id uuid,identidad_social_estado text
)
language sql stable security definer set search_path=public,auth
as $$
  select r.id,r.ambito,r.objetivo_tipo,r.objetivo_id,r.motivo,r.detalle,r.estado,r.creado_en,r.reportado_por,
    case when r.objetivo_tipo='publicacion' then coalesce(pc.autor_nombre,'Publicación') else coalesce(nullif(trim(concat_ws(' ',p.nombre,p.apellidos)),''),'Perfil') end,
    case when r.objetivo_tipo='publicacion' then left(coalesce(pc.texto,''),240) else null end,
    case when r.objetivo_tipo='publicacion' then pc.autor_perfil_id else r.objetivo_id end as objetivo_perfil_id,
    si.estado as identidad_social_estado
  from public.reportes_comunidad r
  left join public.publicaciones_comunidad pc on r.objetivo_tipo='publicacion' and pc.id=r.objetivo_id and pc.club_id=r.club_id
  left join public.perfiles p on r.objetivo_tipo='perfil' and p.id=r.objetivo_id
  left join public.identidades_sociales si
    on si.perfil_id=(case when r.objetivo_tipo='publicacion' then pc.autor_perfil_id else r.objetivo_id end)
   and si.club_origen_id=r.club_id
  where r.club_id=p_club_id and public.app_puede_moderar_comunidad_v036(p_club_id)
  order by case r.estado when 'pendiente' then 0 when 'en_revision' then 1 else 2 end,r.creado_en desc;
$$;
revoke all on function public.app_comunidad_reportes_v036(uuid) from public,anon;
grant execute on function public.app_comunidad_reportes_v036(uuid) to authenticated;

-- --------------------------------------------------------------------------
-- 3. CONTRATO
-- --------------------------------------------------------------------------
do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_social_access_036(uuid)') is null then
    if to_regprocedure('public.app_runtime_contract_v160(uuid)') is null then raise exception '036: falta app_runtime_contract_v160'; end if;
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_social_access_036;
  end if;
end
$contract$;
revoke all on function public.app_runtime_contract_v160_pre_social_access_036(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare v_base jsonb;
begin
  v_base:=public.app_runtime_contract_v160_pre_social_access_036(p_club_id);
  return jsonb_set(v_base,'{operations}',coalesce(v_base->'operations','[]'::jsonb)||jsonb_build_array(
    'comunidad_general.activar','comunidad.denunciar','comunidad.bloquear','comunidad.denuncia.estado','comunidad_general.moderar_acceso'
  ),true);
end
$$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

-- --------------------------------------------------------------------------
-- 4. GATEWAY: edad de autorregistro + alta social + seguridad UGC
-- --------------------------------------------------------------------------
do $migration$
begin
  if to_regprocedure('public.app_mutate_v160_pre_social_access_036(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception '036: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_social_access_036;
  end if;
end
$migration$;
revoke all on function public.app_mutate_v160_pre_social_access_036(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_club uuid;v_existing public.app_mutation_requests;
  v_result jsonb;v_socio public.socios;v_identity public.identidades_sociales;v_post public.publicaciones_comunidad;v_report public.reportes_comunidad;
  v_target uuid;v_status text;v_reason text;v_scope text;v_object_type text;v_slug text;v_name text;v_dob date;v_age integer;v_min_social_age integer:=14;v_block boolean;v_texto uuid;v_previous_status text;v_community_version text;
begin
  -- El autorregistro de alumno es autónomo desde 16 años. Se valida antes de
  -- delegar al flujo histórico, por lo que no cambia el sistema de preinscripción.
  if p_operation='cuenta.registrar' then
    if lower(coalesce(v_payload->>'tipo_cuenta',''))='adulto' then
      begin v_dob:=nullif(v_payload->>'fecha_nacimiento_adulto','')::date; exception when others then raise exception 'Fecha de nacimiento no válida'; end;
      if v_dob is null then raise exception 'La fecha de nacimiento es obligatoria para inscribirte como alumno'; end if;
      if v_dob>current_date then raise exception 'La fecha de nacimiento no puede ser futura'; end if;
      v_age:=extract(year from age(current_date,v_dob))::integer;
      if v_age<16 then raise exception 'El autorregistro como alumno está disponible a partir de los 16 años'; end if;
    end if;
    return public.app_mutate_v160_pre_social_access_036(p_operation,p_payload,p_request_id);
  end if;

  -- La Comunidad interna ya es UGC real. Publicar requiere una aceptación
  -- explícita y vigente de sus normas; consultar el club no la acepta por defecto.
  if p_operation='comunidad.publicar' then
    if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
    if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
    begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
    if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;
    -- Respeta idempotencia: un reintento de una publicación ya completada debe
    -- devolver exactamente el resultado histórico aunque el consentimiento se
    -- haya retirado después. Solo las publicaciones NUEVAS exigen aceptación vigente.
    select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
    if v_existing.request_id is not null then
      if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
      if v_existing.result is not null then return v_existing.result; end if;
    end if;
    select t.id,t.version into v_texto,v_community_version
    from public.textos_legales t
    where t.club_id=v_club and t.tipo='comunidad' and t.vigente
    order by t.creado_en desc,t.id desc limit 1;
    if v_texto is null then raise exception 'Las Normas de Comunidad vigentes no están disponibles'; end if;
    if not exists(
      select 1 from public.aceptaciones_legales a
      where a.club_id=v_club and a.perfil_id=v_uid and a.texto_legal_id=v_texto
        and a.tipo='comunidad' and a.version=v_community_version and a.aceptado and a.revocado_en is null
    ) then raise exception 'Debes leer y aceptar las Normas de Comunidad antes de publicar'; end if;
    return public.app_mutate_v160_pre_social_access_036(p_operation,p_payload,p_request_id);
  end if;

  if p_operation not in ('comunidad_general.activar','comunidad.denunciar','comunidad.bloquear','comunidad.denuncia.estado','comunidad_general.moderar_acceso') then
    return public.app_mutate_v160_pre_social_access_036(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation); end if;

  if p_operation='comunidad_general.activar' then
    if not exists(select 1 from public.miembros_club m where m.club_id=v_club and m.perfil_id=v_uid and m.activo and m.rol='alumno') then
      raise exception 'Solo una cuenta de alumno puede activar la Comunidad General';
    end if;
    select * into v_socio from public.socios s where s.club_id=v_club and s.perfil_id=v_uid and s.estado='activo' order by s.creado_en desc limit 1;
    if v_socio.id is null or v_socio.fecha_nacimiento is null then raise exception 'El club debe validar primero tu identidad y fecha de nacimiento'; end if;
    v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento))::integer;
    v_min_social_age:=public.app_edad_min_comunidad_general_v036(v_club);
    if v_age<v_min_social_age then raise exception 'No cumples la edad mínima configurada para la Comunidad General'; end if;
    if coalesce((v_payload->>'acepta_normas')::boolean,false) is not true or coalesce((v_payload->>'acepta_privacidad')::boolean,false) is not true then
      raise exception 'Debes aceptar las normas y la privacidad de la Comunidad General';
    end if;
    select coalesce(nullif(pd.apodo,''),trim(concat_ws(' ',v_socio.nombre,v_socio.apellidos))) into v_name
      from public.perfiles_deportivos pd where pd.club_id=v_club and pd.socio_id=v_socio.id;
    v_name:=coalesce(v_name,trim(concat_ws(' ',v_socio.nombre,v_socio.apellidos)));
    select * into v_identity from public.identidades_sociales i where i.perfil_id=v_uid for update;
    if v_identity.id is not null and v_identity.estado in ('suspendida','cerrada') then
      raise exception 'Tu acceso a Comunidad General no puede reactivarse desde el perfil mientras esté suspendido o cerrado';
    end if;
    select id into v_texto from public.textos_legales
      where club_id=v_club and tipo='comunidad_general' and version='1.0.0' and vigente limit 1;
    if v_texto is null then raise exception 'Las normas vigentes de Comunidad General no están disponibles'; end if;
    delete from public.aceptaciones_legales
      where club_id=v_club and perfil_id=v_uid and socio_id=v_socio.id and tipo='comunidad_general' and version='1.0.0';
    insert into public.aceptaciones_legales(club_id,perfil_id,socio_id,texto_legal_id,tipo,version,aceptado,aceptado_en,revocado_en,user_agent)
    values(v_club,v_uid,v_socio.id,v_texto,'comunidad_general','1.0.0',true,now(),null,left(coalesce(v_payload->>'user_agent',''),500));
    v_slug:='miembro-'||replace(v_uid::text,'-','');
    insert into public.identidades_sociales(perfil_id,club_origen_id,socio_origen_id,tipo,slug,nombre_publico,estado,version_normas,activada_en,actualizado_en)
    values(v_uid,v_club,v_socio.id,'miembro',v_slug,v_name,'activa','1.0.0',now(),now())
    on conflict(perfil_id) do update set club_origen_id=excluded.club_origen_id,socio_origen_id=excluded.socio_origen_id,
      nombre_publico=excluded.nombre_publico,estado='activa',version_normas='1.0.0',suspendida_en=null,suspension_motivo=null,actualizado_en=now()
    returning * into v_identity;
    v_result:=to_jsonb(v_identity)-'suspension_motivo';

  elsif p_operation='comunidad.bloquear' then
    begin v_target:=(v_payload->>'perfil_id')::uuid; exception when others then raise exception 'Perfil a bloquear no válido'; end;
    if v_target=v_uid then raise exception 'No puedes bloquear tu propio perfil'; end if;
    if not exists(select 1 from public.miembros_club m where m.club_id=v_club and m.perfil_id=v_target and m.activo) then raise exception 'El perfil no pertenece al entorno del club'; end if;
    v_block:=coalesce((v_payload->>'bloquear')::boolean,true);
    if v_block then
      insert into public.bloqueos_comunidad(club_contexto_id,bloqueador_perfil_id,bloqueado_perfil_id)
      values(v_club,v_uid,v_target) on conflict(club_contexto_id,bloqueador_perfil_id,bloqueado_perfil_id) do nothing;
    else delete from public.bloqueos_comunidad where club_contexto_id=v_club and bloqueador_perfil_id=v_uid and bloqueado_perfil_id=v_target;
    end if;
    v_result:=jsonb_build_object('perfil_id',v_target,'bloqueado',v_block);

  elsif p_operation='comunidad.denunciar' then
    v_reason:=lower(trim(coalesce(v_payload->>'motivo','otro')));
    v_scope:=lower(trim(coalesce(nullif(v_payload->>'ambito',''),'club')));
    v_object_type:=lower(trim(coalesce(nullif(v_payload->>'objetivo_tipo',''),'publicacion')));
    if v_reason not in ('acoso','odio_discriminacion','violencia','sexual_menores','privacidad','spam','suplantacion','otro') then raise exception 'Motivo de denuncia no válido'; end if;
    if v_scope not in ('club','general') then raise exception 'Ámbito de denuncia no válido'; end if;
    if v_object_type not in ('publicacion','perfil') then raise exception 'Tipo de objetivo no válido'; end if;
    begin v_target:=(v_payload->>'objetivo_id')::uuid; exception when others then raise exception 'Objetivo de denuncia no válido'; end;
    if v_object_type='publicacion' then
      select * into v_post from public.publicaciones_comunidad where club_id=v_club and id=v_target;
      if v_post.id is null then raise exception 'Publicación no encontrada'; end if;
      if v_post.autor_perfil_id=v_uid then raise exception 'No puedes denunciar tu propia publicación'; end if;
    else
      if v_target=v_uid then raise exception 'No puedes denunciar tu propio perfil'; end if;
      if not exists(select 1 from public.miembros_club m where m.club_id=v_club and m.perfil_id=v_target and m.activo) then raise exception 'Perfil no encontrado'; end if;
    end if;
    insert into public.reportes_comunidad(club_id,reportado_por,ambito,objetivo_tipo,objetivo_id,motivo,detalle)
    values(v_club,v_uid,v_scope,v_object_type,v_target,v_reason,left(nullif(trim(v_payload->>'detalle'),''),1500))
    on conflict(reportado_por,ambito,objetivo_tipo,objetivo_id) where estado in ('pendiente','en_revision')
    do update set motivo=excluded.motivo,detalle=excluded.detalle,creado_en=now()
    returning * into v_report;
    v_result:=jsonb_build_object('id',v_report.id,'estado',v_report.estado);

  elsif p_operation='comunidad.denuncia.estado' then
    if not public.app_puede_moderar_comunidad_v036(v_club) then raise exception 'No tienes permiso para revisar denuncias'; end if;
    begin v_target:=(v_payload->>'reporte_id')::uuid; exception when others then raise exception 'Reporte no válido'; end;
    v_status:=lower(trim(coalesce(v_payload->>'estado','resuelta')));
    if v_status not in ('en_revision','resuelta','descartada') then raise exception 'Estado de reporte no válido'; end if;
    update public.reportes_comunidad set estado=v_status,revisado_por=v_uid,revisado_en=now(),resolucion=left(nullif(trim(v_payload->>'resolucion'),''),1500)
    where club_id=v_club and id=v_target returning * into v_report;
    if v_report.id is null then raise exception 'Reporte no encontrado'; end if;
    if coalesce((v_payload->>'ocultar_publicacion')::boolean,false) and v_report.objetivo_tipo='publicacion' then
      update public.publicaciones_comunidad set estado='oculta',moderada_por=v_uid,moderacion_motivo=coalesce(nullif(v_report.resolucion,''),'Ocultada tras denuncia')
      where club_id=v_club and id=v_report.objetivo_id;
    end if;
    v_result:=jsonb_build_object('id',v_report.id,'estado',v_report.estado,'objetivo_tipo',v_report.objetivo_tipo,'objetivo_id',v_report.objetivo_id);

  else -- comunidad_general.moderar_acceso
    if not public.app_puede_moderar_comunidad_v036(v_club) then raise exception 'No tienes permiso para moderar accesos sociales'; end if;
    begin v_target:=(v_payload->>'perfil_id')::uuid; exception when others then raise exception 'Perfil social no válido'; end;
    if v_target=v_uid then raise exception 'No puedes moderar tu propio acceso social'; end if;
    v_status:=lower(trim(coalesce(v_payload->>'estado','')));
    if v_status not in ('activa','suspendida') then raise exception 'Estado social no válido'; end if;
    v_reason:=left(nullif(trim(v_payload->>'motivo'),''),1000);
    if v_reason is null or char_length(v_reason)<3 then raise exception 'Indica un motivo de moderación'; end if;
    select * into v_identity from public.identidades_sociales i
      where i.club_origen_id=v_club and i.perfil_id=v_target for update;
    if v_identity.id is null then raise exception 'El perfil no tiene una identidad de Comunidad General activa o histórica'; end if;
    v_previous_status:=v_identity.estado;
    if v_previous_status='cerrada' then raise exception 'Una identidad cerrada requiere un flujo específico de reapertura'; end if;
    if v_previous_status=v_status then raise exception 'El acceso social ya se encuentra en ese estado'; end if;
    update public.identidades_sociales set estado=v_status,
      suspendida_en=case when v_status='suspendida' then now() else null end,
      suspension_motivo=case when v_status='suspendida' then v_reason else null end,actualizado_en=now()
    where id=v_identity.id returning * into v_identity;
    insert into public.moderacion_accesos_sociales(club_id,identidad_social_id,perfil_id,moderado_por,estado_anterior,estado_nuevo,motivo)
    values(v_club,v_identity.id,v_target,v_uid,v_previous_status,v_status,v_reason);
    v_result:=jsonb_build_object('perfil_id',v_target,'identity_id',v_identity.id,'estado',v_identity.estado,'estado_anterior',v_previous_status);
  end if;

  v_result:=jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end
$$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

do $audit$
begin
  if to_regprocedure('public.app_mutate_v160_pre_social_access_036(text,jsonb,uuid)') is null then raise exception '036: gateway anterior no preservado'; end if;
  if to_regprocedure('public.app_runtime_contract_v160_pre_social_access_036(uuid)') is null then raise exception '036: contrato anterior no preservado'; end if;
  if has_table_privilege('authenticated','public.identidades_sociales','SELECT') then raise exception '036: identidades sociales no deben tener SELECT directo'; end if;
  if has_table_privilege('authenticated','public.reportes_comunidad','SELECT') then raise exception '036: reportes no deben tener SELECT directo'; end if;
  if has_table_privilege('authenticated','public.moderacion_accesos_sociales','SELECT') then raise exception '036: auditoría de moderación no debe tener SELECT directo'; end if;
end
$audit$;

notify pgrst,'reload schema';
commit;
