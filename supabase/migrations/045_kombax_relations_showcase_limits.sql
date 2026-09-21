-- KOMBAX RC13 build 20027 · relaciones verificadas + Showcase Club/Marca con límites.
-- KOMBAX no usa seguidores. Las relaciones visibles requieren aceptación de ambas partes o moderación.

begin;

create table if not exists public.kombax_relaciones(
  id uuid primary key default gen_random_uuid(),
  origen_social_id uuid not null references public.kombax_social_perfiles(id) on delete cascade,
  destino_social_id uuid not null references public.kombax_social_perfiles(id) on delete cascade,
  tipo text not null check(tipo in ('competidor_club','club_federacion','competidor_profesional','marca_club','marca_competidor','profesional_evento','profesional_club')),
  estado text not null default 'pending' check(estado in ('pending','confirmed','rejected','ended','suspended')),
  solicitado_por uuid not null references public.perfiles(id) on delete restrict,
  confirmado_por uuid references public.perfiles(id) on delete set null,
  moderado_por uuid references public.perfiles(id) on delete set null,
  nota text check(char_length(coalesce(nota,''))<=500),
  creado_en timestamptz not null default now(),
  confirmado_en timestamptz,
  finalizado_en timestamptz,
  check(origen_social_id<>destino_social_id)
);
create unique index if not exists uq_kombax_relacion_abierta_v045 on public.kombax_relaciones(origen_social_id,destino_social_id,tipo) where estado in ('pending','confirmed');
create index if not exists idx_kombax_relaciones_perfil_v045 on public.kombax_relaciones(origen_social_id,estado,creado_en desc);
create index if not exists idx_kombax_relaciones_destino_v045 on public.kombax_relaciones(destino_social_id,estado,creado_en desc);
alter table public.kombax_relaciones enable row level security;
revoke all on public.kombax_relaciones from public,anon,authenticated;

create or replace function public.app_kombax_social_tipo_v045(p_social_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select case when sp.sujeto_tipo='club' then 'club' when sp.sujeto_tipo='miembro' then 'competidor'
    else coalesce((select d.tipo from public.perfiles_kombax_directos d where d.id=sp.perfil_directo_id),'profesional') end
  from public.kombax_social_perfiles sp where sp.id=p_social_id;
$$;
revoke all on function public.app_kombax_social_tipo_v045(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_relacion_tipo_valido_v045(p_from uuid,p_to uuid,p_type text)
returns boolean language plpgsql stable security definer set search_path=public as $$
declare a text:=public.app_kombax_social_tipo_v045(p_from);b text:=public.app_kombax_social_tipo_v045(p_to);t text:=lower(coalesce(p_type,''));
begin
  if a is null or b is null then return false;end if;
  return case t
    when 'competidor_club' then (a='competidor' and b='club') or (a='club' and b='competidor')
    when 'club_federacion' then (a='club' and b='federacion') or (a='federacion' and b='club')
    when 'competidor_profesional' then (a='competidor' and b='profesional') or (a='profesional' and b='competidor')
    when 'marca_club' then (a='marca' and b='club') or (a='club' and b='marca')
    when 'marca_competidor' then (a='marca' and b='competidor') or (a='competidor' and b='marca')
    when 'profesional_club' then (a='profesional' and b='club') or (a='club' and b='profesional')
    when 'profesional_evento' then a='profesional' or b='profesional'
    else false end;
end $$;
revoke all on function public.app_kombax_relacion_tipo_valido_v045(uuid,uuid,text) from public,anon;
grant execute on function public.app_kombax_relacion_tipo_valido_v045(uuid,uuid,text) to authenticated;

create or replace function public.app_kombax_relaciones_v045(p_social_id uuid)
returns table(id uuid,origen_social_id uuid,origen_nombre text,destino_social_id uuid,destino_nombre text,tipo text,estado text,nota text,creado_en timestamptz,confirmado_en timestamptz,gestionable boolean)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  return query select r.id,r.origen_social_id,o.nombre_publico,r.destino_social_id,d.nombre_publico,r.tipo,r.estado,r.nota,r.creado_en,r.confirmado_en,
    r.estado='pending' and public.app_kombax_social_puede_publicar_v041(r.destino_social_id)
  from public.kombax_relaciones r join public.kombax_social_perfiles o on o.id=r.origen_social_id join public.kombax_social_perfiles d on d.id=r.destino_social_id
  where (r.origen_social_id=p_social_id or r.destino_social_id=p_social_id) and (r.estado='confirmed' or public.app_kombax_social_puede_publicar_v041(r.origen_social_id) or public.app_kombax_social_puede_publicar_v041(r.destino_social_id) or public.app_kombax_es_moderador_v041())
  order by case r.estado when 'confirmed' then 0 when 'pending' then 1 else 2 end,r.creado_en desc;
end $$;
revoke all on function public.app_kombax_relaciones_v045(uuid) from public,anon;
grant execute on function public.app_kombax_relaciones_v045(uuid) to authenticated;

create or replace function public.app_kombax_relacion_mutate_v045(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_id uuid;v_from uuid;v_to uuid;v_type text;v_state text;v_rel public.kombax_relaciones;v_note text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);end if;
  if p_operation='kombax.relation.request' then
    begin v_from:=(v_payload->>'origen_social_id')::uuid;v_to:=(v_payload->>'destino_social_id')::uuid;exception when others then raise exception 'KOMBAX_RELATION_PROFILES_INVALID';end;
    if not public.app_kombax_social_puede_publicar_v041(v_from) then raise exception 'KOMBAX_RELATION_SOURCE_NOT_OWNED';end if;
    v_type:=lower(coalesce(v_payload->>'tipo',''));if not public.app_kombax_relacion_tipo_valido_v045(v_from,v_to,v_type) then raise exception 'KOMBAX_RELATION_TYPE_INVALID';end if;
    if not exists(select 1 from public.kombax_social_perfiles where id=v_to and visible and estado='activo') then raise exception 'KOMBAX_RELATION_TARGET_NOT_AVAILABLE';end if;
    v_note:=left(nullif(btrim(v_payload->>'nota'),''),500);
    insert into public.kombax_relaciones(origen_social_id,destino_social_id,tipo,solicitado_por,nota) values(v_from,v_to,v_type,v_uid,v_note) returning * into v_rel;v_result:=to_jsonb(v_rel);
  elsif p_operation='kombax.relation.state' then
    begin v_id:=(v_payload->>'relacion_id')::uuid;exception when others then raise exception 'KOMBAX_RELATION_ID_INVALID';end;
    select * into v_rel from public.kombax_relaciones where id=v_id for update;if v_rel.id is null then raise exception 'KOMBAX_RELATION_NOT_FOUND';end if;
    v_state:=lower(coalesce(v_payload->>'estado',''));if v_state not in ('confirmed','rejected','ended','suspended') then raise exception 'KOMBAX_RELATION_STATE_INVALID';end if;
    if v_state in ('confirmed','rejected') and not public.app_kombax_social_puede_publicar_v041(v_rel.destino_social_id) and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_RELATION_CONFIRM_FORBIDDEN';end if;
    if v_state='ended' and not public.app_kombax_social_puede_publicar_v041(v_rel.origen_social_id) and not public.app_kombax_social_puede_publicar_v041(v_rel.destino_social_id) and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_RELATION_END_FORBIDDEN';end if;
    if v_state='suspended' and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;
    update public.kombax_relaciones set estado=v_state,confirmado_por=case when v_state='confirmed' then v_uid else confirmado_por end,confirmado_en=case when v_state='confirmed' then now() else confirmado_en end,finalizado_en=case when v_state in ('rejected','ended','suspended') then now() else finalizado_en end,moderado_por=case when v_state='suspended' then v_uid else moderado_por end where id=v_id returning * into v_rel;
    v_result:=jsonb_build_object('id',v_rel.id,'estado',v_rel.estado);
  else raise exception 'KOMBAX_RELATION_OPERATION_NOT_ALLOWED';end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_relacion_mutate_v045(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_relacion_mutate_v045(text,jsonb,uuid) to authenticated;

-- Showcase: un espacio puede pertenecer a una Marca verificada o a un Club.
alter table public.kombax_showcase_marcas add column if not exists sujeto_tipo text not null default 'marca';
alter table public.kombax_showcase_marcas add column if not exists club_id uuid references public.clubes(id) on delete cascade;
alter table public.kombax_showcase_marcas drop constraint if exists kombax_showcase_marcas_sujeto_tipo_check;
alter table public.kombax_showcase_marcas add constraint kombax_showcase_marcas_sujeto_tipo_check check(sujeto_tipo in ('marca','club'));
update public.kombax_showcase_marcas set sujeto_tipo=case when club_id is not null then 'club' else 'marca' end;
create unique index if not exists uq_showcase_club_v045 on public.kombax_showcase_marcas(club_id) where sujeto_tipo='club' and club_id is not null;

create or replace function public.app_kombax_showcase_provider_guard_v045()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.sujeto_tipo='club' then
    if new.club_id is null or new.perfil_directo_id is not null then raise exception 'SHOWCASE_CLUB_SUBJECT_INVALID';end if;
  else
    if new.perfil_directo_id is null or new.club_id is not null or not exists(select 1 from public.perfiles_kombax_directos d where d.id=new.perfil_directo_id and d.tipo='marca') then raise exception 'SHOWCASE_BRAND_SUBJECT_INVALID';end if;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_showcase_provider_guard_v045() from public,anon,authenticated;
drop trigger if exists showcase_provider_guard_v045 on public.kombax_showcase_marcas;
create trigger showcase_provider_guard_v045 before insert or update of sujeto_tipo,club_id,perfil_directo_id on public.kombax_showcase_marcas for each row execute function public.app_kombax_showcase_provider_guard_v045();

create or replace function public.app_kombax_showcase_puede_gestionar_v045(p_provider_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_es_moderador_v041()
    or exists(select 1 from public.kombax_showcase_gestores g where g.marca_id=p_provider_id and g.perfil_id=auth.uid() and g.activo)
    or exists(select 1 from public.kombax_showcase_marcas m join public.perfiles_kombax_directos d on d.id=m.perfil_directo_id join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='showcase.publish' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()) where m.id=p_provider_id and m.sujeto_tipo='marca' and d.perfil_id=auth.uid() and d.tipo='marca' and d.estado='activo' and d.verificacion_estado='verificado')
    or exists(select 1 from public.kombax_showcase_marcas m join public.miembros_club mc on mc.club_id=m.club_id where m.id=p_provider_id and m.sujeto_tipo='club' and mc.perfil_id=auth.uid() and mc.activo and (mc.rol in ('direccion','secretaria','comunicacion') or coalesce(mc.coordinacion,false)));
$$;
revoke all on function public.app_kombax_showcase_puede_gestionar_v045(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_puede_gestionar_v045(uuid) to authenticated;

create or replace function public.app_kombax_showcase_ensure_club_v045(p_club_id uuid)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid;v_club public.clubes;v_pc public.perfiles_club_publicos;
begin
  if auth.uid() is null or not exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))) then raise exception 'SHOWCASE_CLUB_MANAGEMENT_REQUIRED';end if;
  select id into v_id from public.kombax_showcase_marcas where sujeto_tipo='club' and club_id=p_club_id;if v_id is not null then return v_id;end if;
  select * into v_club from public.clubes where id=p_club_id and activo;if v_club.id is null then raise exception 'SHOWCASE_CLUB_NOT_FOUND';end if;
  select * into v_pc from public.perfiles_club_publicos where club_id=p_club_id;
  insert into public.kombax_showcase_marcas(sujeto_tipo,club_id,slug,nombre,descripcion,logo_url,banner_url,web_url,verificada,estado,creada_por)
  values('club',p_club_id,'club-'||v_club.slug,coalesce(nullif(v_pc.nombre_publico,''),v_club.nombre),coalesce(v_pc.descripcion,v_club.lema),coalesce(v_pc.logo_url,v_club.logo_url),coalesce(v_pc.portada_url,v_club.portada_url),v_pc.web_publica,true,'publicada',auth.uid()) returning id into v_id;
  insert into public.kombax_showcase_gestores(marca_id,perfil_id,rol,asignado_por) values(v_id,auth.uid(),'responsable',auth.uid()) on conflict do nothing;
  insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,asignada_por) values('club',p_club_id,'showcase.publish',true,'manual',auth.uid()) on conflict do nothing;
  return v_id;
end $$;
revoke all on function public.app_kombax_showcase_ensure_club_v045(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_ensure_club_v045(uuid) to authenticated;

create or replace function public.app_kombax_showcase_mis_espacios_v045(p_club_id uuid default null)
returns table(id uuid,sujeto_tipo text,slug text,nombre text,descripcion text,logo_url text,banner_url text,web_url text,contacto_url text,verificada boolean,estado text,limite_visible integer,publicados integer)
language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_club_id is not null and exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))) then v_id:=public.app_kombax_showcase_ensure_club_v045(p_club_id);end if;
  return query select m.id,m.sujeto_tipo,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado,case m.sujeto_tipo when 'club' then 15 else 30 end,
    (select count(*)::integer from public.kombax_showcase_elementos e where e.marca_id=m.id and e.estado='publicado')
  from public.kombax_showcase_marcas m where public.app_kombax_showcase_puede_gestionar_v045(m.id) order by case m.sujeto_tipo when 'club' then 0 else 1 end,m.nombre;
end $$;
revoke all on function public.app_kombax_showcase_mis_espacios_v045(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mis_espacios_v045(uuid) to authenticated;

create or replace function public.app_kombax_showcase_item_guard_v045()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_type text;v_limit integer;v_count integer;
begin
  if jsonb_typeof(new.galeria)<>'array' or jsonb_array_length(new.galeria)>3 then raise exception 'SHOWCASE_GALLERY_MAX_3_ADDITIONAL';end if;
  if new.estado='publicado' and (tg_op='INSERT' or old.estado is distinct from new.estado) then
    select sujeto_tipo into v_type from public.kombax_showcase_marcas where id=new.marca_id;v_limit:=case v_type when 'club' then 15 else 30 end;
    select count(*) into v_count from public.kombax_showcase_elementos where marca_id=new.marca_id and estado='publicado' and id<>new.id;
    if v_count>=v_limit then raise exception 'SHOWCASE_VISIBLE_LIMIT_%',v_limit;end if;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_showcase_item_guard_v045() from public,anon,authenticated;
drop trigger if exists showcase_item_guard_v045 on public.kombax_showcase_elementos;
create trigger showcase_item_guard_v045 before insert or update of estado,galeria,marca_id on public.kombax_showcase_elementos for each row execute function public.app_kombax_showcase_item_guard_v045();

-- Sustituye internamente la autorización 042 para que su mutador existente también respete Club.
create or replace function public.app_kombax_showcase_puede_gestionar_v042(p_marca_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$ select public.app_kombax_showcase_puede_gestionar_v045(p_marca_id); $$;
revoke all on function public.app_kombax_showcase_puede_gestionar_v042(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_puede_gestionar_v042(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
