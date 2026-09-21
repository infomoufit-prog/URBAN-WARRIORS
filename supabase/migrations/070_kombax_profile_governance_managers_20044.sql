-- KOMBAX RC13 build 20044 · 070 · gobernanza de perfiles oficiales y multigestor.
-- Competidor: una identidad por cuenta. Marca/Federación: una cuenta puede gestionar varias organizaciones.

begin;

alter table public.perfiles_kombax_directos
  add column if not exists origen_identidad_social_id uuid references public.identidades_sociales(id) on delete set null,
  add column if not exists fecha_nacimiento_verificada date,
  add column if not exists verificacion_version text not null default 'verified-profile-v1';

alter table public.kombax_solicitudes_alta
  add column if not exists schema_version integer not null default 2,
  add column if not exists declaracion_aceptada boolean not null default false,
  add column if not exists declaracion_en timestamptz,
  add column if not exists requisitos_version text not null default 'verified-profile-v1';

-- Sustituye la restricción histórica «una cuenta = un perfil de cada tipo».
-- Se mantiene unicidad personal solo para Competidor. Marca/Federación admiten múltiples entidades.
alter table public.perfiles_kombax_directos drop constraint if exists perfiles_kombax_directos_perfil_id_tipo_key;
drop index if exists perfiles_kombax_directos_perfil_id_tipo_key;
create unique index if not exists uq_kombax_competidor_por_cuenta_v070
  on public.perfiles_kombax_directos(perfil_id) where tipo='competidor';
create index if not exists idx_kombax_directos_owner_tipo_v070 on public.perfiles_kombax_directos(perfil_id,tipo,creado_en desc);
create unique index if not exists uq_kombax_competidor_origen_identidad_v070
  on public.perfiles_kombax_directos(origen_identidad_social_id)
  where tipo='competidor' and origen_identidad_social_id is not null;

-- Una misma cuenta puede abrir solicitudes para varias Marcas/Federaciones, una por perfil directo.
drop index if exists uq_kombax_solicitud_abierta_v043;
create unique index if not exists uq_kombax_solicitud_directa_abierta_v070
  on public.kombax_solicitudes_alta(perfil_directo_id)
  where perfil_directo_id is not null and estado in ('draft','submitted','under_review','needs_information');
create unique index if not exists uq_kombax_solicitud_club_abierta_v070
  on public.kombax_solicitudes_alta(perfil_id)
  where tipo='club' and perfil_directo_id is null and estado in ('draft','submitted','under_review','needs_information');

create table if not exists public.kombax_perfil_gestores(
  id uuid primary key default gen_random_uuid(),
  perfil_directo_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  rol text not null check(rol in ('owner','admin','editor','comunicacion')),
  estado text not null default 'activo' check(estado in ('activo','revocado')),
  concedido_por uuid references public.perfiles(id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique(perfil_directo_id,perfil_id)
);
create index if not exists idx_kombax_perfil_gestores_actor_v070 on public.kombax_perfil_gestores(perfil_id,estado,rol,perfil_directo_id);
alter table public.kombax_perfil_gestores enable row level security;
revoke all on public.kombax_perfil_gestores from public,anon,authenticated;

insert into public.kombax_perfil_gestores(perfil_directo_id,perfil_id,rol,estado,concedido_por)
select d.id,d.perfil_id,'owner','activo',d.perfil_id from public.perfiles_kombax_directos d
on conflict(perfil_directo_id,perfil_id) do update set rol='owner',estado='activo',actualizado_en=now();

create table if not exists public.kombax_verificacion_eventos(
  id bigserial primary key,
  solicitud_id uuid references public.kombax_solicitudes_alta(id) on delete set null,
  perfil_directo_id uuid references public.perfiles_kombax_directos(id) on delete set null,
  actor_perfil_id uuid references public.perfiles(id) on delete set null,
  evento text not null check(evento in (
    'draft_saved','submitted','review_started','information_requested','verified','limited','suspended','rejected','withdrawn',
    'service_activated','service_deactivated','manager_added','manager_updated','manager_removed','member_promoted'
  )),
  detalle jsonb not null default '{}'::jsonb check(jsonb_typeof(detalle)='object'),
  creado_en timestamptz not null default now()
);
create index if not exists idx_kombax_verificacion_eventos_v070 on public.kombax_verificacion_eventos(solicitud_id,perfil_directo_id,creado_en desc);
alter table public.kombax_verificacion_eventos enable row level security;
revoke all on public.kombax_verificacion_eventos from public,anon,authenticated;

create or replace function public.app_kombax_uuid_or_null_v070(p_value text)
returns uuid language plpgsql immutable set search_path=public as $$
begin
  return nullif(btrim(coalesce(p_value,'')),'')::uuid;
exception when others then return null;
end $$;
revoke all on function public.app_kombax_uuid_or_null_v070(text) from public,anon;
grant execute on function public.app_kombax_uuid_or_null_v070(text) to authenticated;

create or replace function public.app_kombax_puede_gestionar_perfil_v070(p_perfil_directo_id uuid,p_scope text default 'read')
returns boolean language sql stable security definer set search_path=public,auth as $$
  select auth.uid() is not null and exists(
    select 1 from public.perfiles_kombax_directos d
    where d.id=p_perfil_directo_id and (
      d.perfil_id=auth.uid()
      or exists(
        select 1 from public.kombax_perfil_gestores g
        where g.perfil_directo_id=d.id and g.perfil_id=auth.uid() and g.estado='activo'
          and case lower(coalesce(p_scope,'read'))
            when 'admin' then g.rol in ('owner','admin')
            when 'edit' then g.rol in ('owner','admin','editor')
            when 'social' then g.rol in ('owner','admin','editor','comunicacion')
            else true
          end
      )
    )
  );
$$;
revoke all on function public.app_kombax_puede_gestionar_perfil_v070(uuid,text) from public,anon;
grant execute on function public.app_kombax_puede_gestionar_perfil_v070(uuid,text) to authenticated;

-- Los gestores autorizados pueden leer el perfil directo que gestionan, nunca perfiles ajenos.
drop policy if exists perfiles_kombax_directos_propios_v040 on public.perfiles_kombax_directos;
drop policy if exists perfiles_kombax_directos_gestion_v070 on public.perfiles_kombax_directos;
create policy perfiles_kombax_directos_gestion_v070 on public.perfiles_kombax_directos
for select to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(id,'read'));

-- Media pública: un gestor autorizado puede trabajar sin compartir contraseñas.
drop policy if exists kombax_public_media_insert_v043 on storage.objects;
drop policy if exists kombax_public_media_insert_v064 on storage.objects;
create policy kombax_public_media_insert_v070 on storage.objects for insert to authenticated with check(
  bucket_id='kombax-public-media'
  and array_length(storage.foldername(name),1)>=3
  and (storage.foldername(name))[1]=auth.uid()::text
  and public.app_kombax_puede_gestionar_perfil_v070(public.app_kombax_uuid_or_null_v070((storage.foldername(name))[2]),'edit')
);
drop policy if exists kombax_public_media_update_v043 on storage.objects;
create policy kombax_public_media_update_v070 on storage.objects for update to authenticated using(
  bucket_id='kombax-public-media'
  and (storage.foldername(name))[1]=auth.uid()::text
) with check(
  bucket_id='kombax-public-media'
  and (storage.foldername(name))[1]=auth.uid()::text
  and public.app_kombax_puede_gestionar_perfil_v070(public.app_kombax_uuid_or_null_v070((storage.foldername(name))[2]),'edit')
);
drop policy if exists kombax_public_media_delete_v043 on storage.objects;
create policy kombax_public_media_delete_v070 on storage.objects for delete to authenticated using(
  bucket_id='kombax-public-media' and (storage.foldername(name))[1]=auth.uid()::text
);

create or replace function public.app_kombax_media_guard_v043()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_count integer;
begin
  if not exists(select 1 from public.perfiles_kombax_directos where id=new.perfil_directo_id) then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;
  if auth.uid() is not null and not public.app_kombax_puede_gestionar_perfil_v070(new.perfil_directo_id,'edit') and not public.app_kombax_es_moderador_v041() then
    raise exception 'KOMBAX_MEDIA_FORBIDDEN';
  end if;
  if new.tipo='photo' and new.estado in ('active','pending_review') then
    select count(*) into v_count from public.kombax_perfil_media
    where perfil_directo_id=new.perfil_directo_id and tipo='photo' and estado in ('active','pending_review') and id<>new.id;
    if v_count>=15 then raise exception 'KOMBAX_ALBUM_PHOTO_LIMIT_HARD_15';end if;
  elsif new.tipo='video' and new.estado in ('active','pending_review') then
    select count(*) into v_count from public.kombax_perfil_media
    where perfil_directo_id=new.perfil_directo_id and tipo='video' and estado in ('active','pending_review') and id<>new.id;
    if v_count>=5 then raise exception 'KOMBAX_ALBUM_VIDEO_LIMIT_HARD_5';end if;
  end if;
  new.actualizado_en:=now();return new;
end $$;
revoke all on function public.app_kombax_media_guard_v043() from public,anon,authenticated;

create or replace function public.app_kombax_profile_managers_v070(p_perfil_directo_id uuid)
returns table(perfil_id uuid,nombre text,rol text,estado text,creado_en timestamptz)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_puede_gestionar_perfil_v070(p_perfil_directo_id,'admin') and not public.app_kombax_es_platform_admin_v055() then
    raise exception 'KOMBAX_PROFILE_ADMIN_REQUIRED';
  end if;
  return query
  select g.perfil_id,nullif(btrim(concat_ws(' ',p.nombre,p.apellidos)),''),g.rol,g.estado,g.creado_en
  from public.kombax_perfil_gestores g join public.perfiles p on p.id=g.perfil_id
  where g.perfil_directo_id=p_perfil_directo_id order by case g.rol when 'owner' then 0 when 'admin' then 1 when 'editor' then 2 else 3 end,p.nombre,p.apellidos;
end $$;
revoke all on function public.app_kombax_profile_managers_v070(uuid) from public,anon;
grant execute on function public.app_kombax_profile_managers_v070(uuid) to authenticated;

create or replace function public.app_kombax_profile_manager_mutate_v070(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_profile uuid;v_target uuid;v_role text;v_row public.kombax_perfil_gestores;v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  begin v_profile:=(p_payload->>'perfil_directo_id')::uuid;exception when others then raise exception 'KOMBAX_PROFILE_ID_INVALID';end;
  begin v_target:=(p_payload->>'perfil_id')::uuid;exception when others then raise exception 'KOMBAX_MANAGER_ID_INVALID';end;
  if not public.app_kombax_puede_gestionar_perfil_v070(v_profile,'admin') and not public.app_kombax_es_platform_admin_v055() then raise exception 'KOMBAX_PROFILE_ADMIN_REQUIRED';end if;
  if not exists(select 1 from public.perfiles where id=v_target) then raise exception 'KOMBAX_MANAGER_NOT_FOUND';end if;
  if exists(select 1 from public.perfiles_kombax_directos d where d.id=v_profile and d.perfil_id=v_target) and p_operation<>'kombax.profile.manager.update' then
    raise exception 'KOMBAX_OWNER_CANNOT_BE_REPLACED';
  end if;
  if p_operation in ('kombax.profile.manager.add','kombax.profile.manager.update') then
    v_role:=lower(btrim(coalesce(p_payload->>'rol','editor')));
    if v_role not in ('admin','editor','comunicacion') then raise exception 'KOMBAX_MANAGER_ROLE_INVALID';end if;
    insert into public.kombax_perfil_gestores(perfil_directo_id,perfil_id,rol,estado,concedido_por)
    values(v_profile,v_target,v_role,'activo',v_uid)
    on conflict(perfil_directo_id,perfil_id) do update set rol=excluded.rol,estado='activo',concedido_por=v_uid,actualizado_en=now()
    returning * into v_row;
    insert into public.kombax_verificacion_eventos(perfil_directo_id,actor_perfil_id,evento,detalle)
    values(v_profile,v_uid,case when p_operation='kombax.profile.manager.add' then 'manager_added' else 'manager_updated' end,jsonb_build_object('perfil_id',v_target,'rol',v_role));
  elsif p_operation='kombax.profile.manager.remove' then
    update public.kombax_perfil_gestores set estado='revocado',actualizado_en=now()
    where perfil_directo_id=v_profile and perfil_id=v_target and rol<>'owner' returning * into v_row;
    if v_row.id is null then raise exception 'KOMBAX_MANAGER_NOT_FOUND';end if;
    insert into public.kombax_verificacion_eventos(perfil_directo_id,actor_perfil_id,evento,detalle)
    values(v_profile,v_uid,'manager_removed',jsonb_build_object('perfil_id',v_target,'rol',v_row.rol));
  else raise exception 'KOMBAX_MANAGER_OPERATION_NOT_ALLOWED';end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('perfil_directo_id',v_profile,'perfil_id',v_target,'rol',v_row.rol,'estado',v_row.estado));
  return v_result;
end $$;
revoke all on function public.app_kombax_profile_manager_mutate_v070(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_profile_manager_mutate_v070(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
