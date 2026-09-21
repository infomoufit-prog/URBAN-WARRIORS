begin;

create table if not exists public.kombax_platform_legal_acceptances_v129(
  id uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  tipo text not null check(tipo in ('terms','privacy_notice')),
  version text not null,
  acknowledged boolean not null default true,
  user_agent text,
  acknowledged_at timestamptz not null default now(),
  constraint kombax_platform_legal_acceptance_unique_v129 unique(perfil_id,tipo,version)
);

alter table public.kombax_platform_legal_acceptances_v129 enable row level security;
revoke all on table public.kombax_platform_legal_acceptances_v129 from public,anon,authenticated;

create index if not exists idx_kombax_platform_legal_acceptances_profile_v129
  on public.kombax_platform_legal_acceptances_v129(perfil_id,acknowledged_at desc);

create or replace function public.app_kombax_platform_legal_status_v129()
returns jsonb
language plpgsql
stable
security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_terms text:='1.0.0';
  v_privacy text:='1.0.0';
  v_terms_ok boolean:=false;
  v_privacy_ok boolean:=false;
begin
  if v_uid is null then raise exception 'KOMBAX_AUTH_REQUIRED'; end if;
  select exists(
    select 1 from public.kombax_platform_legal_acceptances_v129 a
    where a.perfil_id=v_uid and a.tipo='terms' and a.version=v_terms and a.acknowledged
  ) into v_terms_ok;
  select exists(
    select 1 from public.kombax_platform_legal_acceptances_v129 a
    where a.perfil_id=v_uid and a.tipo='privacy_notice' and a.version=v_privacy and a.acknowledged
  ) into v_privacy_ok;
  return jsonb_build_object(
    'terms_version',v_terms,
    'privacy_version',v_privacy,
    'terms_accepted',v_terms_ok,
    'privacy_acknowledged',v_privacy_ok,
    'required',not(v_terms_ok and v_privacy_ok)
  );
end;
$$;

create or replace function public.app_kombax_platform_legal_accept_v129(
  p_terms_version text,
  p_privacy_version text,
  p_terms_accepted boolean,
  p_privacy_acknowledged boolean,
  p_user_agent text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_terms text:=btrim(coalesce(p_terms_version,''));
  v_privacy text:=btrim(coalesce(p_privacy_version,''));
  v_ua text:=left(nullif(btrim(coalesce(p_user_agent,'')),''),500);
begin
  if v_uid is null then raise exception 'KOMBAX_AUTH_REQUIRED'; end if;
  if not exists(select 1 from public.perfiles p where p.id=v_uid) then raise exception 'KOMBAX_PROFILE_REQUIRED'; end if;
  if v_terms<>'1.0.0' or v_privacy<>'1.0.0' then raise exception 'KOMBAX_PLATFORM_LEGAL_VERSION_INVALID'; end if;
  if p_terms_accepted is not true then raise exception 'KOMBAX_PLATFORM_TERMS_REQUIRED'; end if;
  if p_privacy_acknowledged is not true then raise exception 'KOMBAX_PLATFORM_PRIVACY_NOTICE_REQUIRED'; end if;

  insert into public.kombax_platform_legal_acceptances_v129(perfil_id,tipo,version,acknowledged,user_agent)
  values(v_uid,'terms',v_terms,true,v_ua)
  on conflict(perfil_id,tipo,version) do update
    set acknowledged=true,user_agent=excluded.user_agent,acknowledged_at=now();

  insert into public.kombax_platform_legal_acceptances_v129(perfil_id,tipo,version,acknowledged,user_agent)
  values(v_uid,'privacy_notice',v_privacy,true,v_ua)
  on conflict(perfil_id,tipo,version) do update
    set acknowledged=true,user_agent=excluded.user_agent,acknowledged_at=now();

  insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
  values(v_uid,null,'kombax.platform.legal.accept','platform_legal',v_uid,
    jsonb_build_object('terms_version',v_terms,'privacy_version',v_privacy));

  return public.app_kombax_platform_legal_status_v129();
end;
$$;

revoke all on function public.app_kombax_platform_legal_status_v129() from public,anon;
revoke all on function public.app_kombax_platform_legal_accept_v129(text,text,boolean,boolean,text) from public,anon;
grant execute on function public.app_kombax_platform_legal_status_v129() to authenticated;
grant execute on function public.app_kombax_platform_legal_accept_v129(text,text,boolean,boolean,text) to authenticated;

comment on table public.kombax_platform_legal_acceptances_v129 is 'Platform-level Terms acceptance and Privacy Notice acknowledgement. Separate from optional Social consent.';

notify pgrst,'reload schema';
commit;
