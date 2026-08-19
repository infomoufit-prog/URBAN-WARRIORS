-- KOMBAX RC13 build 20046 · 086 · access-code anti brute-force hardening
-- Removes anonymous validation and rate-limits authenticated validation without invalidating current club codes.
begin;

create table if not exists public.kombax_codigo_intentos_v086(
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  club_id uuid not null references public.clubes(id) on delete cascade,
  tipo text not null check(tipo in ('alumnos','equipo')),
  fallos integer not null default 0 check(fallos>=0),
  ventana_inicia_en timestamptz not null default now(),
  ultimo_intento_en timestamptz not null default now(),
  bloqueado_hasta timestamptz,
  primary key(perfil_id,club_id,tipo)
);
alter table public.kombax_codigo_intentos_v086 enable row level security;
revoke all on public.kombax_codigo_intentos_v086 from public,anon,authenticated;

-- Move the secret comparison to an internal helper. The legacy v060 endpoint remains
-- temporarily callable for build 20.045 compatibility, but is now rate-limited per IP.
create or replace function public.app_kombax_codigo_validar_raw_v086(p_club_slug text,p_tipo text,p_codigo text)
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
revoke all on function public.app_kombax_codigo_validar_raw_v086(text,text,text) from public,anon,authenticated;
grant execute on function public.app_kombax_codigo_validar_raw_v086(text,text,text) to service_role;

create table if not exists public.kombax_codigo_intentos_anon_v086(
  fingerprint text not null,
  club_id uuid not null references public.clubes(id) on delete cascade,
  tipo text not null check(tipo in ('alumnos','equipo')),
  fallos integer not null default 0 check(fallos>=0),
  ventana_inicia_en timestamptz not null default now(),
  ultimo_intento_en timestamptz not null default now(),
  bloqueado_hasta timestamptz,
  primary key(fingerprint,club_id,tipo)
);
alter table public.kombax_codigo_intentos_anon_v086 enable row level security;
revoke all on public.kombax_codigo_intentos_anon_v086 from public,anon,authenticated;

-- Rebind the authenticated validator to the internal comparison helper.
create or replace function public.app_kombax_codigo_validar_seguro_v086(p_club_slug text,p_tipo text,p_codigo text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  uid uuid:=auth.uid(); t text:=lower(trim(coalesce(p_tipo,''))); cid uuid; row public.kombax_codigo_intentos_v086;
  chk jsonb; now_ts timestamptz:=clock_timestamp(); next_fail integer;
begin
  if uid is null then raise exception 'AUTH_REQUIRED';end if;
  if t not in ('alumnos','equipo') then return jsonb_build_object('valid',false);end if;
  select c.id into cid from public.clubes c where lower(c.slug)=lower(trim(coalesce(p_club_slug,''))) and c.activo limit 1;
  if cid is null then return jsonb_build_object('valid',false);end if;
  insert into public.kombax_codigo_intentos_v086(perfil_id,club_id,tipo,fallos,ventana_inicia_en,ultimo_intento_en)
  values(uid,cid,t,0,now_ts,now_ts) on conflict(perfil_id,club_id,tipo) do nothing;
  select * into row from public.kombax_codigo_intentos_v086 where perfil_id=uid and club_id=cid and tipo=t for update;
  if row.bloqueado_hasta is not null and row.bloqueado_hasta>now_ts then
    return jsonb_build_object('valid',false,'rate_limited',true,'retry_after_seconds',greatest(1,ceil(extract(epoch from (row.bloqueado_hasta-now_ts)))::integer));
  end if;
  if row.ventana_inicia_en < now_ts-interval '15 minutes' then
    update public.kombax_codigo_intentos_v086 set fallos=0,ventana_inicia_en=now_ts,bloqueado_hasta=null,ultimo_intento_en=now_ts where perfil_id=uid and club_id=cid and tipo=t;
    row.fallos:=0;row.ventana_inicia_en:=now_ts;row.bloqueado_hasta:=null;
  end if;
  chk:=public.app_kombax_codigo_validar_raw_v086(p_club_slug,t,p_codigo);
  if coalesce((chk->>'valid')::boolean,false) then
    update public.kombax_codigo_intentos_v086 set fallos=0,ventana_inicia_en=now_ts,bloqueado_hasta=null,ultimo_intento_en=now_ts where perfil_id=uid and club_id=cid and tipo=t;
    return chk;
  end if;
  next_fail:=coalesce(row.fallos,0)+1;
  update public.kombax_codigo_intentos_v086
  set fallos=next_fail,ultimo_intento_en=now_ts,bloqueado_hasta=case when next_fail>=5 then now_ts+interval '15 minutes' else null end
  where perfil_id=uid and club_id=cid and tipo=t;
  if next_fail>=5 then return jsonb_build_object('valid',false,'rate_limited',true,'retry_after_seconds',900);end if;
  return jsonb_build_object('valid',false,'rate_limited',false,'remaining_attempts',greatest(0,5-next_fail));
end $$;
revoke all on function public.app_kombax_codigo_validar_seguro_v086(text,text,text) from public,anon;
grant execute on function public.app_kombax_codigo_validar_seguro_v086(text,text,text) to authenticated;

-- Transitional compatibility endpoint for still-deployed 20.045 clients.
-- Anonymous requests are limited to 10 failures / 15 minutes / IP + club + type.
create or replace function public.app_kombax_codigo_validar_v060(p_club_slug text,p_tipo text,p_codigo text)
returns jsonb language plpgsql security definer set search_path=public,auth,extensions as $$
declare
  t text:=lower(trim(coalesce(p_tipo,''))); cid uuid; chk jsonb; now_ts timestamptz:=clock_timestamp(); row public.kombax_codigo_intentos_anon_v086;
  headers jsonb:=coalesce(nullif(current_setting('request.headers',true),'')::jsonb,'{}'::jsonb);
  ip text; ua text; fp text; next_fail integer;
begin
  if auth.uid() is not null then return public.app_kombax_codigo_validar_seguro_v086(p_club_slug,t,p_codigo);end if;
  if t not in ('alumnos','equipo') then return jsonb_build_object('valid',false);end if;
  select c.id into cid from public.clubes c where lower(c.slug)=lower(trim(coalesce(p_club_slug,''))) and c.activo limit 1;
  if cid is null then return jsonb_build_object('valid',false);end if;
  ip:=split_part(coalesce(headers->>'x-forwarded-for','unknown'),',',1);
  ua:=left(coalesce(headers->>'user-agent',''),180);
  fp:=encode(extensions.digest(convert_to(ip||'|'||ua,'UTF8'),'sha256'),'hex');
  insert into public.kombax_codigo_intentos_anon_v086(fingerprint,club_id,tipo,fallos,ventana_inicia_en,ultimo_intento_en)
  values(fp,cid,t,0,now_ts,now_ts) on conflict(fingerprint,club_id,tipo) do nothing;
  select * into row from public.kombax_codigo_intentos_anon_v086 where fingerprint=fp and club_id=cid and tipo=t for update;
  if row.bloqueado_hasta is not null and row.bloqueado_hasta>now_ts then
    return jsonb_build_object('valid',false,'rate_limited',true,'retry_after_seconds',greatest(1,ceil(extract(epoch from (row.bloqueado_hasta-now_ts)))::integer));
  end if;
  if row.ventana_inicia_en < now_ts-interval '15 minutes' then
    update public.kombax_codigo_intentos_anon_v086 set fallos=0,ventana_inicia_en=now_ts,bloqueado_hasta=null,ultimo_intento_en=now_ts where fingerprint=fp and club_id=cid and tipo=t;
    row.fallos:=0;row.ventana_inicia_en:=now_ts;row.bloqueado_hasta:=null;
  end if;
  chk:=public.app_kombax_codigo_validar_raw_v086(p_club_slug,t,p_codigo);
  if coalesce((chk->>'valid')::boolean,false) then
    update public.kombax_codigo_intentos_anon_v086 set fallos=0,ventana_inicia_en=now_ts,bloqueado_hasta=null,ultimo_intento_en=now_ts where fingerprint=fp and club_id=cid and tipo=t;
    return chk;
  end if;
  next_fail:=coalesce(row.fallos,0)+1;
  update public.kombax_codigo_intentos_anon_v086
  set fallos=next_fail,ultimo_intento_en=now_ts,bloqueado_hasta=case when next_fail>=10 then now_ts+interval '15 minutes' else null end
  where fingerprint=fp and club_id=cid and tipo=t;
  if next_fail>=10 then return jsonb_build_object('valid',false,'rate_limited',true,'retry_after_seconds',900);end if;
  return jsonb_build_object('valid',false,'rate_limited',false,'remaining_attempts',greatest(0,10-next_fail));
end $$;
revoke all on function public.app_kombax_codigo_validar_v060(text,text,text) from public;
grant execute on function public.app_kombax_codigo_validar_v060(text,text,text) to anon,authenticated,service_role;

create or replace function public.app_kombax_equipo_solicitar_v060(p_club_slug text,p_codigo text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare uid uuid:=auth.uid(); chk jsonb; cid uuid; ver integer; row public.kombax_solicitudes_equipo_club; mail text:=lower(coalesce(auth.jwt()->>'email',''));
begin
  if uid is null then raise exception 'AUTH_REQUIRED';end if;
  chk:=public.app_kombax_codigo_validar_seguro_v086(p_club_slug,'equipo',p_codigo);
  if coalesce((chk->>'valid')::boolean,false) is not true then
    return jsonb_build_object(
      'ok',false,
      'error_code',case when coalesce((chk->>'rate_limited')::boolean,false) then 'KOMBAX_ACCESS_CODE_RATE_LIMIT' else 'KOMBAX_ACCESS_CODE_INVALID' end,
      'message',case when coalesce((chk->>'rate_limited')::boolean,false) then 'Demasiados intentos. Espera 15 minutos antes de volver a probar.' else 'Código de equipo no válido.' end,
      'retry_after_seconds',coalesce((chk->>'retry_after_seconds')::integer,0)
    );
  end if;
  cid:=(chk->>'club_id')::uuid;ver:=(chk->>'version')::integer;
  if exists(select 1 from public.miembros_club m where m.club_id=cid and m.perfil_id=uid and m.activo) then raise exception 'Tu cuenta ya pertenece a este club';end if;
  insert into public.perfiles(id,nombre,apellidos)
  values(uid,coalesce(nullif(auth.jwt()->'user_metadata'->>'nombre',''),split_part(mail,'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos',''))
  on conflict(id) do nothing;
  insert into public.kombax_solicitudes_equipo_club(club_id,perfil_id,email,estado,codigo_version,creado_en,actualizado_en,revisado_en,revisado_por,rol_asignado,coordinacion,nota_revision)
  values(cid,uid,mail,'pendiente',ver,now(),now(),null,null,null,false,null)
  on conflict(club_id,perfil_id) do update set email=excluded.email,estado='pendiente',codigo_version=excluded.codigo_version,actualizado_en=now(),revisado_en=null,revisado_por=null,rol_asignado=null,coordinacion=false,nota_revision=null
  returning * into row;
  return jsonb_build_object('ok',true,'id',row.id,'club_id',row.club_id,'club_slug',chk->>'club_slug','club_nombre',chk->>'club_nombre','estado',row.estado,'creado_en',row.creado_en);
end $$;
revoke all on function public.app_kombax_equipo_solicitar_v060(text,text) from public,anon;
grant execute on function public.app_kombax_equipo_solicitar_v060(text,text) to authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare payload jsonb:=coalesce(p_payload,'{}'::jsonb); code text:=trim(coalesce(payload->>'invite_code','')); slug text:=trim(coalesce(payload->>'club_slug','')); chk jsonb; result jsonb;
begin
  if p_operation in ('invitacion.crear','invitacion.aceptar') then raise exception 'INVITATION_FLOW_DEPRECATED: usa los códigos permanentes del club';end if;
  if p_operation='cuenta.registrar' and code<>'' then
    chk:=public.app_kombax_codigo_validar_seguro_v086(slug,'alumnos',code);
    if coalesce((chk->>'valid')::boolean,false) is not true then
      return jsonb_build_object(
        'ok',false,
        'operation',p_operation,
        'request_id',p_request_id,
        'error_code',case when coalesce((chk->>'rate_limited')::boolean,false) then 'KOMBAX_ACCESS_CODE_RATE_LIMIT' else 'KOMBAX_ACCESS_CODE_INVALID' end,
        'message',case when coalesce((chk->>'rate_limited')::boolean,false) then 'Demasiados intentos. Espera 15 minutos antes de volver a probar.' else 'Código de alumnos/familias no válido para este club.' end,
        'retry_after_seconds',coalesce((chk->>'retry_after_seconds')::integer,0)
      );
    end if;
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

notify pgrst,'reload schema';
commit;
