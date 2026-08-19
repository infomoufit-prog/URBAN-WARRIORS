-- KOMBAX RC13 build 20027 · perfiles globales, alta/verificación y álbum público.
-- Esta migración NO crea tenants automáticamente ni concede verificación por autorregistro.
-- Los documentos de verificación permanecen privados y separados del álbum público.

begin;

insert into public.kombax_capacidades(clave,descripcion,sensible) values
  ('profile.direct.manage','Gestión del perfil directo KOMBAX propio',true),
  ('profile.album.publish','Publicación de álbum en perfil KOMBAX verificado',true),
  ('verification.review','Revisión global de altas y verificaciones KOMBAX',true)
on conflict(clave) do nothing;

alter table public.perfiles_kombax_directos
  add column if not exists workflow_estado text not null default 'draft',
  add column if not exists ubicacion text,
  add column if not exists disciplinas text[] not null default '{}'::text[],
  add column if not exists categoria text,
  add column if not exists club_declarado text,
  add column if not exists web_publica text,
  add column if not exists avatar_path text,
  add column if not exists banner_path text,
  add column if not exists verificado_en timestamptz,
  add column if not exists verificado_por uuid references public.perfiles(id) on delete set null;

alter table public.perfiles_kombax_directos drop constraint if exists perfiles_kombax_directos_workflow_estado_check;
alter table public.perfiles_kombax_directos add constraint perfiles_kombax_directos_workflow_estado_check
  check(workflow_estado in ('draft','submitted','under_review','needs_information','verified','limited','suspended','rejected'));
alter table public.perfiles_kombax_directos drop constraint if exists perfiles_kombax_directos_web_publica_check;
alter table public.perfiles_kombax_directos add constraint perfiles_kombax_directos_web_publica_check
  check(web_publica is null or web_publica ~* '^https://[^[:space:]]+$');
alter table public.perfiles_kombax_directos drop constraint if exists perfiles_kombax_directos_disciplinas_check;
alter table public.perfiles_kombax_directos add constraint perfiles_kombax_directos_disciplinas_check
  check(cardinality(disciplinas)<=12);

update public.perfiles_kombax_directos set workflow_estado=case
  when estado='activo' and verificacion_estado='verificado' then 'verified'
  when estado='suspendido' then 'suspended'
  when verificacion_estado='rechazado' then 'rejected'
  when estado='pendiente_verificacion' then 'submitted'
  else 'draft' end
where workflow_estado='draft';

create table if not exists public.kombax_solicitudes_alta(
  id uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  tipo text not null check(tipo in ('club','competidor','marca','federacion','profesional')),
  perfil_directo_id uuid references public.perfiles_kombax_directos(id) on delete set null,
  nombre_publico text not null check(char_length(btrim(nombre_publico)) between 2 and 160),
  datos_publicos jsonb not null default '{}'::jsonb check(jsonb_typeof(datos_publicos)='object'),
  datos_verificacion jsonb not null default '{}'::jsonb check(jsonb_typeof(datos_verificacion)='object'),
  estado text not null default 'draft' check(estado in ('draft','submitted','under_review','needs_information','verified','limited','suspended','rejected','withdrawn')),
  motivo_revision text check(char_length(coalesce(motivo_revision,''))<=2000),
  revisado_por uuid references public.perfiles(id) on delete set null,
  enviado_en timestamptz,
  revisado_en timestamptz,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
create unique index if not exists uq_kombax_solicitud_abierta_v043 on public.kombax_solicitudes_alta(perfil_id,tipo)
  where estado in ('draft','submitted','under_review','needs_information');
create index if not exists idx_kombax_solicitudes_estado_v043 on public.kombax_solicitudes_alta(estado,tipo,creado_en desc);

create table if not exists public.kombax_verificacion_documentos(
  id uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.kombax_solicitudes_alta(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  tipo_documento text not null check(char_length(btrim(tipo_documento)) between 2 and 80),
  storage_path text not null unique,
  mime_type text not null check(mime_type in ('application/pdf','image/jpeg','image/png','image/webp')),
  bytes bigint not null check(bytes between 1 and 15728640),
  estado text not null default 'active' check(estado in ('active','removed')),
  creado_en timestamptz not null default now(),
  retirado_en timestamptz
);

create table if not exists public.kombax_perfil_media(
  id uuid primary key default gen_random_uuid(),
  perfil_directo_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
  tipo text not null check(tipo in ('avatar','banner','photo','video')),
  storage_path text not null unique,
  mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime')),
  bytes bigint not null check(bytes between 1 and 26214400),
  width integer check(width is null or width between 1 and 8192),
  height integer check(height is null or height between 1 and 8192),
  duration_seconds numeric(6,2),
  position integer not null default 0 check(position between 0 and 99),
  estado text not null default 'active' check(estado in ('active','hidden','removed','pending_review')),
  moderacion_motivo text check(char_length(coalesce(moderacion_motivo,''))<=1000),
  creado_por uuid not null references public.perfiles(id) on delete restrict,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  check((tipo='video' and mime_type like 'video/%' and duration_seconds is not null and duration_seconds>0 and duration_seconds<=15)
     or (tipo<>'video' and mime_type like 'image/%' and duration_seconds is null))
);
create index if not exists idx_kombax_perfil_media_v043 on public.kombax_perfil_media(perfil_directo_id,estado,tipo,position,creado_en);
create unique index if not exists uq_kombax_perfil_avatar_v043 on public.kombax_perfil_media(perfil_directo_id) where tipo='avatar' and estado in ('active','pending_review');
create unique index if not exists uq_kombax_perfil_banner_v043 on public.kombax_perfil_media(perfil_directo_id) where tipo='banner' and estado in ('active','pending_review');

alter table public.kombax_solicitudes_alta enable row level security;
alter table public.kombax_verificacion_documentos enable row level security;
alter table public.kombax_perfil_media enable row level security;
revoke all on public.kombax_solicitudes_alta,public.kombax_verificacion_documentos,public.kombax_perfil_media from public,anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('kombax-public-media','kombax-public-media',true,26214400,array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime']::text[])
on conflict(id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('kombax-verification-docs','kombax-verification-docs',false,15728640,array['application/pdf','image/jpeg','image/png','image/webp']::text[])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

-- Objetos de álbum: ruta obligatoria auth.uid()/perfil_directo_id/uuid.ext.
drop policy if exists kombax_public_media_insert_v043 on storage.objects;
create policy kombax_public_media_insert_v043 on storage.objects for insert to authenticated with check(
  bucket_id='kombax-public-media' and array_length(storage.foldername(name),1)>=3
  and (storage.foldername(name))[1]=auth.uid()::text
  and exists(select 1 from public.perfiles_kombax_directos d where d.id::text=(storage.foldername(name))[2] and d.perfil_id=auth.uid())
);
drop policy if exists kombax_public_media_update_v043 on storage.objects;
create policy kombax_public_media_update_v043 on storage.objects for update to authenticated using(
  bucket_id='kombax-public-media' and (storage.foldername(name))[1]=auth.uid()::text
) with check(bucket_id='kombax-public-media' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists kombax_public_media_delete_v043 on storage.objects;
create policy kombax_public_media_delete_v043 on storage.objects for delete to authenticated using(
  bucket_id='kombax-public-media' and (storage.foldername(name))[1]=auth.uid()::text
);

-- Documentación: nunca pública y solo propietario / moderación global.
drop policy if exists kombax_verification_docs_select_v043 on storage.objects;
create policy kombax_verification_docs_select_v043 on storage.objects for select to authenticated using(
  bucket_id='kombax-verification-docs' and ((storage.foldername(name))[1]=auth.uid()::text or public.app_kombax_es_moderador_v041())
);
drop policy if exists kombax_verification_docs_insert_v043 on storage.objects;
create policy kombax_verification_docs_insert_v043 on storage.objects for insert to authenticated with check(
  bucket_id='kombax-verification-docs' and array_length(storage.foldername(name),1)>=3 and (storage.foldername(name))[1]=auth.uid()::text
);
drop policy if exists kombax_verification_docs_delete_v043 on storage.objects;
create policy kombax_verification_docs_delete_v043 on storage.objects for delete to authenticated using(
  bucket_id='kombax-verification-docs' and ((storage.foldername(name))[1]=auth.uid()::text or public.app_kombax_es_moderador_v041())
);

create or replace function public.app_kombax_slug_v043(p_value text)
returns text language sql immutable set search_path=public as $$
  select trim(both '-' from regexp_replace(lower(translate(coalesce(p_value,''),'áéíóúüñÁÉÍÓÚÜÑ','aeiouunAEIOUUN')),'[^a-z0-9]+','-','g'));
$$;
revoke all on function public.app_kombax_slug_v043(text) from public,anon,authenticated;

create or replace function public.app_kombax_media_guard_v043()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_owner uuid;v_count integer;
begin
  select perfil_id into v_owner from public.perfiles_kombax_directos where id=new.perfil_directo_id;
  if v_owner is null then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;
  if auth.uid() is not null and auth.uid()<>v_owner and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MEDIA_FORBIDDEN';end if;
  if new.tipo='photo' and new.estado in ('active','pending_review') then
    select count(*) into v_count from public.kombax_perfil_media where perfil_directo_id=new.perfil_directo_id and tipo='photo' and estado in ('active','pending_review') and id<>new.id;
    if v_count>=10 then raise exception 'KOMBAX_ALBUM_PHOTO_LIMIT_10';end if;
  elsif new.tipo='video' and new.estado in ('active','pending_review') then
    select count(*) into v_count from public.kombax_perfil_media where perfil_directo_id=new.perfil_directo_id and tipo='video' and estado in ('active','pending_review') and id<>new.id;
    if v_count>=3 then raise exception 'KOMBAX_ALBUM_VIDEO_LIMIT_3';end if;
  end if;
  new.actualizado_en:=now();return new;
end $$;
revoke all on function public.app_kombax_media_guard_v043() from public,anon,authenticated;
drop trigger if exists kombax_media_guard_v043 on public.kombax_perfil_media;
create trigger kombax_media_guard_v043 before insert or update on public.kombax_perfil_media for each row execute function public.app_kombax_media_guard_v043();

create or replace function public.app_kombax_mis_perfiles_v043()
returns table(id uuid,tipo text,slug text,nombre_publico text,descripcion text,workflow_estado text,verificacion_estado text,publico boolean,ubicacion text,disciplinas text[],categoria text,club_declarado text,web_publica text,avatar_path text,banner_path text,actualizado_en timestamptz)
language sql stable security definer set search_path=public,auth as $$
  select d.id,d.tipo,d.slug,d.nombre_publico,d.descripcion,d.workflow_estado,d.verificacion_estado,d.publico,d.ubicacion,d.disciplinas,d.categoria,d.club_declarado,d.web_publica,d.avatar_path,d.banner_path,d.actualizado_en
  from public.perfiles_kombax_directos d where d.perfil_id=auth.uid() order by d.creado_en;
$$;
revoke all on function public.app_kombax_mis_perfiles_v043() from public,anon;
grant execute on function public.app_kombax_mis_perfiles_v043() to authenticated;

create or replace function public.app_kombax_mis_solicitudes_v043()
returns table(id uuid,tipo text,perfil_directo_id uuid,nombre_publico text,datos_publicos jsonb,datos_verificacion jsonb,estado text,motivo_revision text,enviado_en timestamptz,revisado_en timestamptz,actualizado_en timestamptz)
language sql stable security definer set search_path=public,auth as $$
  select s.id,s.tipo,s.perfil_directo_id,s.nombre_publico,s.datos_publicos,s.datos_verificacion,s.estado,s.motivo_revision,s.enviado_en,s.revisado_en,s.actualizado_en
  from public.kombax_solicitudes_alta s where s.perfil_id=auth.uid() order by s.creado_en desc;
$$;
revoke all on function public.app_kombax_mis_solicitudes_v043() from public,anon;
grant execute on function public.app_kombax_mis_solicitudes_v043() to authenticated;

create or replace function public.app_kombax_album_v043(p_perfil_directo_id uuid)
returns table(id uuid,tipo text,storage_path text,mime_type text,bytes bigint,width integer,height integer,duration_seconds numeric,"position" integer,estado text,creado_en timestamptz)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_owner uuid;v_public boolean;v_verified boolean;
begin
  select d.perfil_id,d.publico,(d.workflow_estado='verified' and d.estado='activo' and d.verificacion_estado='verificado') into v_owner,v_public,v_verified
  from public.perfiles_kombax_directos d where d.id=p_perfil_directo_id;
  if v_owner is null then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;
  if auth.uid()<>v_owner and not public.app_kombax_es_moderador_v041() and not (v_public and v_verified) then raise exception 'KOMBAX_PROFILE_NOT_PUBLIC';end if;
  return query select m.id,m.tipo,m.storage_path,m.mime_type,m.bytes,m.width,m.height,m.duration_seconds,m.position,m.estado,m.creado_en
  from public.kombax_perfil_media m where m.perfil_directo_id=p_perfil_directo_id
    and (auth.uid()=v_owner or public.app_kombax_es_moderador_v041() or m.estado='active')
  order by case m.tipo when 'avatar' then 0 when 'banner' then 1 when 'photo' then 2 else 3 end,m.position,m.creado_en;
end $$;
revoke all on function public.app_kombax_album_v043(uuid) from public,anon;
grant execute on function public.app_kombax_album_v043(uuid) to authenticated;

create or replace function public.app_kombax_perfil_mutate_v043(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;
  v_type text;v_name text;v_slug text;v_id uuid;v_profile public.perfiles_kombax_directos;v_request public.kombax_solicitudes_alta;v_doc public.kombax_verificacion_documentos;v_state text;v_reason text;v_public jsonb;v_verify jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  delete from public.app_mutation_requests where user_id=v_uid and club_id is null and created_at<now()-interval '30 days';
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation);end if;

  if p_operation='kombax.profile.save' then
    v_type:=lower(btrim(coalesce(v_payload->>'tipo','')));
    if v_type not in ('competidor','marca','federacion','profesional') then raise exception 'KOMBAX_PROFILE_TYPE_NOT_OPEN';end if;
    v_name:=btrim(coalesce(v_payload->>'nombre_publico',''));if char_length(v_name)<2 or char_length(v_name)>160 then raise exception 'KOMBAX_PROFILE_NAME_INVALID';end if;
    begin v_id:=nullif(coalesce(v_payload->>'id',v_payload->>'perfil_directo_id'),'')::uuid;exception when others then raise exception 'KOMBAX_PROFILE_ID_INVALID';end;
    if v_id is null then
      v_slug:=public.app_kombax_slug_v043(coalesce(nullif(v_payload->>'slug',''),v_name));if char_length(v_slug)<2 then raise exception 'KOMBAX_PROFILE_SLUG_INVALID';end if;
      if exists(select 1 from public.perfiles_kombax_directos where slug=v_slug) then v_slug:=left(v_slug,50)||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,8);end if;
      insert into public.perfiles_kombax_directos(perfil_id,tipo,slug,nombre_publico,descripcion,workflow_estado,ubicacion,disciplinas,categoria,club_declarado,web_publica,publico)
      values(v_uid,v_type,v_slug,v_name,left(nullif(btrim(v_payload->>'descripcion'),''),1600),'draft',left(nullif(btrim(v_payload->>'ubicacion'),''),160),
        coalesce(array(select jsonb_array_elements_text(coalesce(v_payload->'disciplinas','[]'::jsonb)) limit 12),'{}'::text[]),left(nullif(btrim(v_payload->>'categoria'),''),120),left(nullif(btrim(v_payload->>'club_declarado'),''),160),nullif(btrim(v_payload->>'web_publica'),''),false)
      returning * into v_profile;
      insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen) values('perfil_directo',v_profile.id,'profile.direct.manage',true,'manual') on conflict do nothing;
    else
      select * into v_profile from public.perfiles_kombax_directos where id=v_id and perfil_id=v_uid for update;if v_profile.id is null then raise exception 'KOMBAX_PROFILE_NOT_OWNED';end if;
      if v_profile.workflow_estado in ('under_review','verified','suspended') then raise exception 'KOMBAX_PROFILE_LOCKED_FOR_REVIEW';end if;
      update public.perfiles_kombax_directos set nombre_publico=v_name,descripcion=left(nullif(btrim(v_payload->>'descripcion'),''),1600),ubicacion=left(nullif(btrim(v_payload->>'ubicacion'),''),160),
        disciplinas=coalesce(array(select jsonb_array_elements_text(coalesce(v_payload->'disciplinas','[]'::jsonb)) limit 12),'{}'::text[]),categoria=left(nullif(btrim(v_payload->>'categoria'),''),120),club_declarado=left(nullif(btrim(v_payload->>'club_declarado'),''),160),web_publica=nullif(btrim(v_payload->>'web_publica'),''),actualizado_en=now()
      where id=v_id returning * into v_profile;
    end if;
    v_result:=to_jsonb(v_profile);

  elsif p_operation='kombax.application.save' then
    v_type:=lower(btrim(coalesce(v_payload->>'tipo','')));if v_type not in ('club','competidor','marca','federacion','profesional') then raise exception 'KOMBAX_APPLICATION_TYPE_INVALID';end if;
    v_name:=btrim(coalesce(v_payload->>'nombre_publico',''));if char_length(v_name)<2 or char_length(v_name)>160 then raise exception 'KOMBAX_APPLICATION_NAME_INVALID';end if;
    begin v_id:=nullif(v_payload->>'perfil_directo_id','')::uuid;exception when others then raise exception 'KOMBAX_PROFILE_ID_INVALID';end;
    if v_type<>'club' and (v_id is null or not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_id and d.perfil_id=v_uid and d.tipo=v_type)) then raise exception 'KOMBAX_DIRECT_PROFILE_REQUIRED';end if;
    v_public:=coalesce(v_payload->'datos_publicos','{}'::jsonb);v_verify:=coalesce(v_payload->'datos_verificacion','{}'::jsonb);
    insert into public.kombax_solicitudes_alta(perfil_id,tipo,perfil_directo_id,nombre_publico,datos_publicos,datos_verificacion,estado)
    values(v_uid,v_type,v_id,v_name,v_public,v_verify,'draft')
    on conflict(perfil_id,tipo) where estado in ('draft','submitted','under_review','needs_information') do update set nombre_publico=excluded.nombre_publico,perfil_directo_id=coalesce(excluded.perfil_directo_id,kombax_solicitudes_alta.perfil_directo_id),datos_publicos=excluded.datos_publicos,datos_verificacion=excluded.datos_verificacion,actualizado_en=now()
    returning * into v_request;
    v_result:=to_jsonb(v_request)-'datos_verificacion';

  elsif p_operation='kombax.application.submit' then
    begin v_id:=(v_payload->>'solicitud_id')::uuid;exception when others then raise exception 'KOMBAX_APPLICATION_ID_INVALID';end;
    select * into v_request from public.kombax_solicitudes_alta where id=v_id and perfil_id=v_uid for update;
    if v_request.id is null or v_request.estado not in ('draft','needs_information') then raise exception 'KOMBAX_APPLICATION_NOT_SUBMITTABLE';end if;
    if jsonb_object_length(v_request.datos_verificacion)=0 then raise exception 'KOMBAX_VERIFICATION_DATA_REQUIRED';end if;
    update public.kombax_solicitudes_alta set estado='submitted',enviado_en=coalesce(enviado_en,now()),motivo_revision=null,actualizado_en=now() where id=v_id returning * into v_request;
    if v_request.perfil_directo_id is not null then update public.perfiles_kombax_directos set workflow_estado='submitted',estado='pendiente_verificacion',verificacion_estado='pendiente',publico=false,actualizado_en=now() where id=v_request.perfil_directo_id;end if;
    v_result:=to_jsonb(v_request)-'datos_verificacion';

  elsif p_operation='kombax.application.withdraw' then
    begin v_id:=(v_payload->>'solicitud_id')::uuid;exception when others then raise exception 'KOMBAX_APPLICATION_ID_INVALID';end;
    update public.kombax_solicitudes_alta set estado='withdrawn',actualizado_en=now() where id=v_id and perfil_id=v_uid and estado in ('draft','submitted','needs_information') returning * into v_request;
    if v_request.id is null then raise exception 'KOMBAX_APPLICATION_NOT_WITHDRAWABLE';end if;
    if v_request.perfil_directo_id is not null then update public.perfiles_kombax_directos set workflow_estado='draft',estado='borrador',verificacion_estado='no_iniciada',publico=false,actualizado_en=now() where id=v_request.perfil_directo_id;end if;
    v_result:=jsonb_build_object('id',v_request.id,'estado',v_request.estado);

  elsif p_operation='kombax.application.document.add' then
    begin v_id:=(v_payload->>'solicitud_id')::uuid;exception when others then raise exception 'KOMBAX_APPLICATION_ID_INVALID';end;
    select * into v_request from public.kombax_solicitudes_alta where id=v_id and perfil_id=v_uid and estado in ('draft','needs_information','submitted');if v_request.id is null then raise exception 'KOMBAX_APPLICATION_DOCUMENT_FORBIDDEN';end if;
    if btrim(coalesce(v_payload->>'storage_path',''))='' or split_part(v_payload->>'storage_path','/',1)<>v_uid::text or split_part(v_payload->>'storage_path','/',2)<>v_id::text then raise exception 'KOMBAX_VERIFICATION_PATH_INVALID';end if;
    insert into public.kombax_verificacion_documentos(solicitud_id,perfil_id,tipo_documento,storage_path,mime_type,bytes)
    values(v_id,v_uid,left(btrim(v_payload->>'tipo_documento'),80),btrim(v_payload->>'storage_path'),lower(btrim(v_payload->>'mime_type')),(v_payload->>'bytes')::bigint) returning * into v_doc;
    v_result:=jsonb_build_object('id',v_doc.id,'solicitud_id',v_doc.solicitud_id,'tipo_documento',v_doc.tipo_documento,'storage_path',v_doc.storage_path,'mime_type',v_doc.mime_type,'bytes',v_doc.bytes);

  elsif p_operation='kombax.application.review' then
    if not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;
    begin v_id:=(v_payload->>'solicitud_id')::uuid;exception when others then raise exception 'KOMBAX_APPLICATION_ID_INVALID';end;
    v_state:=lower(btrim(coalesce(v_payload->>'estado','')));if v_state not in ('under_review','needs_information','verified','limited','suspended','rejected') then raise exception 'KOMBAX_REVIEW_STATE_INVALID';end if;
    v_reason:=left(nullif(btrim(v_payload->>'motivo'),''),2000);
    update public.kombax_solicitudes_alta set estado=v_state,motivo_revision=v_reason,revisado_por=v_uid,revisado_en=now(),actualizado_en=now() where id=v_id and estado not in ('withdrawn') returning * into v_request;
    if v_request.id is null then raise exception 'KOMBAX_APPLICATION_NOT_FOUND';end if;
    if v_request.perfil_directo_id is not null then
      update public.perfiles_kombax_directos set workflow_estado=v_state,
        estado=case v_state when 'verified' then 'activo' when 'suspended' then 'suspendido' when 'rejected' then 'cerrado' when 'limited' then 'activo' else 'pendiente_verificacion' end,
        verificacion_estado=case v_state when 'verified' then 'verificado' when 'rejected' then 'rechazado' else 'pendiente' end,
        publico=(v_state='verified'),verificado_en=case when v_state='verified' then now() else verificado_en end,verificado_por=case when v_state='verified' then v_uid else verificado_por end,actualizado_en=now()
      where id=v_request.perfil_directo_id returning * into v_profile;
      if v_state='verified' then
        insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,asignada_por) values
          ('perfil_directo',v_profile.id,'social.read',true,'manual',v_uid),('perfil_directo',v_profile.id,'social.publish',true,'manual',v_uid),('perfil_directo',v_profile.id,'contact.request',true,'manual',v_uid),('perfil_directo',v_profile.id,'profile.album.publish',true,'manual',v_uid)
        on conflict do nothing;
        if v_profile.tipo='marca' then insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,asignada_por) values('perfil_directo',v_profile.id,'showcase.publish',true,'manual',v_uid) on conflict do nothing;end if;
      end if;
    end if;
    v_result:=jsonb_build_object('id',v_request.id,'estado',v_request.estado,'perfil_directo_id',v_request.perfil_directo_id);
  else raise exception 'KOMBAX_PROFILE_OPERATION_NOT_ALLOWED';end if;

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_perfil_mutate_v043(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_perfil_mutate_v043(text,jsonb,uuid) to authenticated;

create or replace function public.app_kombax_media_mutate_v043(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_profile uuid;v_id uuid;v_media public.kombax_perfil_media;v_type text;v_path text;v_mime text;v_bytes bigint;v_duration numeric;v_state text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation);end if;
  if p_operation='kombax.media.add' then
    begin v_profile:=(v_payload->>'perfil_directo_id')::uuid;exception when others then raise exception 'KOMBAX_PROFILE_ID_INVALID';end;
    if not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_profile and d.perfil_id=v_uid and d.workflow_estado in ('verified','limited')) then raise exception 'KOMBAX_PROFILE_MEDIA_REQUIRES_VERIFIED_PROFILE';end if;
    v_type:=lower(btrim(coalesce(v_payload->>'tipo','')));if v_type not in ('avatar','banner','photo','video') then raise exception 'KOMBAX_MEDIA_TYPE_INVALID';end if;
    v_path:=btrim(coalesce(v_payload->>'storage_path',''));if v_path='' or split_part(v_path,'/',1)<>v_uid::text or split_part(v_path,'/',2)<>v_profile::text then raise exception 'KOMBAX_MEDIA_PATH_INVALID';end if;
    v_mime:=lower(btrim(coalesce(v_payload->>'mime_type','')));begin v_bytes:=(v_payload->>'bytes')::bigint;exception when others then raise exception 'KOMBAX_MEDIA_SIZE_INVALID';end;
    begin v_duration:=nullif(v_payload->>'duration_seconds','')::numeric;exception when others then raise exception 'KOMBAX_MEDIA_DURATION_INVALID';end;
    if v_type='video' and (v_duration is null or v_duration<=0 or v_duration>15) then raise exception 'KOMBAX_VIDEO_MAX_15_SECONDS';end if;
    if v_type in ('avatar','banner') then update public.kombax_perfil_media set estado='removed',actualizado_en=now() where perfil_directo_id=v_profile and tipo=v_type and estado in ('active','pending_review');end if;
    insert into public.kombax_perfil_media(perfil_directo_id,tipo,storage_path,mime_type,bytes,width,height,duration_seconds,position,estado,creado_por)
    values(v_profile,v_type,v_path,v_mime,v_bytes,nullif(v_payload->>'width','')::integer,nullif(v_payload->>'height','')::integer,v_duration,coalesce(nullif(v_payload->>'position','')::integer,0),'active',v_uid) returning * into v_media;
    if v_type='avatar' then update public.perfiles_kombax_directos set avatar_path=v_path,actualizado_en=now() where id=v_profile;elsif v_type='banner' then update public.perfiles_kombax_directos set banner_path=v_path,actualizado_en=now() where id=v_profile;end if;
    v_result:=to_jsonb(v_media);
  elsif p_operation='kombax.media.remove' then
    begin v_id:=(v_payload->>'media_id')::uuid;exception when others then raise exception 'KOMBAX_MEDIA_ID_INVALID';end;
    select m.* into v_media from public.kombax_perfil_media m join public.perfiles_kombax_directos d on d.id=m.perfil_directo_id where m.id=v_id and (d.perfil_id=v_uid or public.app_kombax_es_moderador_v041()) for update;
    if v_media.id is null then raise exception 'KOMBAX_MEDIA_NOT_FOUND';end if;
    update public.kombax_perfil_media set estado='removed',actualizado_en=now() where id=v_id returning * into v_media;
    update public.perfiles_kombax_directos set avatar_path=case when avatar_path=v_media.storage_path then null else avatar_path end,banner_path=case when banner_path=v_media.storage_path then null else banner_path end,actualizado_en=now() where id=v_media.perfil_directo_id;
    v_result:=jsonb_build_object('id',v_media.id,'storage_path',v_media.storage_path,'estado',v_media.estado);
  elsif p_operation='kombax.media.moderate' then
    if not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;
    begin v_id:=(v_payload->>'media_id')::uuid;exception when others then raise exception 'KOMBAX_MEDIA_ID_INVALID';end;
    v_state:=lower(btrim(coalesce(v_payload->>'estado','')));if v_state not in ('active','hidden','removed') then raise exception 'KOMBAX_MEDIA_STATE_INVALID';end if;
    update public.kombax_perfil_media set estado=v_state,moderacion_motivo=left(nullif(btrim(v_payload->>'motivo'),''),1000),actualizado_en=now() where id=v_id returning * into v_media;if v_media.id is null then raise exception 'KOMBAX_MEDIA_NOT_FOUND';end if;
    v_result:=jsonb_build_object('id',v_media.id,'estado',v_media.estado);
  else raise exception 'KOMBAX_MEDIA_OPERATION_NOT_ALLOWED';end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_media_mutate_v043(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_media_mutate_v043(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
