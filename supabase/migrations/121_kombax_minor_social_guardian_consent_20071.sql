-- KOMBAX RC13 build 20071 · 121
-- Consentimiento adulto verificable para KOMBAX Social en perfiles personales <18.
begin;

create table if not exists public.kombax_social_minor_consents_v121(
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null references public.socios(id) on delete cascade,
  minor_profile_id uuid not null references public.perfiles(id) on delete cascade,
  tutor_profile_id uuid not null references public.perfiles(id) on delete restrict,
  estado text not null default 'pending' check(estado in ('pending','approved','rejected','revoked')),
  rules_version text not null default '1.3',
  solicitado_en timestamptz not null default now(),
  decidido_en timestamptz,
  revocado_en timestamptz,
  actualizado_en timestamptz not null default now(),
  unique(club_id,socio_id,tutor_profile_id)
);
create index if not exists idx_kombax_minor_consents_tutor_v121 on public.kombax_social_minor_consents_v121(tutor_profile_id,estado,solicitado_en desc);
create index if not exists idx_kombax_minor_consents_minor_v121 on public.kombax_social_minor_consents_v121(minor_profile_id,estado,solicitado_en desc);
alter table public.kombax_social_minor_consents_v121 enable row level security;
revoke all on public.kombax_social_minor_consents_v121 from public,anon,authenticated;

create or replace function public.app_kombax_social_minor_consent_status_v121()
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_mine jsonb;v_approvals jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'consent_id',c.id,'club_id',c.club_id,'socio_id',c.socio_id,'estado',c.estado,
    'tutor_profile_id',c.tutor_profile_id,'tutor_name',trim(concat_ws(' ',p.nombre,p.apellidos)),
    'solicitado_en',c.solicitado_en,'decidido_en',c.decidido_en,'revocado_en',c.revocado_en
  ) order by c.solicitado_en desc),'[]'::jsonb) into v_mine
  from public.kombax_social_minor_consents_v121 c
  join public.perfiles p on p.id=c.tutor_profile_id
  where c.minor_profile_id=v_uid;

  select coalesce(jsonb_agg(jsonb_build_object(
    'consent_id',c.id,'club_id',c.club_id,'socio_id',c.socio_id,'estado',c.estado,
    'minor_profile_id',c.minor_profile_id,'minor_name',trim(concat_ws(' ',s.nombre,s.apellidos)),
    'solicitado_en',c.solicitado_en,'decidido_en',c.decidido_en,'revocado_en',c.revocado_en
  ) order by c.solicitado_en asc),'[]'::jsonb) into v_approvals
  from public.kombax_social_minor_consents_v121 c
  join public.socios s on s.id=c.socio_id
  where c.tutor_profile_id=v_uid and c.estado='pending';

  return jsonb_build_object('mine',v_mine,'approvals',v_approvals);
end $$;
revoke all on function public.app_kombax_social_minor_consent_status_v121() from public,anon;
grant execute on function public.app_kombax_social_minor_consent_status_v121() to authenticated;

create or replace function public.app_kombax_social_minor_consent_mutate_v121(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_existing public.app_mutation_requests;v_result jsonb;v_club uuid;v_socio public.socios;v_tutor uuid;v_id uuid;v_state text;v_consent public.kombax_social_minor_consents_v121;v_age integer;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  if p_operation not in ('kombax.social.minor.consent.request','kombax.social.minor.consent.decide') then raise exception 'KOMBAX_MINOR_CONSENT_OPERATION_INVALID';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,nullif(p_payload->>'club_id','')::uuid,p_operation);
  end if;

  if p_operation='kombax.social.minor.consent.request' then
    begin v_club:=(p_payload->>'club_id')::uuid;exception when others then raise exception 'KOMBAX_CLUB_ID_INVALID';end;
    select * into v_socio from public.socios where club_id=v_club and perfil_id=v_uid and estado='activo' order by creado_en desc limit 1;
    if v_socio.id is null or v_socio.fecha_nacimiento is null then raise exception 'KOMBAX_SOCIAL_AGE_VERIFICATION_REQUIRED';end if;
    v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento))::integer;
    if v_age>=18 then raise exception 'KOMBAX_MINOR_CONSENT_NOT_REQUIRED';end if;
    select t.tutor_perfil_id into v_tutor from public.tutores_socios t where t.club_id=v_club and t.socio_id=v_socio.id and t.contacto_principal order by t.id limit 1;
    if v_tutor is null then raise exception 'KOMBAX_SOCIAL_GUARDIAN_LINK_REQUIRED';end if;
    insert into public.kombax_social_minor_consents_v121(club_id,socio_id,minor_profile_id,tutor_profile_id,estado,rules_version,solicitado_en,decidido_en,revocado_en,actualizado_en)
    values(v_club,v_socio.id,v_uid,v_tutor,'pending','1.3',now(),null,null,now())
    on conflict(club_id,socio_id,tutor_profile_id) do update set minor_profile_id=excluded.minor_profile_id,estado='pending',rules_version='1.3',solicitado_en=now(),decidido_en=null,revocado_en=null,actualizado_en=now()
    returning * into v_consent;
    v_result:=jsonb_build_object('consent_id',v_consent.id,'estado',v_consent.estado,'tutor_profile_id',v_tutor);
  else
    begin v_id:=(p_payload->>'consent_id')::uuid;exception when others then raise exception 'KOMBAX_MINOR_CONSENT_ID_INVALID';end;
    v_state:=lower(coalesce(p_payload->>'estado',''));
    if v_state not in ('approved','rejected','revoked') then raise exception 'KOMBAX_MINOR_CONSENT_STATE_INVALID';end if;
    select * into v_consent from public.kombax_social_minor_consents_v121 where id=v_id for update;
    if v_consent.id is null or v_consent.tutor_profile_id<>v_uid then raise exception 'KOMBAX_MINOR_CONSENT_FORBIDDEN';end if;
    if not exists(select 1 from public.tutores_socios t where t.club_id=v_consent.club_id and t.socio_id=v_consent.socio_id and t.tutor_perfil_id=v_uid) then raise exception 'KOMBAX_MINOR_CONSENT_RELATION_REQUIRED';end if;
    update public.kombax_social_minor_consents_v121
       set estado=v_state,decidido_en=case when v_state in ('approved','rejected') then now() else decidido_en end,
           revocado_en=case when v_state='revoked' then now() else null end,actualizado_en=now()
     where id=v_id returning * into v_consent;
    if v_state='revoked' then
      update public.identidades_sociales set estado='cerrada',actualizado_en=now() where perfil_id=v_consent.minor_profile_id and estado='activa';
      update public.perfiles_kombax_directos set social_activo=false,social_activado_en=null,actualizado_en=now() where perfil_id=v_consent.minor_profile_id and fecha_nacimiento_verificada is not null and extract(year from age(current_date,fecha_nacimiento_verificada))<18;
    end if;
    v_result:=jsonb_build_object('consent_id',v_consent.id,'estado',v_consent.estado);
  end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',v_result);
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_social_minor_consent_mutate_v121(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_minor_consent_mutate_v121(text,jsonb,uuid) to authenticated;

create or replace function public.kombax_minor_social_consent_guard_v121()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_socio public.socios;v_age integer;
begin
  if new.estado<>'activa' then return new;end if;
  select * into v_socio from public.socios where id=new.socio_origen_id;
  if v_socio.id is null or v_socio.fecha_nacimiento is null then return new;end if;
  v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento))::integer;
  if v_age>=18 then return new;end if;
  if not exists(select 1 from public.kombax_social_minor_consents_v121 c where c.club_id=v_socio.club_id and c.socio_id=v_socio.id and c.minor_profile_id=new.perfil_id and c.estado='approved' and c.revocado_en is null) then
    raise exception 'KOMBAX_SOCIAL_GUARDIAN_CONSENT_REQUIRED';
  end if;
  return new;
end $$;

drop trigger if exists trg_kombax_minor_social_consent_guard_v121 on public.identidades_sociales;
create trigger trg_kombax_minor_social_consent_guard_v121 before insert or update of estado,socio_origen_id on public.identidades_sociales for each row execute function public.kombax_minor_social_consent_guard_v121();

create or replace function public.kombax_minor_direct_social_consent_guard_v121()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_socio public.socios;v_age integer;
begin
  if new.social_activo is not true then return new;end if;
  if new.fecha_nacimiento_verificada is null then return new;end if;
  v_age:=extract(year from age(current_date,new.fecha_nacimiento_verificada))::integer;
  if v_age>=18 then return new;end if;
  select * into v_socio from public.socios s where s.perfil_id=new.perfil_id and s.estado='activo' order by s.creado_en desc limit 1;
  if v_socio.id is null then raise exception 'KOMBAX_SOCIAL_GUARDIAN_LINK_REQUIRED';end if;
  if not exists(select 1 from public.kombax_social_minor_consents_v121 c where c.club_id=v_socio.club_id and c.socio_id=v_socio.id and c.minor_profile_id=new.perfil_id and c.estado='approved' and c.revocado_en is null) then
    raise exception 'KOMBAX_SOCIAL_GUARDIAN_CONSENT_REQUIRED';
  end if;
  return new;
end $$;

drop trigger if exists trg_kombax_minor_direct_social_consent_guard_v121 on public.perfiles_kombax_directos;
create trigger trg_kombax_minor_direct_social_consent_guard_v121 before insert or update of social_activo,fecha_nacimiento_verificada on public.perfiles_kombax_directos for each row execute function public.kombax_minor_direct_social_consent_guard_v121();

notify pgrst,'reload schema';
commit;
