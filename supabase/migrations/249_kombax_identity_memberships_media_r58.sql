-- KOMBAX 20.108 R58 · IDENTITY / MEMBERSHIPS / SPECTATOR / MEDIA
-- Derivada de R57. Mantiene Auth global separado de las membresías administrativas de cada club.
-- Un usuario sin membresía/perfil autorizado opera como Espectador; cada club activa su ficha por separado.

begin;

-- -----------------------------------------------------------------------------
-- 1) Ficha administrativa de alumno independiente de Auth
-- -----------------------------------------------------------------------------
alter table public.socios
  add column if not exists kombax_acceso_estado text not null default 'sin_activar',
  add column if not exists kombax_acceso_email text,
  add column if not exists kombax_acceso_modo text,
  add column if not exists kombax_acceso_actualizado_en timestamptz not null default now(),
  add column if not exists kombax_vinculado_en timestamptz;

alter table public.socios drop constraint if exists socios_kombax_acceso_estado_check;
alter table public.socios add constraint socios_kombax_acceso_estado_check
  check(kombax_acceso_estado in ('sin_activar','invitacion_pendiente','vinculacion_pendiente','activo'));
alter table public.socios drop constraint if exists socios_kombax_acceso_modo_check;
alter table public.socios add constraint socios_kombax_acceso_modo_check
  check(kombax_acceso_modo is null or kombax_acceso_modo in ('alumno','tutor'));

update public.socios
set kombax_acceso_estado='activo',kombax_acceso_modo='alumno',kombax_vinculado_en=coalesce(kombax_vinculado_en,actualizado_en,now())
where perfil_id is not null and kombax_acceso_estado<>'activo';

create index if not exists idx_socios_kombax_access_r58
  on public.socios(club_id,kombax_acceso_estado,estado);
create index if not exists idx_socios_kombax_email_r58
  on public.socios(club_id,lower(email)) where email is not null and btrim(email)<>'';

-- La invitación personal puede quedar ligada a UNA ficha ya existente.
alter table public.invitaciones_club add column if not exists socio_id uuid;
do $$ begin
  if not exists(select 1 from pg_constraint where conname='invitaciones_club_socio_r58_fk') then
    alter table public.invitaciones_club add constraint invitaciones_club_socio_r58_fk
      foreign key(club_id,socio_id) references public.socios(club_id,id) on delete cascade;
  end if;
end $$;
create index if not exists idx_invitaciones_club_socio_r58 on public.invitaciones_club(club_id,socio_id,estado) where socio_id is not null;

-- Bloquea nuevos duplicados de la misma cuenta como dos alumnos del mismo club,
-- pero permite esa misma cuenta en clubes distintos.
create or replace function public.app_kombax_guard_socio_account_r58()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.perfil_id is not null and exists(
    select 1 from public.socios s
    where s.club_id=new.club_id and s.perfil_id=new.perfil_id and s.id<>new.id
  ) then raise exception 'KOMBAX_DUPLICATE_STUDENT_ACCOUNT_IN_CLUB'; end if;
  return new;
end $$;
revoke all on function public.app_kombax_guard_socio_account_r58() from public,anon,authenticated;
drop trigger if exists socios_kombax_account_guard_r58 on public.socios;
create trigger socios_kombax_account_guard_r58 before insert or update of club_id,perfil_id on public.socios
for each row execute function public.app_kombax_guard_socio_account_r58();

-- Invitación ligada a una ficha administrativa concreta. Reutiliza el generador v059.
create or replace function public.app_kombax_alumno_invitar_r58(p_club_id uuid,p_socio_id uuid,p_email text default null)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_socio public.socios;v_email text;v_inv jsonb;v_inv_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then raise exception 'KOMBAX_MEMBER_INVITE_FORBIDDEN';end if;
  select * into v_socio from public.socios where club_id=p_club_id and id=p_socio_id for update;
  if v_socio.id is null then raise exception 'KOMBAX_STUDENT_NOT_FOUND';end if;
  if v_socio.estado in ('baja','suspendido') then raise exception 'KOMBAX_STUDENT_NOT_ACTIVE';end if;
  if v_socio.perfil_id is not null then raise exception 'KOMBAX_STUDENT_ALREADY_LINKED';end if;
  v_email:=lower(btrim(coalesce(nullif(p_email,''),v_socio.email,'')));
  if v_email='' or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'KOMBAX_STUDENT_EMAIL_REQUIRED';end if;

  update public.invitaciones_club set estado='revocada'
  where club_id=p_club_id and socio_id=p_socio_id and tipo_invitacion='alumno' and estado='pendiente';

  v_inv:=public.app_kombax_invitacion_crear_v059(p_club_id,'alumno',v_email,null,concat_ws(' ',v_socio.nombre,v_socio.apellidos),168);
  v_inv_id:=(v_inv->>'id')::uuid;
  update public.invitaciones_club set socio_id=p_socio_id where id=v_inv_id;
  update public.socios set email=coalesce(nullif(email,''),v_email),kombax_acceso_email=v_email,
    kombax_acceso_estado='invitacion_pendiente',kombax_acceso_actualizado_en=now()
  where id=p_socio_id and club_id=p_club_id;
  return v_inv||jsonb_build_object('socio_id',p_socio_id,'vincula_ficha',true,'acceso_estado','invitacion_pendiente');
end $$;
revoke all on function public.app_kombax_alumno_invitar_r58(uuid,uuid,text) from public,anon;
grant execute on function public.app_kombax_alumno_invitar_r58(uuid,uuid,text) to authenticated;

-- Extiende la validación pública de códigos sin cambiar su firma histórica.
create or replace function public.app_kombax_invitacion_validar_v059(p_codigo text,p_email text)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v public.invitaciones_club;v_club public.clubes;
begin
  select * into v from public.invitaciones_club i
   where upper(i.codigo)=upper(trim(coalesce(p_codigo,''))) and lower(i.email)=lower(trim(coalesce(p_email,'')))
     and i.estado='pendiente' and i.expira_en>now() limit 1;
  if v.id is null then return jsonb_build_object('valid',false);end if;
  select * into v_club from public.clubes where id=v.club_id and activo;
  if v_club.id is null then return jsonb_build_object('valid',false);end if;
  return jsonb_build_object('valid',true,'tipo',v.tipo_invitacion,'club_id',v.club_id,'club_slug',v_club.slug,'club_nombre',v_club.nombre,
    'email',v.email,'nombre',v.nombre_destinatario,'rol',case when v.coordinacion then 'coordinacion' else v.rol::text end,'expira_en',v.expira_en,
    'socio_id',v.socio_id,'vincula_ficha',(v.tipo_invitacion='alumno' and v.socio_id is not null));
end $$;
revoke all on function public.app_kombax_invitacion_validar_v059(text,text) from public;
grant execute on function public.app_kombax_invitacion_validar_v059(text,text) to anon,authenticated;

-- Acepta una invitación personal y vincula la cuenta a ESA membresía, no crea otra preinscripción.
create or replace function public.app_kombax_alumno_aceptar_r58(p_codigo text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_email text;v_confirmed timestamptz;v_inv public.invitaciones_club;v_socio public.socios;
  v_age integer;v_mode text;v_other uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  select lower(coalesce(email,'')),email_confirmed_at into v_email,v_confirmed from auth.users where id=v_uid;
  if v_confirmed is null then raise exception 'KOMBAX_EMAIL_VERIFICATION_REQUIRED';end if;
  select * into v_inv from public.invitaciones_club i
  where upper(i.codigo)=upper(btrim(coalesce(p_codigo,''))) and i.tipo_invitacion='alumno' and i.estado='pendiente' for update;
  if v_inv.id is null or v_inv.socio_id is null then raise exception 'KOMBAX_BOUND_STUDENT_INVITATION_REQUIRED';end if;
  if v_inv.expira_en<=now() then update public.invitaciones_club set estado='caducada' where id=v_inv.id;raise exception 'La invitación ha caducado';end if;
  if lower(v_inv.email)<>v_email then raise exception 'La invitación pertenece a otro correo';end if;
  perform pg_advisory_xact_lock(hashtext(v_inv.club_id::text||':'||v_uid::text));
  select * into v_socio from public.socios where id=v_inv.socio_id and club_id=v_inv.club_id for update;
  if v_socio.id is null then raise exception 'KOMBAX_STUDENT_NOT_FOUND';end if;
  if v_socio.estado in ('baja','suspendido') then raise exception 'KOMBAX_STUDENT_NOT_ACTIVE';end if;
  if v_socio.fecha_nacimiento is not null then v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento));end if;

  insert into public.perfiles(id,nombre,apellidos)
  values(v_uid,coalesce(nullif(auth.jwt()->'user_metadata'->>'nombre',''),split_part(v_email,'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos',''))
  on conflict(id) do nothing;

  if coalesce(v_age,16)<16 then
    -- El menor conserva su propia ficha; la cuenta activa es la del tutor.
    insert into public.tutores_socios(club_id,tutor_perfil_id,socio_id,parentesco,contacto_principal)
    values(v_inv.club_id,v_uid,v_socio.id,'tutor',true)
    on conflict(club_id,tutor_perfil_id,socio_id) do update set contacto_principal=true;
    insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
    values(v_inv.club_id,v_uid,'familia',true,false)
    on conflict(club_id,perfil_id,rol) do update set activo=true;
    v_mode:='tutor';
  else
    if v_socio.perfil_id is not null and v_socio.perfil_id<>v_uid then raise exception 'KOMBAX_STUDENT_ALREADY_LINKED_TO_OTHER_ACCOUNT';end if;
    select id into v_other from public.socios where club_id=v_inv.club_id and perfil_id=v_uid and id<>v_socio.id limit 1;
    if v_other is not null then raise exception 'KOMBAX_ACCOUNT_ALREADY_HAS_STUDENT_MEMBERSHIP_IN_CLUB';end if;
    update public.socios set perfil_id=v_uid where id=v_socio.id and club_id=v_inv.club_id;
    insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
    values(v_inv.club_id,v_uid,'alumno',true,false)
    on conflict(club_id,perfil_id,rol) do update set activo=true;
    v_mode:='alumno';
  end if;

  update public.socios set kombax_acceso_estado='activo',kombax_acceso_email=v_email,kombax_acceso_modo=v_mode,
    kombax_acceso_actualizado_en=now(),kombax_vinculado_en=coalesce(kombax_vinculado_en,now())
  where id=v_socio.id and club_id=v_inv.club_id;
  update public.invitaciones_club set estado='aceptada',aceptado_por=v_uid,aceptado_en=now() where id=v_inv.id;
  return jsonb_build_object('ok',true,'club_id',v_inv.club_id,'socio_id',v_socio.id,'modo',v_mode,'estado','activo');
end $$;
revoke all on function public.app_kombax_alumno_aceptar_r58(text) from public,anon;
grant execute on function public.app_kombax_alumno_aceptar_r58(text) to authenticated;

-- Descubrimiento seguro por email verificado: solo propone fichas, nunca las fusiona automáticamente.
create or replace function public.app_kombax_membresias_pendientes_r58()
returns table(socio_id uuid,club_id uuid,club_nombre text,nombre text,apellidos text,estado text,acceso_estado text)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_email text;v_confirmed timestamptz;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  select lower(coalesce(email,'')),email_confirmed_at into v_email,v_confirmed from auth.users where id=v_uid;
  if v_confirmed is null then raise exception 'KOMBAX_EMAIL_VERIFICATION_REQUIRED';end if;
  return query select s.id,s.club_id,c.nombre,s.nombre,s.apellidos,s.estado,s.kombax_acceso_estado
  from public.socios s join public.clubes c on c.id=s.club_id and c.activo
  where lower(coalesce(s.email,''))=v_email and s.perfil_id is null and s.estado in ('activo','prealta')
  order by c.nombre,s.apellidos,s.nombre;
end $$;
revoke all on function public.app_kombax_membresias_pendientes_r58() from public,anon;
grant execute on function public.app_kombax_membresias_pendientes_r58() to authenticated;

create table if not exists public.kombax_membership_claims_r58(
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null,
  account_id uuid not null references public.perfiles(id) on delete cascade,
  estado text not null default 'pendiente' check(estado in ('pendiente','aprobada','rechazada','cancelada')),
  solicitado_en timestamptz not null default now(),
  resuelto_en timestamptz,
  resuelto_por uuid references public.perfiles(id) on delete set null,
  foreign key(club_id,socio_id) references public.socios(club_id,id) on delete cascade
);
create unique index if not exists uq_membership_claim_pending_r58 on public.kombax_membership_claims_r58(club_id,socio_id,account_id) where estado='pendiente';
alter table public.kombax_membership_claims_r58 enable row level security;
revoke all on public.kombax_membership_claims_r58 from public,anon,authenticated;

create or replace function public.app_kombax_membresia_solicitar_r58(p_socio_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_email text;v_confirmed timestamptz;v_socio public.socios;v_id uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  select lower(coalesce(email,'')),email_confirmed_at into v_email,v_confirmed from auth.users where id=v_uid;
  if v_confirmed is null then raise exception 'KOMBAX_EMAIL_VERIFICATION_REQUIRED';end if;
  select * into v_socio from public.socios where id=p_socio_id for update;
  if v_socio.id is null or v_socio.perfil_id is not null or lower(coalesce(v_socio.email,''))<>v_email then raise exception 'KOMBAX_MEMBERSHIP_CLAIM_NOT_ELIGIBLE';end if;
  insert into public.perfiles(id,nombre,apellidos) values(v_uid,coalesce(auth.jwt()->'user_metadata'->>'nombre',split_part(v_email,'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos','')) on conflict(id) do nothing;
  insert into public.kombax_membership_claims_r58(club_id,socio_id,account_id) values(v_socio.club_id,v_socio.id,v_uid)
  on conflict(club_id,socio_id,account_id) where estado='pendiente' do update set solicitado_en=excluded.solicitado_en returning id into v_id;
  update public.socios set kombax_acceso_estado='vinculacion_pendiente',kombax_acceso_email=v_email,kombax_acceso_actualizado_en=now() where id=v_socio.id;
  return jsonb_build_object('ok',true,'claim_id',v_id,'club_id',v_socio.club_id,'socio_id',v_socio.id,'estado','vinculacion_pendiente');
end $$;
revoke all on function public.app_kombax_membresia_solicitar_r58(uuid) from public,anon;
grant execute on function public.app_kombax_membresia_solicitar_r58(uuid) to authenticated;

-- Membresías activas de la cuenta, separadas por club. Incluye alumno directo y tutor/familia.
create or replace function public.app_kombax_mis_membresias_r58()
returns table(club_id uuid,club_nombre text,club_slug text,socio_id uuid,alumno_nombre text,alumno_apellidos text,modo text,estado text)
language sql stable security definer set search_path=public,auth as $$
  select s.club_id,c.nombre,c.slug,s.id,s.nombre,s.apellidos,'alumno'::text,s.estado
  from public.socios s join public.clubes c on c.id=s.club_id
  where s.perfil_id=auth.uid() and s.kombax_acceso_estado='activo' and s.estado='activo'
  union all
  select s.club_id,c.nombre,c.slug,s.id,s.nombre,s.apellidos,'tutor'::text,s.estado
  from public.tutores_socios t join public.socios s on s.id=t.socio_id and s.club_id=t.club_id join public.clubes c on c.id=s.club_id
  where t.tutor_perfil_id=auth.uid() and s.kombax_acceso_estado='activo' and s.estado='activo'
  order by 2,5,6;
$$;
revoke all on function public.app_kombax_mis_membresias_r58() from public,anon;
grant execute on function public.app_kombax_mis_membresias_r58() to authenticated;

-- La baja/suspensión solo revoca el acceso de ESA membresía/club.
create or replace function public.app_kombax_sync_member_access_r58()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_tutor uuid;
begin
  if new.estado in ('baja','suspendido') then
    if new.perfil_id is not null then update public.miembros_club set activo=false where club_id=new.club_id and perfil_id=new.perfil_id and rol='alumno';end if;
    for v_tutor in select t.tutor_perfil_id from public.tutores_socios t where t.club_id=new.club_id and t.socio_id=new.id loop
      if not exists(select 1 from public.tutores_socios t2 join public.socios s2 on s2.id=t2.socio_id and s2.club_id=t2.club_id where t2.club_id=new.club_id and t2.tutor_perfil_id=v_tutor and s2.id<>new.id and s2.estado='activo' and s2.kombax_acceso_estado='activo') then
        update public.miembros_club set activo=false where club_id=new.club_id and perfil_id=v_tutor and rol='familia';
      end if;
    end loop;
  elsif new.estado='activo' and new.kombax_acceso_estado='activo' then
    if new.perfil_id is not null then update public.miembros_club set activo=true where club_id=new.club_id and perfil_id=new.perfil_id and rol='alumno';end if;
    update public.miembros_club mc set activo=true where mc.club_id=new.club_id and mc.rol='familia' and exists(select 1 from public.tutores_socios t where t.club_id=new.club_id and t.socio_id=new.id and t.tutor_perfil_id=mc.perfil_id);
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_sync_member_access_r58() from public,anon,authenticated;
drop trigger if exists socios_member_access_sync_r58 on public.socios;
create trigger socios_member_access_sync_r58 after update of estado,kombax_acceso_estado on public.socios for each row execute function public.app_kombax_sync_member_access_r58();

-- -----------------------------------------------------------------------------
-- 2) Cuenta Espectador: canal específico para futura alta en Club
--    (NO crea membresía, Mi Red ni permiso de publicación)
-- -----------------------------------------------------------------------------
create table if not exists public.kombax_club_interest_threads_r58(
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  account_id uuid not null references public.perfiles(id) on delete cascade,
  estado text not null default 'abierta' check(estado in ('abierta','respondida','cerrada')),
  creada_en timestamptz not null default now(),
  actualizada_en timestamptz not null default now(),
  unique(club_id,account_id)
);
create table if not exists public.kombax_club_interest_messages_r58(
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.kombax_club_interest_threads_r58(id) on delete cascade,
  autor_perfil_id uuid not null references public.perfiles(id) on delete cascade,
  texto text not null check(char_length(btrim(texto)) between 2 and 1000),
  creado_en timestamptz not null default now()
);
alter table public.kombax_club_interest_threads_r58 enable row level security;
alter table public.kombax_club_interest_messages_r58 enable row level security;
revoke all on public.kombax_club_interest_threads_r58,public.kombax_club_interest_messages_r58 from public,anon,authenticated;

create or replace function public.app_kombax_club_interest_send_r58(p_club_id uuid,p_mensaje text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_text text:=btrim(coalesce(p_mensaje,''));v_thread uuid;v_msg uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if char_length(v_text)<2 or char_length(v_text)>1000 then raise exception 'KOMBAX_CLUB_INTEREST_TEXT_INVALID';end if;
  if not exists(select 1 from public.clubes where id=p_club_id and activo) then raise exception 'KOMBAX_CLUB_NOT_AVAILABLE';end if;
  insert into public.perfiles(id,nombre,apellidos) values(v_uid,coalesce(auth.jwt()->'user_metadata'->>'nombre',split_part(coalesce(auth.jwt()->>'email','usuario'),'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos','')) on conflict(id) do nothing;
  insert into public.kombax_club_interest_threads_r58(club_id,account_id) values(p_club_id,v_uid)
  on conflict(club_id,account_id) do update set estado='abierta',actualizada_en=now() returning id into v_thread;
  insert into public.kombax_club_interest_messages_r58(thread_id,autor_perfil_id,texto) values(v_thread,v_uid,v_text) returning id into v_msg;
  return jsonb_build_object('ok',true,'thread_id',v_thread,'message_id',v_msg,'membership_created',false);
end $$;
revoke all on function public.app_kombax_club_interest_send_r58(uuid,text) from public,anon;
grant execute on function public.app_kombax_club_interest_send_r58(uuid,text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) Perfil adicional MEDIA / CREADOR DE CONTENIDO
--    Perfil independiente de Promotora: Social + Showcase, sin gestión de Club.
-- -----------------------------------------------------------------------------
alter table public.perfiles_kombax_directos drop constraint if exists perfiles_kombax_directos_tipo_check;
alter table public.perfiles_kombax_directos add constraint perfiles_kombax_directos_tipo_check
  check(tipo in ('competidor','marca','federacion','espectador','profesional','media'));
alter table public.kombax_solicitudes_alta drop constraint if exists kombax_solicitudes_alta_tipo_check;
alter table public.kombax_solicitudes_alta add constraint kombax_solicitudes_alta_tipo_check
  check(tipo in ('club','competidor','marca','federacion','profesional','media'));

alter table public.kombax_showcase_marcas drop constraint if exists kombax_showcase_marcas_sujeto_tipo_check;
alter table public.kombax_showcase_marcas add constraint kombax_showcase_marcas_sujeto_tipo_check check(sujeto_tipo in ('marca','club','media'));

create or replace function public.app_kombax_showcase_provider_guard_v045()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.sujeto_tipo='club' then
    if new.club_id is null or new.perfil_directo_id is not null then raise exception 'SHOWCASE_CLUB_SUBJECT_INVALID';end if;
  else
    if new.perfil_directo_id is null or new.club_id is not null or not exists(select 1 from public.perfiles_kombax_directos d where d.id=new.perfil_directo_id and d.tipo=new.sujeto_tipo and d.tipo in ('marca','media')) then raise exception 'SHOWCASE_DIRECT_SUBJECT_INVALID';end if;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_showcase_provider_guard_v045() from public,anon,authenticated;

create or replace function public.app_kombax_showcase_puede_gestionar_v045(p_provider_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_es_moderador_v041()
    or exists(select 1 from public.kombax_showcase_gestores g where g.marca_id=p_provider_id and g.perfil_id=auth.uid() and g.activo)
    or exists(select 1 from public.kombax_showcase_marcas m join public.perfiles_kombax_directos d on d.id=m.perfil_directo_id join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='showcase.publish' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()) where m.id=p_provider_id and m.sujeto_tipo in ('marca','media') and d.perfil_id=auth.uid() and d.tipo=m.sujeto_tipo and d.estado='activo' and d.verificacion_estado='verificado')
    or exists(select 1 from public.kombax_showcase_marcas m join public.miembros_club mc on mc.club_id=m.club_id where m.id=p_provider_id and m.sujeto_tipo='club' and mc.perfil_id=auth.uid() and mc.activo and (mc.rol in ('direccion','secretaria','comunicacion') or coalesce(mc.coordinacion,false)));
$$;
revoke all on function public.app_kombax_showcase_puede_gestionar_v045(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_puede_gestionar_v045(uuid) to authenticated;

-- Media pasa por revisión y al verificarse obtiene SOLO capacidades globales Social/Showcase/álbum.
create or replace function public.app_kombax_media_entitlements_r58()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.tipo='media' and new.estado='activo' and new.verificacion_estado='verificado' then
    insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen) values
      ('perfil_directo',new.id,'social.read',true,'manual'),('perfil_directo',new.id,'social.publish',true,'manual'),
      ('perfil_directo',new.id,'contact.request',true,'manual'),('perfil_directo',new.id,'profile.album.publish',true,'manual'),
      ('perfil_directo',new.id,'showcase.publish',true,'manual')
    on conflict do nothing;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_media_entitlements_r58() from public,anon,authenticated;
drop trigger if exists direct_profile_media_entitlements_r58 on public.perfiles_kombax_directos;
create trigger direct_profile_media_entitlements_r58 after insert or update of estado,verificacion_estado on public.perfiles_kombax_directos
for each row execute function public.app_kombax_media_entitlements_r58();

-- Autoriza Media en Social; Espectador sigue deliberadamente fuera.
create or replace function public.app_kombax_social_puede_actuar_v051(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.publicar_habilitado and (
      (sp.sujeto_tipo='miembro' and exists(
        select 1 from public.identidades_sociales i join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
        where i.id=sp.identidad_social_id and i.perfil_id=auth.uid() and i.estado='activa' and s.estado='activo' and s.fecha_nacimiento is not null
          and extract(year from age(current_date,s.fecha_nacimiento))>=14 and public.app_kombax_club_permiso_v051(i.club_origen_id,'social.publish')
      ))
      or (sp.sujeto_tipo='club' and public.app_kombax_club_permiso_v051(sp.club_id,'social.publish') and public.app_kombax_club_permiso_v051(sp.club_id,'social.act_as_club'))
      or (sp.sujeto_tipo='perfil_directo' and exists(
        select 1 from public.perfiles_kombax_directos d
        where d.id=sp.perfil_directo_id and d.perfil_id=auth.uid() and d.estado='activo' and d.verificacion_estado='verificado' and d.social_activo
          and (
            d.tipo in ('marca','federacion','media')
            or (d.tipo in ('competidor','profesional') and exists(
              select 1 from public.identidades_sociales i join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
              where i.perfil_id=d.perfil_id and i.estado='activa' and s.estado='activo' and s.fecha_nacimiento is not null and extract(year from age(current_date,s.fecha_nacimiento))>=14
            ))
          )
      ))
    )
  );
$$;
revoke all on function public.app_kombax_social_puede_actuar_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_actuar_v051(uuid) to authenticated;

create or replace function public.app_kombax_social_puede_publicar_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$ select public.app_kombax_social_puede_actuar_v051(p_social_id); $$;
revoke all on function public.app_kombax_social_puede_publicar_v041(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_publicar_v041(uuid) to authenticated;

create or replace function public.app_kombax_social_contactable_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.contacto_habilitado and (
      sp.sujeto_tipo='club'
      or (sp.sujeto_tipo='miembro' and exists(select 1 from public.identidades_sociales i join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id where i.id=sp.identidad_social_id and i.estado='activa' and s.estado='activo' and s.fecha_nacimiento is not null and extract(year from age(current_date,s.fecha_nacimiento))>=18))
      or (sp.sujeto_tipo='perfil_directo' and exists(select 1 from public.perfiles_kombax_directos d where d.id=sp.perfil_directo_id and d.estado='activo' and d.verificacion_estado='verificado' and d.social_activo and (
        d.tipo in ('marca','federacion','media') or (d.tipo in ('competidor','profesional') and exists(select 1 from public.identidades_sociales i join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id where i.perfil_id=d.perfil_id and i.estado='activa' and s.estado='activo' and s.fecha_nacimiento is not null and extract(year from age(current_date,s.fecha_nacimiento))>=18))
      )))
    )
  );
$$;
revoke all on function public.app_kombax_social_contactable_v041(uuid) from public,anon;
grant execute on function public.app_kombax_social_contactable_v041(uuid) to authenticated;

-- Wrapper R58: abre Media sin reescribir el motor de perfiles vigente. El resto delega a v196.
create or replace function public.app_kombax_perfil_mutate_r58(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_type text:=lower(btrim(coalesce(p_payload->>'tipo','')));v_name text;v_slug text;v_id uuid;v_profile public.perfiles_kombax_directos;v_request public.kombax_solicitudes_alta;v_result jsonb;
begin
  if v_type<>'media' or p_operation not in ('kombax.profile.save','kombax.application.save') then
    return public.app_kombax_perfil_mutate_v196(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  v_name:=btrim(coalesce(p_payload->>'nombre_publico',''));if char_length(v_name)<2 or char_length(v_name)>160 then raise exception 'KOMBAX_PROFILE_NAME_INVALID';end if;
  if p_operation='kombax.profile.save' then
    begin v_id:=nullif(coalesce(p_payload->>'id',p_payload->>'perfil_directo_id'),'')::uuid;exception when others then raise exception 'KOMBAX_PROFILE_ID_INVALID';end;
    if v_id is null then
      v_slug:=public.app_kombax_slug_v043(coalesce(nullif(p_payload->>'slug',''),v_name));if exists(select 1 from public.perfiles_kombax_directos where slug=v_slug) then v_slug:=left(v_slug,50)||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,8);end if;
      insert into public.perfiles_kombax_directos(perfil_id,tipo,slug,nombre_publico,descripcion,workflow_estado,ubicacion,disciplinas,categoria,club_declarado,web_publica,publico)
      values(v_uid,'media',v_slug,v_name,left(nullif(btrim(p_payload->>'descripcion'),''),1600),'draft',left(nullif(btrim(p_payload->>'ubicacion'),''),160),
        coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'disciplinas','[]'::jsonb)) limit 12),'{}'::text[]),left(nullif(btrim(p_payload->>'categoria'),''),120),null,nullif(btrim(p_payload->>'web_publica'),''),false) returning * into v_profile;
      insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen) values('perfil_directo',v_profile.id,'profile.direct.manage',true,'manual') on conflict do nothing;
    else
      update public.perfiles_kombax_directos set nombre_publico=v_name,descripcion=left(nullif(btrim(p_payload->>'descripcion'),''),1600),ubicacion=left(nullif(btrim(p_payload->>'ubicacion'),''),160),
        disciplinas=coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'disciplinas','[]'::jsonb)) limit 12),'{}'::text[]),categoria=left(nullif(btrim(p_payload->>'categoria'),''),120),web_publica=nullif(btrim(p_payload->>'web_publica'),''),actualizado_en=now()
      where id=v_id and perfil_id=v_uid and tipo='media' and workflow_estado not in ('under_review','verified','suspended') returning * into v_profile;
      if v_profile.id is null then raise exception 'KOMBAX_PROFILE_NOT_EDITABLE';end if;
    end if;
    v_result:=to_jsonb(v_profile);
  else
    begin v_id:=nullif(p_payload->>'perfil_directo_id','')::uuid;exception when others then raise exception 'KOMBAX_PROFILE_ID_INVALID';end;
    if v_id is null or not exists(select 1 from public.perfiles_kombax_directos where id=v_id and perfil_id=v_uid and tipo='media') then raise exception 'KOMBAX_DIRECT_PROFILE_REQUIRED';end if;
    insert into public.kombax_solicitudes_alta(perfil_id,tipo,perfil_directo_id,nombre_publico,datos_publicos,datos_verificacion,estado)
    values(v_uid,'media',v_id,v_name,coalesce(p_payload->'datos_publicos','{}'::jsonb),coalesce(p_payload->'datos_verificacion','{}'::jsonb),'draft')
    on conflict(perfil_id,tipo) where estado in ('draft','submitted','under_review','needs_information') do update set nombre_publico=excluded.nombre_publico,perfil_directo_id=excluded.perfil_directo_id,datos_publicos=excluded.datos_publicos,datos_verificacion=excluded.datos_verificacion,actualizado_en=now()
    returning * into v_request;v_result:=to_jsonb(v_request)-'datos_verificacion';
  end if;
  return jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',v_result);
end $$;
revoke all on function public.app_kombax_perfil_mutate_r58(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_perfil_mutate_r58(text,jsonb,uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) Consulta/chat Showcase para Espectador SIN abrir chat Social ni Mi Red
-- -----------------------------------------------------------------------------
create table if not exists public.kombax_showcase_inquiries_r58(
  id uuid primary key default gen_random_uuid(),
  elemento_id uuid not null references public.kombax_showcase_elementos(id) on delete cascade,
  marca_id uuid not null references public.kombax_showcase_marcas(id) on delete cascade,
  account_id uuid not null references public.perfiles(id) on delete cascade,
  estado text not null default 'abierta' check(estado in ('abierta','respondida','cerrada')),
  creada_en timestamptz not null default now(),
  actualizada_en timestamptz not null default now(),
  unique(elemento_id,account_id)
);
create table if not exists public.kombax_showcase_inquiry_messages_r58(
  id uuid primary key default gen_random_uuid(),
  inquiry_id uuid not null references public.kombax_showcase_inquiries_r58(id) on delete cascade,
  autor_perfil_id uuid not null references public.perfiles(id) on delete cascade,
  texto text not null check(char_length(btrim(texto)) between 2 and 1000),
  creado_en timestamptz not null default now()
);
create index if not exists idx_showcase_inquiries_account_r58 on public.kombax_showcase_inquiries_r58(account_id,actualizada_en desc);
create index if not exists idx_showcase_inquiries_provider_r58 on public.kombax_showcase_inquiries_r58(marca_id,actualizada_en desc);
create index if not exists idx_showcase_inquiry_messages_r58 on public.kombax_showcase_inquiry_messages_r58(inquiry_id,creado_en,id);
alter table public.kombax_showcase_inquiries_r58 enable row level security;
alter table public.kombax_showcase_inquiry_messages_r58 enable row level security;
revoke all on public.kombax_showcase_inquiries_r58,public.kombax_showcase_inquiry_messages_r58 from public,anon,authenticated;

create or replace function public.app_kombax_showcase_inquiry_request_r58(p_elemento_id uuid,p_mensaje text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_text text:=btrim(coalesce(p_mensaje,''));v_item public.kombax_showcase_elementos;v_id uuid;v_msg uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if char_length(v_text)<10 or char_length(v_text)>1000 then raise exception 'KOMBAX_SHOWCASE_INQUIRY_TEXT_INVALID';end if;
  select * into v_item from public.kombax_showcase_elementos where id=p_elemento_id and estado='publicado';
  if v_item.id is null then raise exception 'SHOWCASE_ITEM_NOT_PUBLIC';end if;
  if not exists(select 1 from public.kombax_showcase_marcas m where m.id=v_item.marca_id and m.estado='publicada') then raise exception 'SHOWCASE_PROVIDER_NOT_PUBLIC';end if;
  insert into public.perfiles(id,nombre,apellidos) values(v_uid,coalesce(auth.jwt()->'user_metadata'->>'nombre',split_part(coalesce(auth.jwt()->>'email','usuario'),'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos','')) on conflict(id) do nothing;
  insert into public.kombax_showcase_inquiries_r58(elemento_id,marca_id,account_id)
  values(v_item.id,v_item.marca_id,v_uid)
  on conflict(elemento_id,account_id) do update set estado=case when kombax_showcase_inquiries_r58.estado='cerrada' then 'abierta' else kombax_showcase_inquiries_r58.estado end,actualizada_en=now()
  returning id into v_id;
  insert into public.kombax_showcase_inquiry_messages_r58(inquiry_id,autor_perfil_id,texto) values(v_id,v_uid,v_text) returning id into v_msg;
  update public.kombax_showcase_inquiries_r58 set actualizada_en=now() where id=v_id;
  return jsonb_build_object('ok',true,'id',v_id,'message_id',v_msg,'channel','showcase','social_network_created',false);
end $$;
revoke all on function public.app_kombax_showcase_inquiry_request_r58(uuid,text) from public,anon;
grant execute on function public.app_kombax_showcase_inquiry_request_r58(uuid,text) to authenticated;

create or replace function public.app_kombax_showcase_my_inquiries_r58(p_limit integer default 50)
returns table(id uuid,elemento_id uuid,marca_id uuid,producto_nombre text,marca_nombre text,imagen_url text,estado text,actualizada_en timestamptz,mensajes bigint)
language sql stable security definer set search_path=public,auth as $$
  select i.id,i.elemento_id,i.marca_id,e.nombre,m.nombre,e.imagen_url,i.estado,i.actualizada_en,
    (select count(*) from public.kombax_showcase_inquiry_messages_r58 x where x.inquiry_id=i.id)
  from public.kombax_showcase_inquiries_r58 i
  join public.kombax_showcase_elementos e on e.id=i.elemento_id
  join public.kombax_showcase_marcas m on m.id=i.marca_id
  where i.account_id=auth.uid()
  order by i.actualizada_en desc limit least(greatest(coalesce(p_limit,50),1),100);
$$;
revoke all on function public.app_kombax_showcase_my_inquiries_r58(integer) from public,anon;
grant execute on function public.app_kombax_showcase_my_inquiries_r58(integer) to authenticated;

create or replace function public.app_kombax_showcase_provider_inquiries_r58(p_marca_id uuid,p_limit integer default 80)
returns table(id uuid,elemento_id uuid,producto_nombre text,account_id uuid,account_nombre text,estado text,actualizada_en timestamptz,mensajes bigint)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_showcase_puede_gestionar_v045(p_marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
  return query select i.id,i.elemento_id,e.nombre,i.account_id,concat_ws(' ',p.nombre,p.apellidos),i.estado,i.actualizada_en,
    (select count(*) from public.kombax_showcase_inquiry_messages_r58 x where x.inquiry_id=i.id)
  from public.kombax_showcase_inquiries_r58 i join public.kombax_showcase_elementos e on e.id=i.elemento_id join public.perfiles p on p.id=i.account_id
  where i.marca_id=p_marca_id order by i.actualizada_en desc limit least(greatest(coalesce(p_limit,80),1),150);
end $$;
revoke all on function public.app_kombax_showcase_provider_inquiries_r58(uuid,integer) from public,anon;
grant execute on function public.app_kombax_showcase_provider_inquiries_r58(uuid,integer) to authenticated;

create or replace function public.app_kombax_showcase_inquiry_messages_r58(p_inquiry_id uuid,p_limit integer default 150)
returns table(id uuid,autor_perfil_id uuid,autor_nombre text,texto text,creado_en timestamptz,propio boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_i public.kombax_showcase_inquiries_r58;
begin
  select * into v_i from public.kombax_showcase_inquiries_r58 where id=p_inquiry_id;
  if v_i.id is null then raise exception 'SHOWCASE_INQUIRY_NOT_FOUND';end if;
  if v_i.account_id<>auth.uid() and not public.app_kombax_showcase_puede_gestionar_v045(v_i.marca_id) then raise exception 'SHOWCASE_INQUIRY_FORBIDDEN';end if;
  return query select x.id,x.autor_perfil_id,concat_ws(' ',p.nombre,p.apellidos),x.texto,x.creado_en,x.autor_perfil_id=auth.uid()
  from public.kombax_showcase_inquiry_messages_r58 x join public.perfiles p on p.id=x.autor_perfil_id
  where x.inquiry_id=p_inquiry_id order by x.creado_en,x.id limit least(greatest(coalesce(p_limit,150),1),300);
end $$;
revoke all on function public.app_kombax_showcase_inquiry_messages_r58(uuid,integer) from public,anon;
grant execute on function public.app_kombax_showcase_inquiry_messages_r58(uuid,integer) to authenticated;

create or replace function public.app_kombax_showcase_inquiry_send_r58(p_inquiry_id uuid,p_mensaje text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_text text:=btrim(coalesce(p_mensaje,''));v_i public.kombax_showcase_inquiries_r58;v_id uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if char_length(v_text)<2 or char_length(v_text)>1000 then raise exception 'KOMBAX_SHOWCASE_INQUIRY_TEXT_INVALID';end if;
  select * into v_i from public.kombax_showcase_inquiries_r58 where id=p_inquiry_id for update;
  if v_i.id is null then raise exception 'SHOWCASE_INQUIRY_NOT_FOUND';end if;
  if v_i.account_id<>v_uid and not public.app_kombax_showcase_puede_gestionar_v045(v_i.marca_id) then raise exception 'SHOWCASE_INQUIRY_FORBIDDEN';end if;
  insert into public.kombax_showcase_inquiry_messages_r58(inquiry_id,autor_perfil_id,texto) values(v_i.id,v_uid,v_text) returning id into v_id;
  update public.kombax_showcase_inquiries_r58 set estado=case when v_uid=account_id then 'abierta' else 'respondida' end,actualizada_en=now() where id=v_i.id;
  return jsonb_build_object('ok',true,'id',v_id,'inquiry_id',v_i.id,'channel','showcase');
end $$;
revoke all on function public.app_kombax_showcase_inquiry_send_r58(uuid,text) from public,anon;
grant execute on function public.app_kombax_showcase_inquiry_send_r58(uuid,text) to authenticated;

-- Garantía explícita: el Espectador no recibe capacidades de publicación por el mero registro.
-- No se insertan social.publish/showcase.publish para Auth global ni para tipo espectador.

commit;
