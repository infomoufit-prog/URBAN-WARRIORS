-- KOMBAX RC13 build 20064 · 108
-- Acceso maestro global: contraseña + OTP de correo + sesión de administración efímera.
-- IMPORTANTE: preparada para activación controlada durante QA móvil. No aplicar sin preflight.
begin;

create table if not exists public.kombax_platform_admin_challenges(
  id uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  password_session_id text,
  creado_en timestamptz not null default now(),
  expira_en timestamptz not null default (now()+interval '5 minutes'),
  consumido_en timestamptz,
  constraint kombax_platform_admin_challenge_window check(expira_en>creado_en)
);

create table if not exists public.kombax_platform_admin_sessions(
  id uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  auth_session_id text not null,
  challenge_id uuid references public.kombax_platform_admin_challenges(id) on delete set null,
  creado_en timestamptz not null default now(),
  expira_en timestamptz not null default (now()+interval '30 minutes'),
  terminado_en timestamptz,
  constraint kombax_platform_admin_session_window check(expira_en>creado_en)
);

create index if not exists idx_kombax_platform_admin_challenges_active
  on public.kombax_platform_admin_challenges(perfil_id,expira_en desc)
  where consumido_en is null;
create index if not exists idx_kombax_platform_admin_sessions_active
  on public.kombax_platform_admin_sessions(perfil_id,auth_session_id,expira_en desc)
  where terminado_en is null;

alter table public.kombax_platform_admin_challenges enable row level security;
alter table public.kombax_platform_admin_sessions enable row level security;
revoke all on public.kombax_platform_admin_challenges from public,anon,authenticated;
revoke all on public.kombax_platform_admin_sessions from public,anon,authenticated;

-- Helper interno. Comprueba que el JWT actual contiene el método de autenticación
-- esperado y que fue realizado dentro de la ventana indicada.
create or replace function public.app_kombax_auth_method_recent_v108(
  p_method text,
  p_max_age_seconds integer default 900
)
returns boolean
language sql
stable
security definer
set search_path=public,auth
as $$
  select auth.uid() is not null
    and exists(
      select 1
      from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) as a(entry)
      where lower(coalesce(a.entry->>'method',''))=lower(coalesce(p_method,''))
        and coalesce((a.entry->>'timestamp')::bigint,0)
            >= extract(epoch from now())::bigint-greatest(coalesce(p_max_age_seconds,900),60)
    );
$$;
revoke all on function public.app_kombax_auth_method_recent_v108(text,integer) from public,anon,authenticated;
grant execute on function public.app_kombax_auth_method_recent_v108(text,integer) to service_role;

-- Fase 1. Solo un platform admin activo que acaba de autenticar con contraseña
-- puede obtener un challenge. El challenge NO es la autorización final.
create or replace function public.app_kombax_platform_admin_challenge_start_v108()
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_email text;
  v_id uuid;
  v_expira timestamptz;
  v_session_id text:=nullif(auth.jwt()->>'session_id','');
  v_recent public.kombax_platform_admin_challenges%rowtype;
begin
  if v_uid is null then raise exception 'KOMBAX_ADMIN_AUTH_REQUIRED'; end if;
  if not exists(select 1 from public.kombax_platform_admins a where a.perfil_id=v_uid and a.activo) then
    raise exception 'PLATFORM_ADMIN_REQUIRED';
  end if;
  if not public.app_kombax_auth_method_recent_v108('password',600) then
    raise exception 'KOMBAX_ADMIN_PASSWORD_REQUIRED';
  end if;

  select * into v_recent
  from public.kombax_platform_admin_challenges c
  where c.perfil_id=v_uid and c.consumido_en is null and c.expira_en>now()
  order by c.creado_en desc limit 1;

  if v_recent.id is not null and v_recent.creado_en>now()-interval '30 seconds' then
    raise exception 'KOMBAX_ADMIN_CHALLENGE_RATE_LIMIT';
  end if;

  update public.kombax_platform_admin_challenges
     set consumido_en=coalesce(consumido_en,now())
   where perfil_id=v_uid and consumido_en is null;

  insert into public.kombax_platform_admin_challenges(perfil_id,password_session_id)
  values(v_uid,v_session_id)
  returning id,expira_en into v_id,v_expira;

  select u.email into v_email from auth.users u where u.id=v_uid;

  return jsonb_build_object(
    'challenge_id',v_id,
    'expires_at',v_expira,
    'email_masked',case
      when position('@' in coalesce(v_email,''))>2 then left(v_email,2)||'***'||substr(v_email,position('@' in v_email))
      else coalesce(v_email,'')
    end
  );
end;
$$;
revoke all on function public.app_kombax_platform_admin_challenge_start_v108() from public,anon;
grant execute on function public.app_kombax_platform_admin_challenge_start_v108() to authenticated;

-- Fase 2. Tras verificar el OTP de correo, Supabase emite una nueva sesión cuyo AMR
-- incluye otp. El challenge une esa prueba a una contraseña previa del mismo perfil.
create or replace function public.app_kombax_platform_admin_challenge_complete_v108(p_challenge_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_session_id text:=nullif(auth.jwt()->>'session_id','');
  v_challenge public.kombax_platform_admin_challenges%rowtype;
  v_expira timestamptz:=now()+interval '30 minutes';
  v_nivel text;
begin
  if v_uid is null or v_session_id is null then raise exception 'KOMBAX_ADMIN_AUTH_REQUIRED'; end if;
  select a.nivel into v_nivel from public.kombax_platform_admins a where a.perfil_id=v_uid and a.activo limit 1;
  if v_nivel is null then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  if not public.app_kombax_auth_method_recent_v108('otp',600) then raise exception 'KOMBAX_ADMIN_OTP_REQUIRED'; end if;

  select * into v_challenge
  from public.kombax_platform_admin_challenges c
  where c.id=p_challenge_id and c.perfil_id=v_uid
  for update;

  if v_challenge.id is null or v_challenge.consumido_en is not null or v_challenge.expira_en<=now() then
    raise exception 'KOMBAX_ADMIN_CHALLENGE_INVALID';
  end if;

  update public.kombax_platform_admin_challenges set consumido_en=now() where id=v_challenge.id;
  update public.kombax_platform_admin_sessions
     set terminado_en=coalesce(terminado_en,now())
   where perfil_id=v_uid and terminado_en is null;

  insert into public.kombax_platform_admin_sessions(perfil_id,auth_session_id,challenge_id,expira_en)
  values(v_uid,v_session_id,v_challenge.id,v_expira);

  return jsonb_build_object('authorized',true,'nivel',v_nivel,'expires_at',v_expira);
end;
$$;
revoke all on function public.app_kombax_platform_admin_challenge_complete_v108(uuid) from public,anon;
grant execute on function public.app_kombax_platform_admin_challenge_complete_v108(uuid) to authenticated;

create or replace function public.app_kombax_platform_admin_session_end_v108()
returns boolean
language plpgsql
security definer
set search_path=public,auth
as $$
declare v_uid uuid:=auth.uid();v_session_id text:=nullif(auth.jwt()->>'session_id','');
begin
  if v_uid is null then return false; end if;
  update public.kombax_platform_admin_sessions
     set terminado_en=coalesce(terminado_en,now())
   where perfil_id=v_uid and auth_session_id=v_session_id and terminado_en is null;
  return true;
end;
$$;
revoke all on function public.app_kombax_platform_admin_session_end_v108() from public,anon;
grant execute on function public.app_kombax_platform_admin_session_end_v108() to authenticated;

-- A partir de 108, ser owner/admin en la tabla NO basta para invocar la consola.
-- Hace falta una sesión maestra creada tras contraseña + OTP y ligada al session_id actual.
create or replace function public.app_kombax_es_platform_admin_v055()
returns boolean
language sql
stable
security definer
set search_path=public,auth
as $$
  select auth.uid() is not null
    and nullif(auth.jwt()->>'session_id','') is not null
    and exists(select 1 from public.kombax_platform_admins a where a.perfil_id=auth.uid() and a.activo)
    and exists(
      select 1 from public.kombax_platform_admin_sessions s
      where s.perfil_id=auth.uid()
        and s.auth_session_id=(auth.jwt()->>'session_id')
        and s.terminado_en is null
        and s.expira_en>now()
    );
$$;
revoke all on function public.app_kombax_es_platform_admin_v055() from public,anon,authenticated;
grant execute on function public.app_kombax_es_platform_admin_v055() to service_role;

create or replace function public.app_kombax_platform_context_v055()
returns jsonb
language sql
stable
security definer
set search_path=public,auth
as $$
  select case when public.app_kombax_es_platform_admin_v055() then
    jsonb_build_object(
      'authorized',true,
      'nivel',(select nivel from public.kombax_platform_admins where perfil_id=auth.uid() and activo limit 1),
      'expires_at',(
        select s.expira_en from public.kombax_platform_admin_sessions s
        where s.perfil_id=auth.uid() and s.auth_session_id=(auth.jwt()->>'session_id')
          and s.terminado_en is null and s.expira_en>now()
        order by s.expira_en desc limit 1
      )
    )
  else jsonb_build_object('authorized',false) end;
$$;
revoke all on function public.app_kombax_platform_context_v055() from public,anon;
grant execute on function public.app_kombax_platform_context_v055() to authenticated;

notify pgrst,'reload schema';
commit;
