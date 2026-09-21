-- Urban Warriors RC13 build 20018 · 035
-- Perfil público del club y capa normalizada de identidad/búsqueda.
-- No despliega todavía un entorno multiclub visible: valida el modelo dentro de Urban Warriors.

begin;

create table if not exists public.perfiles_club_publicos (
  club_id uuid primary key references public.clubes(id) on delete cascade,
  slug text not null unique,
  nombre_publico text not null,
  alias text,
  lema text,
  descripcion text,
  historia text,
  ciudad text,
  provincia text,
  pais text not null default 'España',
  logros text,
  contacto_publico text,
  web_publica text,
  instagram text,
  tiktok text,
  youtube text,
  logo_url text,
  portada_url text,
  visible boolean not null default true,
  moderacion_oculta boolean not null default false,
  actualizado_por uuid references public.perfiles(id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  check(slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  check(char_length(nombre_publico) between 1 and 160),
  check(char_length(coalesce(alias,''))<=80),
  check(char_length(coalesce(lema,''))<=180),
  check(char_length(coalesce(descripcion,''))<=1200),
  check(char_length(coalesce(historia,''))<=4000),
  check(char_length(coalesce(ciudad,''))<=120),
  check(char_length(coalesce(provincia,''))<=120),
  check(char_length(coalesce(pais,''))<=120),
  check(char_length(coalesce(logros,''))<=2500),
  check(char_length(coalesce(contacto_publico,''))<=240),
  check(char_length(coalesce(web_publica,''))<=500),
  check(char_length(coalesce(instagram,''))<=240),
  check(char_length(coalesce(tiktok,''))<=240),
  check(char_length(coalesce(youtube,''))<=500),
  check(web_publica is null or btrim(web_publica) ~* '^https://'),
  check(instagram is null or btrim(instagram) ~* '^https://'),
  check(tiktok is null or btrim(tiktok) ~* '^https://'),
  check(youtube is null or btrim(youtube) ~* '^https://'),
  check(logo_url is null or btrim(logo_url) ~* '^https://'),
  check(portada_url is null or btrim(portada_url) ~* '^https://')
);
create index if not exists idx_perfiles_club_publicos_busqueda_v035
  on public.perfiles_club_publicos(visible,moderacion_oculta,nombre_publico,ciudad,slug);
alter table public.perfiles_club_publicos enable row level security;
revoke all on public.perfiles_club_publicos from public,anon,authenticated;

-- Inicializa cada club actual con datos que ya eran de marca pública; no copia CIF,
-- email administrativo, teléfono administrativo ni dirección privada.
insert into public.perfiles_club_publicos(club_id,slug,nombre_publico,alias,lema,descripcion,web_publica,logo_url,portada_url,visible)
select c.id,c.slug,c.nombre,null::text,nullif(c.lema,''),null::text,
  case when nullif(trim(c.web),'') ~* '^https://' then trim(c.web) end,
  case when nullif(trim(c.logo_url),'') ~* '^https://' then trim(c.logo_url) end,
  case when nullif(trim(c.portada_url),'') ~* '^https://' then trim(c.portada_url) end,c.activo
from public.clubes c
on conflict(club_id) do nothing;

-- Mantiene el modelo preparado para un club futuro sin crear todavía una UX multiclub.
create or replace function public.app_seed_perfil_club_publico_v035()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.perfiles_club_publicos(club_id,slug,nombre_publico,alias,lema,descripcion,web_publica,logo_url,portada_url,visible)
  values(new.id,new.slug,new.nombre,null::text,nullif(new.lema,''),null::text,
    case when nullif(trim(new.web),'') ~* '^https://' then trim(new.web) end,
    case when nullif(trim(new.logo_url),'') ~* '^https://' then trim(new.logo_url) end,
    case when nullif(trim(new.portada_url),'') ~* '^https://' then trim(new.portada_url) end,new.activo)
  on conflict(club_id) do nothing;
  return new;
end
$$;
revoke all on function public.app_seed_perfil_club_publico_v035() from public,anon,authenticated;
drop trigger if exists clubes_seed_perfil_publico_v035 on public.clubes;
create trigger clubes_seed_perfil_publico_v035 after insert on public.clubes
for each row execute function public.app_seed_perfil_club_publico_v035();

create or replace function public.app_puede_gestionar_perfil_club_v035(p_club_id uuid)
returns boolean
language sql stable security definer set search_path=public,auth
as $$
  select exists(
    select 1 from public.miembros_club m
    where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo
      and (m.rol='direccion' or coalesce(m.coordinacion,false))
  );
$$;
revoke all on function public.app_puede_gestionar_perfil_club_v035(uuid) from public,anon;
grant execute on function public.app_puede_gestionar_perfil_club_v035(uuid) to authenticated;

create or replace function public.app_perfil_club_publico_v035(p_club_id uuid)
returns table(
  club_id uuid,slug text,nombre_publico text,alias text,lema text,descripcion text,historia text,ciudad text,provincia text,pais text,
  logros text,contacto_publico text,web_publica text,instagram text,tiktok text,youtube text,logo_url text,portada_url text,
  visible boolean,moderacion_oculta boolean,editable boolean,disciplinas jsonb
)
language sql stable security definer set search_path=public,auth
as $$
  select p.club_id,p.slug,p.nombre_publico,p.alias,p.lema,p.descripcion,p.historia,p.ciudad,p.provincia,p.pais,
    p.logros,p.contacto_publico,p.web_publica,p.instagram,p.tiktok,p.youtube,p.logo_url,p.portada_url,
    p.visible,p.moderacion_oculta,public.app_puede_gestionar_perfil_club_v035(p.club_id),
    coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'nombre',d.nombre) order by d.orden,d.nombre)
      from public.disciplinas d where d.club_id=p.club_id and d.activa),'[]'::jsonb)
  from public.perfiles_club_publicos p
  where p.club_id=p_club_id
    and auth.uid() is not null
    and ((p.visible and not p.moderacion_oculta) or public.app_puede_gestionar_perfil_club_v035(p.club_id));
$$;
revoke all on function public.app_perfil_club_publico_v035(uuid) from public,anon;
grant execute on function public.app_perfil_club_publico_v035(uuid) to authenticated;

-- Capa de identidad común. Hoy normaliza club + perfiles deportivos del club actual;
-- mañana puede incorporar competidor, federación, marca o tienda sin cambiar el consumidor.
create or replace function public.app_buscar_identidades_publicas_v035(p_club_id uuid,p_query text default '',p_limit integer default 40)
returns table(
  identidad_id text,tipo text,referencia_id uuid,nombre text,subtitulo text,slug text,media_path text,media_url text,extra jsonb
)
language sql stable security definer set search_path=public,auth
as $$
  with q as (select lower(trim(coalesce(p_query,''))) value),
  identidades as (
    select
      'club:'||pc.club_id::text identidad_id,'club'::text tipo,pc.club_id referencia_id,pc.nombre_publico nombre,
      trim(concat_ws(' · ',nullif(pc.alias,''),nullif(pc.ciudad,''),nullif(pc.pais,''))) subtitulo,pc.slug,
      null::text media_path,pc.logo_url media_url,
      jsonb_build_object('disciplinas',coalesce((select jsonb_agg(d.nombre order by d.orden,d.nombre) from public.disciplinas d where d.club_id=pc.club_id and d.activa),'[]'::jsonb)) extra
    from public.perfiles_club_publicos pc,q
    where pc.club_id=p_club_id and pc.visible and not pc.moderacion_oculta and public.es_miembro_club(p_club_id)
      and (
        q.value=''
        or lower(concat_ws(' ',pc.nombre_publico,pc.alias,pc.slug,pc.ciudad,pc.provincia,pc.pais)) like '%'||q.value||'%'
        or exists(select 1 from public.disciplinas d where d.club_id=pc.club_id and d.activa and lower(d.nombre) like '%'||q.value||'%')
      )
    union all
    select
      'miembro:'||pd.socio_id::text,'miembro',pd.socio_id,
      coalesce(nullif(pd.apodo,''),trim(concat_ws(' ',s.nombre,s.apellidos))),
      coalesce((select string_agg(trim(concat_ws(' · ',d.nombre,g.nombre)), ' / ' order by d.nombre,g.nombre)
        from public.socio_disciplinas sd
        join public.disciplinas d on d.club_id=sd.club_id and d.id=sd.disciplina_id
        left join public.grupos g on g.club_id=sd.club_id and g.id=sd.grupo_id
        where sd.club_id=pd.club_id and sd.socio_id=pd.socio_id and sd.activa),'Miembro del club'),
      null::text,pd.foto_path,null::text,
      jsonb_build_object('apodo',pd.apodo,'categoria_competitiva',pd.categoria_competitiva)
    from public.perfiles_deportivos pd
    join public.socios s on s.club_id=pd.club_id and s.id=pd.socio_id
    cross join q
    where pd.club_id=p_club_id and pd.visible and not pd.moderacion_oculta and public.es_miembro_club(p_club_id)
      and (
        q.value=''
        or lower(concat_ws(' ',pd.apodo,s.nombre,s.apellidos,pd.especialidad,pd.categoria_competitiva)) like '%'||q.value||'%'
        or exists(
          select 1 from public.socio_disciplinas sd
          join public.disciplinas d on d.club_id=sd.club_id and d.id=sd.disciplina_id
          left join public.grupos g on g.club_id=sd.club_id and g.id=sd.grupo_id
          where sd.club_id=pd.club_id and sd.socio_id=pd.socio_id and sd.activa
            and lower(concat_ws(' ',d.nombre,g.nombre)) like '%'||q.value||'%'
        )
      )
  )
  select i.identidad_id,i.tipo,i.referencia_id,i.nombre,nullif(i.subtitulo,''),i.slug,i.media_path,i.media_url,i.extra
  from identidades i order by case i.tipo when 'club' then 0 else 1 end,i.nombre
  limit greatest(1,least(coalesce(p_limit,40),100));
$$;
revoke all on function public.app_buscar_identidades_publicas_v035(uuid,text,integer) from public,anon;
grant execute on function public.app_buscar_identidades_publicas_v035(uuid,text,integer) to authenticated;

-- Contrato runtime.
do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_club_profile_035(uuid)') is null then
    if to_regprocedure('public.app_runtime_contract_v160(uuid)') is null then raise exception '035: falta app_runtime_contract_v160'; end if;
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_club_profile_035;
  end if;
end
$contract$;
revoke all on function public.app_runtime_contract_v160_pre_club_profile_035(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare v_base jsonb;
begin
  v_base:=public.app_runtime_contract_v160_pre_club_profile_035(p_club_id);
  return jsonb_set(v_base,'{operations}',coalesce(v_base->'operations','[]'::jsonb)||jsonb_build_array('club_publico.guardar'),true);
end
$$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

-- Gateway.
do $migration$
begin
  if to_regprocedure('public.app_mutate_v160_pre_club_profile_035(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception '035: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_club_profile_035;
  end if;
end
$migration$;
revoke all on function public.app_mutate_v160_pre_club_profile_035(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_club uuid;v_existing public.app_mutation_requests;
  v_result jsonb;v_profile public.perfiles_club_publicos;v_slug text;
begin
  if p_operation<>'club_publico.guardar' then return public.app_mutate_v160_pre_club_profile_035(p_operation,p_payload,p_request_id); end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.app_puede_gestionar_perfil_club_v035(v_club) then raise exception 'No tienes permiso para editar el perfil público del club'; end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation); end if;

  v_slug:=lower(trim(coalesce(nullif(v_payload->>'slug',''),(select slug from public.clubes where id=v_club))));
  if v_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then raise exception 'El identificador público solo admite minúsculas, números y guiones'; end if;
  if nullif(trim(v_payload->>'nombre_publico'),'') is null then raise exception 'El perfil público necesita nombre'; end if;
  -- Los campos que luego se insertan en href/src/style solo aceptan HTTP(S).
  -- Así una edición administrativa no puede introducir esquemas ejecutables
  -- (javascript:, data:, etc.) en la ficha pública.
  if exists(
    select 1 from jsonb_array_elements_text(jsonb_build_array(
      coalesce(v_payload->>'web_publica',''),coalesce(v_payload->>'instagram',''),coalesce(v_payload->>'tiktok',''),coalesce(v_payload->>'youtube',''),
      coalesce(v_payload->>'logo_url',''),coalesce(v_payload->>'portada_url','')
    )) u(value)
    where nullif(trim(u.value),'') is not null and trim(u.value) !~* '^https://'
  ) then raise exception 'Los enlaces públicos deben utilizar HTTPS'; end if;

  insert into public.perfiles_club_publicos(
    club_id,slug,nombre_publico,alias,lema,descripcion,historia,ciudad,provincia,pais,logros,contacto_publico,web_publica,
    instagram,tiktok,youtube,logo_url,portada_url,visible,actualizado_por,actualizado_en
  ) values(
    v_club,v_slug,trim(v_payload->>'nombre_publico'),nullif(trim(v_payload->>'alias'),''),nullif(trim(v_payload->>'lema'),''),nullif(trim(v_payload->>'descripcion'),''),
    nullif(trim(v_payload->>'historia'),''),nullif(trim(v_payload->>'ciudad'),''),nullif(trim(v_payload->>'provincia'),''),
    coalesce(nullif(trim(v_payload->>'pais'),''),'España'),nullif(trim(v_payload->>'logros'),''),nullif(trim(v_payload->>'contacto_publico'),''),
    nullif(trim(v_payload->>'web_publica'),''),nullif(trim(v_payload->>'instagram'),''),nullif(trim(v_payload->>'tiktok'),''),nullif(trim(v_payload->>'youtube'),''),
    nullif(v_payload->>'logo_url',''),nullif(v_payload->>'portada_url',''),coalesce((v_payload->>'visible')::boolean,true),v_uid,now()
  ) on conflict(club_id) do update set
    slug=excluded.slug,nombre_publico=excluded.nombre_publico,alias=excluded.alias,lema=excluded.lema,descripcion=excluded.descripcion,historia=excluded.historia,
    ciudad=excluded.ciudad,provincia=excluded.provincia,pais=excluded.pais,logros=excluded.logros,contacto_publico=excluded.contacto_publico,
    web_publica=excluded.web_publica,instagram=excluded.instagram,tiktok=excluded.tiktok,youtube=excluded.youtube,
    logo_url=excluded.logo_url,portada_url=excluded.portada_url,visible=excluded.visible,actualizado_por=v_uid,actualizado_en=now()
  returning * into v_profile;
  v_result:=jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_profile));
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
  if to_regprocedure('public.app_mutate_v160_pre_club_profile_035(text,jsonb,uuid)') is null then raise exception '035: gateway anterior no preservado'; end if;
  if to_regprocedure('public.app_runtime_contract_v160_pre_club_profile_035(uuid)') is null then raise exception '035: contrato anterior no preservado'; end if;
  if to_regprocedure('public.app_buscar_identidades_publicas_v035(uuid,text,integer)') is null then raise exception '035: falta capa de identidad pública'; end if;
  if has_table_privilege('authenticated','public.perfiles_club_publicos','SELECT') then raise exception '035: no debe haber SELECT directo al perfil público'; end if;
end
$audit$;

notify pgrst,'reload schema';
commit;
