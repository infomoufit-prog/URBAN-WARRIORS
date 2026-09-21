-- Urban Warriors RC13 MVP · perfiles deportivos públicos + likes privados por identidad.
-- Requiere 022 (Comunidad/perfil), 025 (gateway material) y 030 (cierre DML).
-- Idempotente, multiclub y no destructiva.

begin;

-- --------------------------------------------------------------------------
-- 1. PERFIL DEPORTIVO PÚBLICO, SEPARADO DEL PERFIL ADMINISTRATIVO
-- --------------------------------------------------------------------------
create table if not exists public.perfiles_deportivos (
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null,
  foto_path text,
  apodo text,
  presentacion text,
  experiencia_anos numeric(4,1),
  guardia text,
  tecnica_favorita text,
  especialidad text,
  categoria_competitiva text,
  competiciones_logros text,
  objetivos text,
  visible boolean not null default false,
  moderacion_oculta boolean not null default false,
  moderado_por uuid references public.perfiles(id) on delete set null,
  moderacion_motivo text,
  moderado_en timestamptz,
  actualizado_por uuid references public.perfiles(id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  primary key (club_id,socio_id),
  foreign key (club_id,socio_id) references public.socios(club_id,id) on delete cascade,
  check (experiencia_anos is null or (experiencia_anos>=0 and experiencia_anos<=80)),
  check (char_length(coalesce(apodo,''))<=60),
  check (char_length(coalesce(presentacion,''))<=600),
  check (char_length(coalesce(guardia,''))<=40),
  check (char_length(coalesce(tecnica_favorita,''))<=120),
  check (char_length(coalesce(especialidad,''))<=120),
  check (char_length(coalesce(categoria_competitiva,''))<=100),
  check (char_length(coalesce(competiciones_logros,''))<=1200),
  check (char_length(coalesce(objetivos,''))<=800)
);
create index if not exists idx_perfiles_deportivos_club_visible
  on public.perfiles_deportivos(club_id,visible,actualizado_en desc,socio_id);
alter table public.perfiles_deportivos enable row level security;

create or replace function public.app_puede_editar_perfil_deportivo_v032(p_socio_id uuid)
returns boolean
language sql stable security definer set search_path=public,auth
as $$
  select exists(
    select 1 from public.socios s
    where s.id=p_socio_id
      and public.es_miembro_club(s.club_id)
      and (
        s.perfil_id=auth.uid()
        or exists(
          select 1 from public.tutores_socios t
          where t.club_id=s.club_id and t.socio_id=s.id and t.tutor_perfil_id=auth.uid()
        )
      )
  );
$$;
revoke all on function public.app_puede_editar_perfil_deportivo_v032(uuid) from public,anon;
grant execute on function public.app_puede_editar_perfil_deportivo_v032(uuid) to authenticated;

create or replace function public.app_puede_moderar_perfil_deportivo_v032(p_club_id uuid)
returns boolean
language sql stable security definer set search_path=public,auth
as $$
  select exists(
    select 1 from public.miembros_club m
    where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo
      and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))
  );
$$;
revoke all on function public.app_puede_moderar_perfil_deportivo_v032(uuid) from public,anon;
grant execute on function public.app_puede_moderar_perfil_deportivo_v032(uuid) to authenticated;

create or replace function public.app_puede_ver_perfil_deportivo_v032(p_club_id uuid,p_socio_id uuid)
returns boolean
language sql stable security definer set search_path=public,auth
as $$
  select public.es_miembro_club(p_club_id)
    and exists(select 1 from public.socios s where s.club_id=p_club_id and s.id=p_socio_id and s.estado='activo')
    and (
      exists(select 1 from public.perfiles_deportivos pd where pd.club_id=p_club_id and pd.socio_id=p_socio_id and pd.visible and not pd.moderacion_oculta)
      or public.app_puede_editar_perfil_deportivo_v032(p_socio_id)
      or (
        public.app_puede_moderar_perfil_deportivo_v032(p_club_id)
        and exists(select 1 from public.perfiles_deportivos pd where pd.club_id=p_club_id and pd.socio_id=p_socio_id)
      )
    );
$$;
revoke all on function public.app_puede_ver_perfil_deportivo_v032(uuid,uuid) from public,anon;
grant execute on function public.app_puede_ver_perfil_deportivo_v032(uuid,uuid) to authenticated;

drop policy if exists perfiles_deportivos_lectura_v032 on public.perfiles_deportivos;
create policy perfiles_deportivos_lectura_v032 on public.perfiles_deportivos
for select to authenticated using(public.app_puede_ver_perfil_deportivo_v032(club_id,socio_id));
revoke all on public.perfiles_deportivos from public,anon,authenticated;
-- La app cliente consume únicamente app_perfiles_deportivos_publicos_v032;
-- no se concede SELECT directo para reducir superficie de exposición.

-- Foto deportiva independiente de la foto de la cuenta/tutor.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('sports-profile-media','sports-profile-media',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists sports_profile_media_read_v032 on storage.objects;
create policy sports_profile_media_read_v032 on storage.objects for select to authenticated using(
  bucket_id='sports-profile-media'
  and array_length(storage.foldername(name),1)>=2
  and public.app_puede_ver_perfil_deportivo_v032(
    ((storage.foldername(name))[1])::uuid,
    ((storage.foldername(name))[2])::uuid
  )
);
drop policy if exists sports_profile_media_write_v032 on storage.objects;
create policy sports_profile_media_write_v032 on storage.objects for insert to authenticated with check(
  bucket_id='sports-profile-media'
  and array_length(storage.foldername(name),1)>=2
  and public.es_miembro_club(((storage.foldername(name))[1])::uuid)
  and public.app_puede_editar_perfil_deportivo_v032(((storage.foldername(name))[2])::uuid)
);
drop policy if exists sports_profile_media_delete_v032 on storage.objects;
create policy sports_profile_media_delete_v032 on storage.objects for delete to authenticated using(
  bucket_id='sports-profile-media'
  and array_length(storage.foldername(name),1)>=2
  and public.es_miembro_club(((storage.foldername(name))[1])::uuid)
  and public.app_puede_editar_perfil_deportivo_v032(((storage.foldername(name))[2])::uuid)
);

-- Función de lectura segura: nunca expone email, teléfono, fecha de nacimiento,
-- finanzas, documentos ni información familiar/administrativa.
create or replace function public.app_perfiles_deportivos_publicos_v032(
  p_club_id uuid,
  p_socio_id uuid default null
)
returns table(
  socio_id uuid,
  nombre text,
  apellidos text,
  foto_path text,
  apodo text,
  presentacion text,
  experiencia_anos numeric,
  guardia text,
  tecnica_favorita text,
  especialidad text,
  categoria_competitiva text,
  competiciones_logros text,
  objetivos text,
  disciplinas jsonb,
  editable boolean,
  visible boolean,
  moderado boolean
)
language sql stable security definer set search_path=public,auth
as $$
  select
    s.id,
    s.nombre,
    s.apellidos,
    pd.foto_path,
    pd.apodo,
    pd.presentacion,
    pd.experiencia_anos,
    pd.guardia,
    pd.tecnica_favorita,
    pd.especialidad,
    pd.categoria_competitiva,
    pd.competiciones_logros,
    pd.objetivos,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'disciplina_id',d.id,
          'disciplina',d.nombre,
          'grado_id',g.id,
          'grado',g.nombre,
          'grupo_id',gr.id,
          'grupo',gr.nombre
        ) order by d.orden,d.nombre,gr.nombre
      )
      from public.socio_disciplinas sd
      join public.disciplinas d on d.club_id=sd.club_id and d.id=sd.disciplina_id
      left join public.grados g on g.club_id=sd.club_id and g.id=sd.grado_id
      left join public.grupos gr on gr.club_id=sd.club_id and gr.id=sd.grupo_id
      where sd.club_id=s.club_id and sd.socio_id=s.id and sd.activa
    ),'[]'::jsonb),
    public.app_puede_editar_perfil_deportivo_v032(s.id),
    coalesce(pd.visible,false),
    coalesce(pd.moderacion_oculta,false)
  from public.socios s
  left join public.perfiles_deportivos pd on pd.club_id=s.club_id and pd.socio_id=s.id
  where s.club_id=p_club_id
    and s.estado='activo'
    and public.es_miembro_club(s.club_id)
    and (p_socio_id is null or s.id=p_socio_id)
    and public.app_puede_ver_perfil_deportivo_v032(s.club_id,s.id)
  order by s.apellidos,s.nombre,s.id;
$$;
revoke all on function public.app_perfiles_deportivos_publicos_v032(uuid,uuid) from public,anon;
grant execute on function public.app_perfiles_deportivos_publicos_v032(uuid,uuid) to authenticated;

-- --------------------------------------------------------------------------
-- 2. COMUNIDAD: LINK SEGURO A SOCIO + LIKE SIN IDENTIDAD PÚBLICA
-- --------------------------------------------------------------------------
alter table public.publicaciones_comunidad
  add column if not exists autor_socio_id uuid,
  add column if not exists likes_count integer not null default 0;

do $$ begin
  if not exists(
    select 1 from pg_constraint
    where conname='publicaciones_comunidad_autor_socio_fk'
      and conrelid='public.publicaciones_comunidad'::regclass
  ) then
    alter table public.publicaciones_comunidad
      add constraint publicaciones_comunidad_autor_socio_fk
      foreign key(autor_socio_id) references public.socios(id) on delete set null;
  end if;
end $$;

create or replace function public.trg_comunidad_autor_socio_v032()
returns trigger
language plpgsql security definer set search_path=public,auth
as $$
begin
  if new.autor_socio_id is null then
    select s.id into new.autor_socio_id
    from public.socios s
    where s.club_id=new.club_id and s.perfil_id=new.autor_perfil_id and s.estado='activo'
    order by s.creado_en desc limit 1;
  end if;
  return new;
end;
$$;
revoke all on function public.trg_comunidad_autor_socio_v032() from public,anon,authenticated;
drop trigger if exists trg_comunidad_autor_socio_v032 on public.publicaciones_comunidad;
create trigger trg_comunidad_autor_socio_v032
before insert or update of autor_perfil_id,club_id on public.publicaciones_comunidad
for each row execute function public.trg_comunidad_autor_socio_v032();

update public.publicaciones_comunidad pc
set autor_socio_id=(
  select x.id from public.socios x
  where x.club_id=pc.club_id and x.perfil_id=pc.autor_perfil_id and x.estado='activo'
  order by x.creado_en desc limit 1
)
where pc.autor_socio_id is null;

create table if not exists public.comunidad_likes (
  club_id uuid not null references public.clubes(id) on delete cascade,
  publicacion_id uuid not null,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  creado_en timestamptz not null default now(),
  primary key(club_id,publicacion_id,perfil_id),
  foreign key(club_id,publicacion_id) references public.publicaciones_comunidad(club_id,id) on delete cascade
);
create index if not exists idx_comunidad_likes_post_v032 on public.comunidad_likes(club_id,publicacion_id);
create index if not exists idx_comunidad_likes_profile_v032 on public.comunidad_likes(perfil_id,creado_en desc);
alter table public.comunidad_likes enable row level security;

-- La identidad de los likes es legible únicamente por su propio autor.
drop policy if exists comunidad_likes_propios_v032 on public.comunidad_likes;
create policy comunidad_likes_propios_v032 on public.comunidad_likes
for select to authenticated using(
  perfil_id=auth.uid() and public.es_miembro_club(club_id)
);
revoke all on public.comunidad_likes from public,anon,authenticated;
grant select on public.comunidad_likes to authenticated;

create or replace function public.trg_comunidad_likes_count_v032()
returns trigger
language plpgsql security definer set search_path=public,auth
as $$
begin
  if tg_op='INSERT' then
    update public.publicaciones_comunidad
      set likes_count=likes_count+1
      where club_id=new.club_id and id=new.publicacion_id;
    return new;
  elsif tg_op='DELETE' then
    update public.publicaciones_comunidad
      set likes_count=greatest(likes_count-1,0)
      where club_id=old.club_id and id=old.publicacion_id;
    return old;
  end if;
  return null;
end;
$$;
revoke all on function public.trg_comunidad_likes_count_v032() from public,anon,authenticated;
drop trigger if exists trg_comunidad_likes_count_v032 on public.comunidad_likes;
create trigger trg_comunidad_likes_count_v032
after insert or delete on public.comunidad_likes
for each row execute function public.trg_comunidad_likes_count_v032();

-- Reconciliación idempotente por si la migración se repite o se cargan datos previos.
update public.publicaciones_comunidad p
set likes_count=(select count(*)::integer from public.comunidad_likes l where l.club_id=p.club_id and l.publicacion_id=p.id);

-- --------------------------------------------------------------------------
-- 3. CONTRATO RUNTIME: PUBLICA LAS NUEVAS OPERACIONES SIN ROMPER EL CONTRATO BASE
-- --------------------------------------------------------------------------
do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_social_032(uuid)') is null then
    if to_regprocedure('public.app_runtime_contract_v160(uuid)') is null then raise exception '032: falta app_runtime_contract_v160'; end if;
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_social_032;
  end if;
end
$contract$;
revoke all on function public.app_runtime_contract_v160_pre_social_032(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare v_base jsonb;
begin
  v_base:=public.app_runtime_contract_v160_pre_social_032(p_club_id);
  return jsonb_set(
    v_base,
    '{operations}',
    coalesce(v_base->'operations','[]'::jsonb) || jsonb_build_array(
      'perfil_deportivo.guardar','perfil_deportivo.foto','perfil_deportivo.moderar','comunidad.like'
    ),
    true
  );
end
$$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

-- --------------------------------------------------------------------------
-- 4. GATEWAY: NUEVAS MUTACIONES, SIN ABRIR DML DIRECTO
-- --------------------------------------------------------------------------
do $migration$
begin
  if to_regprocedure('public.app_mutate_v160_pre_social_032(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception '032: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_social_032;
  end if;
end
$migration$;
revoke all on function public.app_mutate_v160_pre_social_032(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_club uuid;
  v_existing public.app_mutation_requests;
  v_data jsonb;
  v_result jsonb;
  v_socio uuid;
  v_post uuid;
  v_active boolean;
  v_old_path text;
  v_row public.perfiles_deportivos;
begin
  if p_operation not in (
    'perfil_deportivo.guardar','perfil_deportivo.foto','perfil_deportivo.moderar','comunidad.like'
  ) then
    return public.app_mutate_v160_pre_social_032(p_operation,p_payload,p_request_id);
  end if;

  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,v_club,p_operation);
  end if;

  if p_operation='perfil_deportivo.guardar' then
    begin v_socio:=(v_payload->>'socio_id')::uuid; exception when others then raise exception 'SOCIO_ID_INVALIDO'; end;
    if not exists(select 1 from public.socios s where s.club_id=v_club and s.id=v_socio and s.estado='activo') then raise exception 'Alumno no disponible'; end if;
    if not public.app_puede_editar_perfil_deportivo_v032(v_socio) then raise exception 'No puedes editar este perfil deportivo'; end if;

    insert into public.perfiles_deportivos(
      club_id,socio_id,apodo,presentacion,experiencia_anos,guardia,tecnica_favorita,especialidad,
      categoria_competitiva,competiciones_logros,objetivos,visible,actualizado_por,actualizado_en
    ) values(
      v_club,v_socio,
      nullif(trim(v_payload->>'apodo'),''),nullif(trim(v_payload->>'presentacion'),''),
      nullif(v_payload->>'experiencia_anos','')::numeric,nullif(trim(v_payload->>'guardia'),''),
      nullif(trim(v_payload->>'tecnica_favorita'),''),nullif(trim(v_payload->>'especialidad'),''),
      nullif(trim(v_payload->>'categoria_competitiva'),''),nullif(trim(v_payload->>'competiciones_logros'),''),
      nullif(trim(v_payload->>'objetivos'),''),coalesce((v_payload->>'visible')::boolean,true),v_uid,now()
    )
    on conflict(club_id,socio_id) do update set
      apodo=excluded.apodo,presentacion=excluded.presentacion,experiencia_anos=excluded.experiencia_anos,
      guardia=excluded.guardia,tecnica_favorita=excluded.tecnica_favorita,especialidad=excluded.especialidad,
      categoria_competitiva=excluded.categoria_competitiva,competiciones_logros=excluded.competiciones_logros,
      objetivos=excluded.objetivos,visible=excluded.visible,actualizado_por=v_uid,actualizado_en=now()
    returning * into v_row;
    v_data:=to_jsonb(v_row)-'moderado_por'-'moderacion_motivo';

  elsif p_operation='perfil_deportivo.foto' then
    begin v_socio:=(v_payload->>'socio_id')::uuid; exception when others then raise exception 'SOCIO_ID_INVALIDO'; end;
    if not exists(select 1 from public.socios s where s.club_id=v_club and s.id=v_socio and s.estado='activo') then raise exception 'Alumno no disponible'; end if;
    if not public.app_puede_editar_perfil_deportivo_v032(v_socio) then raise exception 'No puedes editar este perfil deportivo'; end if;
    select foto_path into v_old_path from public.perfiles_deportivos where club_id=v_club and socio_id=v_socio;
    insert into public.perfiles_deportivos(club_id,socio_id,foto_path,visible,actualizado_por,actualizado_en)
    values(v_club,v_socio,nullif(v_payload->>'foto_path',''),false,v_uid,now())
    on conflict(club_id,socio_id) do update set foto_path=excluded.foto_path,actualizado_por=v_uid,actualizado_en=now()
    returning * into v_row;
    v_data:=jsonb_build_object('socio_id',v_socio,'foto_path',v_row.foto_path,'old_foto_path',v_old_path);

  elsif p_operation='perfil_deportivo.moderar' then
    begin v_socio:=(v_payload->>'socio_id')::uuid; exception when others then raise exception 'SOCIO_ID_INVALIDO'; end;
    if not public.app_puede_moderar_perfil_deportivo_v032(v_club) then raise exception 'No tienes permiso para moderar perfiles'; end if;
    v_active:=coalesce((v_payload->>'visible')::boolean,false);
    update public.perfiles_deportivos set
      moderacion_oculta=not v_active,
      moderado_por=case when v_active then null else v_uid end,
      moderacion_motivo=case when v_active then null else nullif(trim(v_payload->>'motivo'),'') end,
      moderado_en=case when v_active then null else now() end,
      actualizado_por=v_uid,actualizado_en=now()
    where club_id=v_club and socio_id=v_socio
    returning * into v_row;
    if v_row.socio_id is null then raise exception 'Perfil deportivo no encontrado'; end if;
    v_data:=jsonb_build_object('socio_id',v_socio,'visible',v_row.visible,'moderado',v_row.moderacion_oculta,'visible_efectivo',(v_row.visible and not v_row.moderacion_oculta));

  elsif p_operation='comunidad.like' then
    begin v_post:=(v_payload->>'publicacion_id')::uuid; exception when others then raise exception 'PUBLICACION_ID_INVALIDA'; end;
    v_active:=coalesce((v_payload->>'activo')::boolean,true);
    if not exists(
      select 1 from public.publicaciones_comunidad p
      where p.club_id=v_club and p.id=v_post and p.estado='publicada' and p.expira_en>now()
    ) then raise exception 'Publicación no disponible'; end if;
    if v_active then
      insert into public.comunidad_likes(club_id,publicacion_id,perfil_id)
      values(v_club,v_post,v_uid) on conflict do nothing;
    else
      delete from public.comunidad_likes
      where club_id=v_club and publicacion_id=v_post and perfil_id=v_uid;
    end if;
    select jsonb_build_object(
      'publicacion_id',p.id,
      'liked',exists(select 1 from public.comunidad_likes l where l.club_id=v_club and l.publicacion_id=v_post and l.perfil_id=v_uid),
      'likes_count',p.likes_count
    ) into v_data
    from public.publicaciones_comunidad p where p.club_id=v_club and p.id=v_post;
  end if;

  v_result:=jsonb_build_object(
    'ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,
    'data',coalesce(v_data,'{}'::jsonb)
  );
  update public.app_mutation_requests set result=v_result,completed_at=now(),club_id=v_club where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end
$$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
