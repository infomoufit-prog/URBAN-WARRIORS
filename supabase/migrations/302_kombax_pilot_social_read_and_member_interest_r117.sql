-- KOMBAX R117 pilot hotfix
-- Authenticated identities can read KOMBAX Social. Publishing remains separately gated.
-- Member/Practitioner access-interest messages are surfaced to Club Dirección/Secretaría.

create or replace function public.app_kombax_social_read_access_r117()
returns boolean
language sql
stable
security definer
set search_path='public','auth'
as $$
  select auth.uid() is not null;
$$;

revoke all on function public.app_kombax_social_read_access_r117() from public,anon;
grant execute on function public.app_kombax_social_read_access_r117() to authenticated;

do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_social_feed_v238' and p.prokind='f';
  d:=replace(d,
    'if not public.app_kombax_social_acceso_v041() then raise exception ''SOCIAL_ACCESS_REQUIRED'';end if;',
    'if not public.app_kombax_social_read_access_r117() then raise exception ''AUTH_REQUIRED'';end if;');
  execute d;

  select pg_get_functiondef(p.oid) into d
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_social_feed_v239' and p.prokind='f';
  d:=replace(d,
    'if not public.app_kombax_social_acceso_v041() then raise exception ''SOCIAL_ACCESS_REQUIRED''; end if;',
    'if not public.app_kombax_social_read_access_r117() then raise exception ''AUTH_REQUIRED''; end if;');
  execute d;

  select pg_get_functiondef(p.oid) into d
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_social_comentarios_v053' and p.prokind='f';
  d:=replace(d,
    'if not public.app_kombax_social_acceso_v041() then raise exception ''SOCIAL_ACCESS_REQUIRED'';end if;',
    'if not public.app_kombax_social_read_access_r117() then raise exception ''AUTH_REQUIRED'';end if;');
  execute d;

  select pg_get_functiondef(p.oid) into d
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_social_preference_v240' and p.prokind='f';
  d:=replace(d,
    'if not public.app_kombax_social_acceso_v041() then raise exception ''SOCIAL_ACCESS_REQUIRED'';end if;',
    'if not public.app_kombax_social_read_access_r117() then raise exception ''AUTH_REQUIRED'';end if;');
  execute d;

  select pg_get_functiondef(p.oid) into d
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_social_report_offtopic_v240' and p.prokind='f';
  d:=replace(d,
    'if not public.app_kombax_social_acceso_v041() then raise exception ''SOCIAL_ACCESS_REQUIRED'';end if;',
    'if not public.app_kombax_social_read_access_r117() then raise exception ''AUTH_REQUIRED'';end if;');
  execute d;
end $$;

create or replace function public.app_kombax_club_interest_send_r58(p_club_id uuid, p_mensaje text)
returns jsonb
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_uid uuid:=auth.uid();
  v_text text:=btrim(coalesce(p_mensaje,''));
  v_thread uuid;
  v_msg uuid;
  v_name text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if char_length(v_text)<2 or char_length(v_text)>1000 then raise exception 'KOMBAX_CLUB_INTEREST_TEXT_INVALID'; end if;
  if not exists(select 1 from public.clubes where id=p_club_id and activo) then raise exception 'KOMBAX_CLUB_NOT_AVAILABLE'; end if;

  insert into public.perfiles(id,nombre,apellidos)
  values(
    v_uid,
    coalesce(auth.jwt()->'user_metadata'->>'nombre',split_part(coalesce(auth.jwt()->>'email','usuario'),'@',1)),
    coalesce(auth.jwt()->'user_metadata'->>'apellidos','')
  )
  on conflict(id) do nothing;

  select btrim(concat_ws(' ',p.nombre,p.apellidos)) into v_name
  from public.perfiles p where p.id=v_uid;

  insert into public.kombax_club_interest_threads_r58(club_id,account_id)
  values(p_club_id,v_uid)
  on conflict(club_id,account_id)
  do update set estado='abierta',actualizada_en=now()
  returning id into v_thread;

  insert into public.kombax_club_interest_messages_r58(thread_id,autor_perfil_id,texto)
  values(v_thread,v_uid,v_text)
  returning id into v_msg;

  insert into public.notificaciones(
    club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
  )
  select
    p_club_id,
    rol,
    'club-interest-'||v_thread::text||'-'||rol::text,
    'inscripcion',
    'Nueva consulta de acceso',
    coalesce(nullif(v_name,''),'Una cuenta KOMBAX')||' quiere vincularse al club.',
    'members',
    jsonb_build_object(
      'thread_id',v_thread,
      'account_id',v_uid,
      'message_id',v_msg,
      'kind','club_member_interest'
    ),
    v_uid
  from unnest(array['direccion','secretaria']::public.rol_club[]) rol
  on conflict (club_id,rol_destino,clave)
  where (clave is not null and rol_destino is not null)
  do update set
    titulo=excluded.titulo,
    cuerpo=excluded.cuerpo,
    ruta=excluded.ruta,
    datos=excluded.datos,
    leida=false,
    leida_en=null,
    ciclo_estado='activo',
    archivado_en=null,
    archivado_por=null,
    papelera_en=null,
    papelera_por=null,
    creado_en=now();

  return jsonb_build_object(
    'ok',true,
    'thread_id',v_thread,
    'message_id',v_msg,
    'membership_created',false,
    'club_notified',true
  );
end $$;

create or replace function public.app_kombax_club_interest_list_r98(p_club_id uuid)
returns table(thread_id uuid,account_id uuid,account_name text,account_email text,message text,sent_at timestamptz)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null
     or not (
       public.tiene_rol_club(p_club_id,'direccion','secretaria')
       or exists(
         select 1 from public.miembros_club mc
         where mc.club_id=p_club_id
           and mc.perfil_id=auth.uid()
           and mc.activo
           and mc.coordinacion
       )
     ) then
    raise exception 'KOMBAX_CLUB_INTEREST_FORBIDDEN' using errcode='42501';
  end if;

  return query
  select
    t.id,
    t.account_id,
    btrim(concat_ws(' ',p.nombre,p.apellidos)),
    lower(coalesce(u.email,'')),
    m.texto,
    m.creado_en
  from public.kombax_club_interest_threads_r58 t
  join public.perfiles p on p.id=t.account_id
  left join auth.users u on u.id=t.account_id
  join lateral (
    select x.texto,x.creado_en
    from public.kombax_club_interest_messages_r58 x
    where x.thread_id=t.id
    order by x.creado_en desc
    limit 1
  ) m on true
  where t.club_id=p_club_id
    and t.estado='abierta'
  order by m.creado_en desc
  limit 100;
end $$;

revoke all on function public.app_kombax_club_interest_list_r98(uuid) from public,anon,service_role;
grant execute on function public.app_kombax_club_interest_list_r98(uuid) to authenticated;

insert into public.notificaciones(
  club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
)
select
  t.club_id,
  rol,
  'club-interest-'||t.id::text||'-'||rol::text,
  'inscripcion',
  'Nueva consulta de acceso',
  coalesce(nullif(btrim(concat_ws(' ',p.nombre,p.apellidos)),''),'Una cuenta KOMBAX')||' quiere vincularse al club.',
  'members',
  jsonb_build_object('thread_id',t.id,'account_id',t.account_id,'kind','club_member_interest'),
  t.account_id
from public.kombax_club_interest_threads_r58 t
join public.perfiles p on p.id=t.account_id
cross join unnest(array['direccion','secretaria']::public.rol_club[]) rol
where t.estado='abierta'
on conflict (club_id,rol_destino,clave)
where (clave is not null and rol_destino is not null)
do nothing;

notify pgrst,'reload schema';
