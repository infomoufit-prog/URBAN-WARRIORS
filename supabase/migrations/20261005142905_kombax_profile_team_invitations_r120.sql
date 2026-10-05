-- R120: consent-based delegation for direct profiles. Club membership/team codes
-- and federation-specific roles remain under their existing operations.
begin;
create table public.kombax_profile_team_invites_r120(
 id uuid primary key default gen_random_uuid(),
 profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
 email text not null check(email=lower(btrim(email)) and length(email)<=254 and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
 role text not null check(role in ('admin','editor','comunicacion')),
 status text not null default 'pending' check(status in ('pending','accepted','declined','revoked')),
 invited_by uuid not null references public.perfiles(id),
 accepted_by uuid references public.perfiles(id),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '7 days',
 updated_at timestamptz not null default now()
);
create index kombax_profile_team_invite_inbox_r120 on public.kombax_profile_team_invites_r120(email,expires_at) where status='pending';
create index kombax_profile_team_invite_profile_r120 on public.kombax_profile_team_invites_r120(profile_id,created_at desc);
alter table public.kombax_profile_team_invites_r120 enable row level security;
revoke all on public.kombax_profile_team_invites_r120 from public,anon,authenticated;

create table public.kombax_profile_team_requests_r120(
 request_id uuid primary key,
 actor_id uuid not null references public.perfiles(id),
 operation text not null,
 payload jsonb not null,
 result jsonb,
 created_at timestamptz not null default now()
);
alter table public.kombax_profile_team_requests_r120 enable row level security;
revoke all on public.kombax_profile_team_requests_r120 from public,anon,authenticated;

create or replace function public.app_kombax_profile_team_inbox_r120()
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_email text;v_out jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 select lower(btrim(u.email)) into v_email from auth.users u
 where u.id=auth.uid() and u.email_confirmed_at is not null and u.deleted_at is null;
 if v_email is null then raise exception 'KOMBAX_CONFIRMED_EMAIL_REQUIRED';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'profile_id',i.profile_id,
   'profile_name',d.nombre_publico,'profile_type',d.tipo,'role',i.role,
   'created_at',i.created_at,'expires_at',i.expires_at) order by i.created_at desc),'[]'::jsonb)
 into v_out from public.kombax_profile_team_invites_r120 i
 join public.perfiles_kombax_directos d on d.id=i.profile_id
 where i.email=v_email and i.status='pending' and i.expires_at>now() and d.estado='activo';
 return v_out;
end $$;

create or replace function public.app_kombax_profile_team_workspace_r120(p_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_invites jsonb;v_managers jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'admin') then raise exception 'KOMBAX_PROFILE_ADMIN_REQUIRED';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'email',i.email,'role',i.role,
 'status',case when i.status='pending' and i.expires_at<=now() then 'expired' else i.status end,
 'accepted_by',i.accepted_by,'created_at',i.created_at,'expires_at',i.expires_at) order by i.created_at desc),'[]'::jsonb)
 into v_invites from public.kombax_profile_team_invites_r120 i where i.profile_id=p_profile_id;
 select coalesce(jsonb_agg(to_jsonb(m)),'[]'::jsonb) into v_managers
 from public.app_kombax_profile_managers_v070(p_profile_id) m;
 return jsonb_build_object('profile_id',p_profile_id,'invites',v_invites,'managers',v_managers);
end $$;

create or replace function public.app_kombax_profile_team_mutate_r120(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_email text;v_profile uuid;v_role text;v_invite uuid;
 v_i public.kombax_profile_team_invites_r120;v_d public.perfiles_kombax_directos;
 v_req public.kombax_profile_team_requests_r120;v_result jsonb;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
 if p_payload is null or jsonb_typeof(p_payload)<>'object' then raise exception 'MUTATION_PAYLOAD_REQUIRED';end if;
 if p_operation not in ('team.invite','team.accept','team.decline','team.revoke') then raise exception 'KOMBAX_TEAM_OPERATION_INVALID';end if;
 select lower(btrim(u.email)) into v_email from auth.users u where u.id=v_uid
   and u.email_confirmed_at is not null and u.deleted_at is null;
 if v_email is null then raise exception 'KOMBAX_CONFIRMED_EMAIL_REQUIRED';end if;
 -- Serialize retries, including concurrent requests with the same key.
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,120));
 select * into v_req from public.kombax_profile_team_requests_r120 where request_id=p_request_id;
 if found then
   if v_req.actor_id<>v_uid or v_req.operation<>p_operation or v_req.payload<>p_payload then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
   return v_req.result;
 end if;
 if p_operation='team.invite' then
   v_profile:=public.app_kombax_uuid_or_null_v070(p_payload->>'profile_id');
   if v_profile is null then raise exception 'KOMBAX_PROFILE_ID_INVALID';end if;
   if not public.app_kombax_puede_gestionar_perfil_v070(v_profile,'admin') then raise exception 'KOMBAX_PROFILE_ADMIN_REQUIRED';end if;
   select * into v_d from public.perfiles_kombax_directos where id=v_profile for update;
   if v_d.id is null or v_d.estado<>'activo' then raise exception 'KOMBAX_PROFILE_NOT_ACTIVE';end if;
   if v_d.tipo not in ('marca','federacion','profesional','competidor','media') then raise exception 'KOMBAX_TEAM_USE_EXISTING_MEMBERSHIP_FLOW';end if;
   if not exists(select 1 from public.kombax_account_private_r117 a where a.perfil_id=v_d.perfil_id
     and a.fecha_nacimiento<=current_date-interval '18 years') then raise exception 'KOMBAX_ADULT_PROFILE_OWNER_REQUIRED';end if;
   v_role:=lower(btrim(coalesce(p_payload->>'role','editor')));
   if v_role not in ('admin','editor','comunicacion') then raise exception 'KOMBAX_MANAGER_ROLE_INVALID';end if;
   v_email:=lower(btrim(p_payload->>'email'));
   if v_email is null or length(v_email)>254 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'KOMBAX_TEAM_EMAIL_INVALID';end if;
   if exists(select 1 from auth.users u where u.id=v_d.perfil_id and lower(btrim(u.email))=v_email) then raise exception 'KOMBAX_OWNER_ROLE_IMMUTABLE';end if;
   if exists(select 1 from public.kombax_profile_team_invites_r120 i where i.profile_id=v_profile and i.email=v_email and i.status='pending' and i.expires_at>now()) then raise exception 'KOMBAX_TEAM_INVITE_PENDING';end if;
   insert into public.kombax_profile_team_invites_r120(profile_id,email,role,invited_by)
   values(v_profile,v_email,v_role,v_uid) returning * into v_i;
 else
   v_invite:=public.app_kombax_uuid_or_null_v070(p_payload->>'invite_id');
   select * into v_i from public.kombax_profile_team_invites_r120 where id=v_invite for update;
   if v_i.id is null then raise exception 'KOMBAX_TEAM_INVITE_UNAVAILABLE';end if;
   v_profile:=v_i.profile_id;
   if p_operation='team.revoke' then
     if not public.app_kombax_puede_gestionar_perfil_v070(v_profile,'admin') then raise exception 'KOMBAX_PROFILE_ADMIN_REQUIRED';end if;
     if v_i.status='accepted' then
       perform public.app_kombax_profile_manager_mutate_v070('kombax.profile.manager.remove',
       jsonb_build_object('perfil_directo_id',v_profile,'perfil_id',v_i.accepted_by),p_request_id);
     end if;
     update public.kombax_profile_team_invites_r120 set status='revoked',updated_at=now() where id=v_i.id;
   else
     if v_i.email<>v_email then raise exception 'KOMBAX_TEAM_INVITE_UNAVAILABLE';end if;
     if v_i.status<>'pending' or v_i.expires_at<=now() then raise exception 'KOMBAX_TEAM_INVITE_UNAVAILABLE';end if;
     if p_operation='team.accept' then
       select * into v_d from public.perfiles_kombax_directos where id=v_profile for update;
       if v_d.estado<>'activo' or v_d.id is null then raise exception 'KOMBAX_PROFILE_NOT_ACTIVE';end if;
       -- An invitation does not survive revocation of its sender's authority.
       if v_i.invited_by<>v_d.perfil_id and not exists(select 1 from public.kombax_perfil_gestores g
         where g.perfil_directo_id=v_profile and g.perfil_id=v_i.invited_by and g.estado='activo' and g.rol in ('owner','admin')) then raise exception 'KOMBAX_TEAM_INVITER_NO_LONGER_AUTHORIZED';end if;
       if not exists(select 1 from public.kombax_account_private_r117 a where a.perfil_id=v_uid
         and a.fecha_nacimiento<=current_date-interval '18 years') then raise exception 'KOMBAX_ADULT_TEAM_MEMBER_REQUIRED';end if;
       if v_uid=v_d.perfil_id then raise exception 'KOMBAX_OWNER_ROLE_IMMUTABLE';end if;
       if exists(select 1 from public.kombax_perfil_gestores g where g.perfil_directo_id=v_profile and g.perfil_id=v_uid and g.estado='activo') then raise exception 'KOMBAX_TEAM_ALREADY_ACTIVE';end if;
       insert into public.kombax_perfil_gestores(perfil_directo_id,perfil_id,rol,estado,concedido_por)
       values(v_profile,v_uid,v_i.role,'activo',v_i.invited_by)
       on conflict(perfil_directo_id,perfil_id) do update set rol=excluded.rol,estado='activo',concedido_por=excluded.concedido_por,actualizado_en=now();
       update public.kombax_profile_team_invites_r120 set status='accepted',accepted_by=v_uid,updated_at=now() where id=v_i.id;
     else update public.kombax_profile_team_invites_r120 set status='declined',updated_at=now() where id=v_i.id;
     end if;
   end if;
 end if;
 insert into public.kombax_verificacion_eventos(perfil_directo_id,actor_perfil_id,evento,detalle)
 values(v_profile,v_uid,p_operation,jsonb_build_object('invite_id',v_i.id,'role',v_i.role));
 select jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,
 'data',jsonb_build_object('invite_id',i.id,'profile_id',i.profile_id,'role',i.role,'status',i.status))
 into v_result from public.kombax_profile_team_invites_r120 i where i.id=v_i.id;
 insert into public.kombax_profile_team_requests_r120(request_id,actor_id,operation,payload,result)
 values(p_request_id,v_uid,p_operation,p_payload,v_result);
 return v_result;
end $$;
revoke all on function public.app_kombax_profile_team_inbox_r120() from public,anon;
revoke all on function public.app_kombax_profile_team_workspace_r120(uuid) from public,anon;
revoke all on function public.app_kombax_profile_team_mutate_r120(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_profile_team_inbox_r120() to authenticated;
grant execute on function public.app_kombax_profile_team_workspace_r120(uuid) to authenticated;
grant execute on function public.app_kombax_profile_team_mutate_r120(text,jsonb,uuid) to authenticated;
commit;
