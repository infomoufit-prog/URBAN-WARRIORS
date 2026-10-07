-- Local reviewed migration. Do not apply without deployment authorization.
begin;
create schema kombax_meta;
revoke all on schema kombax_meta from public,anon,authenticated;

create table kombax_meta.connections(
 id uuid primary key default gen_random_uuid(),social_id uuid not null unique references public.kombax_social_perfiles(id),
 page_id text not null,instagram_id text not null unique,username text not null,
 meta_user_id text not null,status text not null check(status in ('connected','expired','revoked','error','not_connected')),
 permissions jsonb not null default '[]',token_expires_at timestamptz,
 connected_by uuid not null references public.perfiles(id),connected_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),last_verified_at timestamptz
);
create table kombax_meta.credentials(
 connection_id uuid primary key references kombax_meta.connections(id) on delete cascade,
 encrypted_token text not null check(length(encrypted_token)<24000)
);
create table kombax_meta.flows(
 id uuid primary key default gen_random_uuid(),actor_id uuid not null references public.perfiles(id),
 social_id uuid not null references public.kombax_social_perfiles(id),state_hash text not null unique,proof_hash text not null,
 handoff_hash text unique,encrypted_code text,candidates_encrypted text,meta_user_id text,
 stage text not null check(stage in ('started','returned','exchanging','select','done','failed')),
 created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '10 minutes'
);
create index meta_flows_actor_created on kombax_meta.flows(actor_id,created_at);
create table kombax_meta.publications(
 id uuid primary key default gen_random_uuid(),connection_id uuid not null references kombax_meta.connections(id),
 social_id uuid not null references public.kombax_social_perfiles(id),post_id uuid not null,
 actor_id uuid not null references public.perfiles(id),status text not null check(status in ('creating','processing','publishing','published','failed','uncertain')),
 container_id text,media_id text,error_code text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(connection_id,post_id)
);
create table kombax_meta.audit(
 id bigint generated always as identity primary key,event text not null,actor_id uuid,social_id uuid,object_id uuid,
 created_at timestamptz not null default now()
);
create table kombax_meta.deletions(
 confirmation_code text primary key,created_at timestamptz not null default now()
);
alter table kombax_meta.connections enable row level security;
alter table kombax_meta.credentials enable row level security;
alter table kombax_meta.flows enable row level security;
alter table kombax_meta.publications enable row level security;
alter table kombax_meta.audit enable row level security;
alter table kombax_meta.deletions enable row level security;
revoke all on all tables in schema kombax_meta from public,anon,authenticated;
revoke all on all sequences in schema kombax_meta from public,anon,authenticated;

-- Explicit actor predicates, called only from validated JWT/server-side operations.
-- No user_metadata or support impersonation grants for external credentials.
create function kombax_meta.can_manage(p_actor uuid,p_social uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select p_actor is not null and exists(select 1 from public.kombax_social_perfiles sp
 where sp.id=p_social and sp.estado='activo' and (
  (sp.sujeto_tipo='club' and exists(select 1 from public.miembros_club mc
   where mc.club_id=sp.club_id and mc.perfil_id=p_actor and mc.activo and mc.rol='direccion'))
  or (sp.sujeto_tipo='perfil_directo' and exists(select 1 from public.perfiles_kombax_directos d
   where d.id=sp.perfil_directo_id and d.estado='activo' and d.tipo<>'espectador' and
   (d.perfil_id=p_actor or exists(select 1 from public.kombax_perfil_gestores g
    where g.perfil_directo_id=d.id and g.perfil_id=p_actor and g.estado='activo' and g.rol in ('owner','admin')))))
 ));
$$;
revoke all on function kombax_meta.can_manage(uuid,uuid) from public,anon,authenticated;

create function public.app_kombax_meta_context_fix20(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not kombax_meta.can_manage(auth.uid(),p_social_id) then
  raise exception 'META_IDENTITY_ADMIN_REQUIRED' using errcode='42501';end if;
 if coalesce((public.app_kombax_platform_legal_status_v129()->>'required')::boolean,true) then
  raise exception 'META_LEGAL_ACCEPTANCE_REQUIRED' using errcode='42501';end if;
 return jsonb_build_object('social_id',p_social_id,'can_manage',true,
  'can_publish',public.app_kombax_social_puede_actuar_v051(p_social_id));
end $$;
revoke all on function public.app_kombax_meta_context_fix20(uuid) from public,anon;
grant execute on function public.app_kombax_meta_context_fix20(uuid) to authenticated;

-- Single service-role API. No browser can invoke it, including for another tenant.
create function public.app_kombax_meta_internal_fix20(p_action text,p_actor uuid default null,p_id uuid default null,p_data jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare f kombax_meta.flows%rowtype;c kombax_meta.connections%rowtype;j kombax_meta.publications%rowtype;
 v_id uuid;v_social uuid;v_source jsonb;v_event text;
begin
 if p_action='begin' then
  if not kombax_meta.can_manage(p_actor,p_id) then raise exception 'META_IDENTITY_ADMIN_REQUIRED';end if;
  -- Expired OAuth payloads are scrubbed on activity; no permanent authorization-code archive.
  update kombax_meta.flows set encrypted_code=null,candidates_encrypted=null,stage='failed'
   where expires_at<now() and stage not in ('done','failed');
  delete from kombax_meta.flows where created_at<now()-interval '1 day';
  if (select count(*) from kombax_meta.flows where actor_id=p_actor and created_at>now()-interval '10 minutes')>=10 then raise exception 'META_RATE_LIMIT';end if;
  if length(p_data->>'state_hash')<>64 or length(p_data->>'proof_hash')<>64 then raise exception 'META_STATE_INVALID';end if;
  insert into kombax_meta.flows(actor_id,social_id,state_hash,proof_hash,stage)
   values(p_actor,p_id,p_data->>'state_hash',p_data->>'proof_hash','started') returning * into f;
  insert into kombax_meta.audit(event,actor_id,social_id,object_id) values('meta_auth_started',p_actor,p_id,f.id);
  return jsonb_build_object('id',f.id);
 elsif p_action='callback' then
  select * into f from kombax_meta.flows where state_hash=p_data->>'state_hash' for update;
  if f.id is null or f.stage<>'started' or f.expires_at<=now() or not kombax_meta.can_manage(f.actor_id,f.social_id) then raise exception 'META_STATE_INVALID';end if;
  update kombax_meta.flows set stage=case when p_data->>'encrypted_code' is null then 'failed' else 'returned' end,
   encrypted_code=p_data->>'encrypted_code',handoff_hash=p_data->>'handoff_hash' where id=f.id;
  insert into kombax_meta.audit(event,actor_id,social_id,object_id) values('meta_auth_callback',f.actor_id,f.social_id,f.id);
  return jsonb_build_object('id',f.id);
 elsif p_action='finish' then
  select * into f from kombax_meta.flows where id=p_id for update;
  if f.id is null or f.actor_id is distinct from p_actor or f.stage<>'returned' or f.expires_at<=now()
   or f.proof_hash is distinct from p_data->>'proof_hash' or f.handoff_hash is distinct from p_data->>'handoff_hash'
   or not kombax_meta.can_manage(p_actor,f.social_id) then raise exception 'META_STATE_INVALID';end if;
  update kombax_meta.flows set stage='exchanging',encrypted_code=null,handoff_hash=null where id=f.id;
  return jsonb_build_object('social_id',f.social_id,'encrypted_code',f.encrypted_code);
 elsif p_action='candidates' then
  select * into f from kombax_meta.flows where id=p_id for update;
  if f.actor_id is distinct from p_actor or f.stage<>'exchanging' or f.expires_at<=now() or not kombax_meta.can_manage(p_actor,f.social_id) then raise exception 'META_STATE_INVALID';end if;
  update kombax_meta.flows set stage='select',candidates_encrypted=p_data->>'encrypted',meta_user_id=p_data->>'meta_user_id' where id=f.id;
  return jsonb_build_object('ok',true);
 elsif p_action in ('select','attach') then
  select * into f from kombax_meta.flows where id=p_id for update;
  if f.id is null or f.actor_id is distinct from p_actor or f.stage<>'select' or f.expires_at<=now() or not kombax_meta.can_manage(p_actor,f.social_id) then raise exception 'META_STATE_INVALID';end if;
  if p_action='select' then return jsonb_build_object('social_id',f.social_id,'encrypted',f.candidates_encrypted);end if;
  -- Prevent replacing a connection while an external publication is in progress.
  perform pg_advisory_xact_lock(hashtextextended(f.social_id::text,20));
  if exists(select 1 from kombax_meta.publications where social_id=f.social_id and status in ('creating','processing','publishing','uncertain')) then raise exception 'META_PUBLICATION_REVIEW_REQUIRED';end if;
  insert into kombax_meta.connections(social_id,page_id,instagram_id,username,meta_user_id,status,permissions,token_expires_at,connected_by,last_verified_at)
   values(f.social_id,p_data->>'page_id',p_data->>'instagram_id',p_data->>'username',p_data->>'meta_user_id','connected',p_data->'permissions',nullif(p_data->>'expires_at','')::timestamptz,p_actor,now())
   on conflict(social_id) do update set page_id=excluded.page_id,instagram_id=excluded.instagram_id,username=excluded.username,
    meta_user_id=excluded.meta_user_id,status='connected',permissions=excluded.permissions,token_expires_at=excluded.token_expires_at,
    connected_by=excluded.connected_by,connected_at=now(),updated_at=now(),last_verified_at=now() returning * into c;
  insert into kombax_meta.credentials values(c.id,p_data->>'encrypted_token') on conflict(connection_id) do update set encrypted_token=excluded.encrypted_token;
  update kombax_meta.flows set stage='done',candidates_encrypted=null where id=f.id;
  insert into kombax_meta.audit(event,actor_id,social_id,object_id) values('meta_account_connected',p_actor,f.social_id,c.id);
  return jsonb_build_object('ok',true);
 elsif p_action in ('status','credential','disconnect','connection_state','claim') then
  if not kombax_meta.can_manage(p_actor,p_id) then raise exception 'META_IDENTITY_ADMIN_REQUIRED';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id::text,20));
  select * into c from kombax_meta.connections where social_id=p_id for update;
  if p_action='status' then
   return jsonb_build_object('status',case when c.id is null then 'not_connected' when c.status='connected' and c.token_expires_at<=now() then 'expired' else c.status end,
    'username',c.username,'connection_id',c.id,'last_verified_at',c.last_verified_at,
    'publications',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'post_id',q.post_id,'status',q.status,'media_id',q.media_id,'updated_at',q.updated_at)) from
     (select * from kombax_meta.publications where social_id=p_id order by created_at desc limit 10) q),'[]'::jsonb));
  end if;
  if c.id is null then raise exception 'META_NOT_CONNECTED';end if;
  if p_action='disconnect' then
   delete from kombax_meta.credentials where connection_id=c.id;
   update kombax_meta.connections set status='not_connected',updated_at=now(),permissions='[]' where id=c.id;
   update kombax_meta.flows set stage='failed',encrypted_code=null,candidates_encrypted=null where social_id=p_id and stage<>'done';
   insert into kombax_meta.audit(event,actor_id,social_id,object_id) values('meta_account_disconnected',p_actor,p_id,c.id);
   return jsonb_build_object('ok',true);
  elsif p_action='connection_state' then
   if p_data->>'status' not in ('connected','expired','revoked','error') then raise exception 'META_STATUS_INVALID';end if;
   update kombax_meta.connections set status=p_data->>'status',last_verified_at=now(),updated_at=now() where id=c.id;
   if p_data->>'status' in ('expired','revoked') then delete from kombax_meta.credentials where connection_id=c.id;end if;
   return jsonb_build_object('ok',true);
  end if;
  if c.status<>'connected' or c.token_expires_at<=now() then raise exception 'META_RECONNECT_REQUIRED';end if;
  if p_action='credential' then
   return to_jsonb(c)||jsonb_build_object('encrypted_token',(select encrypted_token from kombax_meta.credentials where connection_id=c.id));
  end if;
  v_source:=public.app_kombax_meta_source_internal_fix20(p_id,(p_data->>'post_id')::uuid);
  insert into kombax_meta.publications(connection_id,social_id,post_id,actor_id,status)
   values(c.id,p_id,(p_data->>'post_id')::uuid,p_actor,'creating') on conflict(connection_id,post_id) do nothing returning * into j;
  if j.id is null then select * into j from kombax_meta.publications where connection_id=c.id and post_id=(p_data->>'post_id')::uuid;
   return jsonb_build_object('existing',true,'job',to_jsonb(j));end if;
  insert into kombax_meta.audit(event,actor_id,social_id,object_id) values('meta_publish_started',p_actor,p_id,j.id);
  return jsonb_build_object('existing',false,'job',to_jsonb(j),'source',v_source);
 elsif p_action in ('job','job_update') then
  select * into j from kombax_meta.publications where id=p_id for update;
  if j.id is null or not kombax_meta.can_manage(p_actor,j.social_id) then raise exception 'META_IDENTITY_ADMIN_REQUIRED';end if;
  if p_action='job' then return to_jsonb(j);end if;
  if p_data->>'status' not in ('processing','publishing','published','failed','uncertain') then raise exception 'META_STATUS_INVALID';end if;
  if j.status='published' then return to_jsonb(j);end if;
  if p_data->>'status'='publishing' then
   if j.status<>'processing' then return jsonb_build_object('busy',true);end if;
   perform public.app_kombax_meta_source_internal_fix20(j.social_id,j.post_id);
  end if;
  update kombax_meta.publications set status=p_data->>'status',container_id=coalesce(p_data->>'container_id',container_id),
   media_id=coalesce(p_data->>'media_id',media_id),error_code=p_data->>'error_code',updated_at=now() where id=j.id returning * into j;
  if j.status in ('published','failed','uncertain') then
   insert into kombax_meta.audit(event,actor_id,social_id,object_id) values(case when j.status='published' then 'meta_publish_success' else 'meta_publish_failed' end,p_actor,j.social_id,j.id);end if;
  return to_jsonb(j);
 elsif p_action in ('deauthorize','delete_data') then
  if coalesce(p_data->>'meta_user_id','')!~'^[0-9]+$' then raise exception 'META_SIGNED_REQUEST_INVALID';end if;
  delete from kombax_meta.credentials where connection_id in(select id from kombax_meta.connections where meta_user_id=p_data->>'meta_user_id');
  -- Remove pending encrypted authorizations for the same KOMBAX actors as well.
  delete from kombax_meta.flows where meta_user_id=p_data->>'meta_user_id'
   or actor_id in(select connected_by from kombax_meta.connections where meta_user_id=p_data->>'meta_user_id');
  if p_action='delete_data' then
   delete from kombax_meta.audit where social_id in(select social_id from kombax_meta.connections where meta_user_id=p_data->>'meta_user_id');
   delete from kombax_meta.publications where connection_id in(select id from kombax_meta.connections where meta_user_id=p_data->>'meta_user_id');
   delete from kombax_meta.connections where meta_user_id=p_data->>'meta_user_id';
   insert into kombax_meta.deletions(confirmation_code) values(p_data->>'confirmation_code') on conflict do nothing;
  else update kombax_meta.connections set status='revoked',permissions='[]',updated_at=now() where meta_user_id=p_data->>'meta_user_id';end if;
  return jsonb_build_object('ok',true);
 elsif p_action='deletion_status' then
  return jsonb_build_object('completed',exists(select 1 from kombax_meta.deletions where confirmation_code=p_data->>'confirmation_code'));
 end if;
 raise exception 'META_ACTION_INVALID';
end $$;

-- Authoritative data only: no caller-controlled URLs, captions or cross-entity media.
create function public.app_kombax_meta_source_internal_fix20(p_social uuid,p_post uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v jsonb;
begin
 select jsonb_build_object('text',p.texto,'bucket',coalesce(sm.storage_bucket,case when cm.id is not null then 'club-public-media' else 'kombax-public-media' end),
  'path',coalesce(sm.storage_path,cm.storage_path),'mime',coalesce(sm.mime_type,cm.mime_type),
  'width',coalesce(sm.width,cm.width),'height',coalesce(sm.height,cm.height)) into v
 from public.kombax_social_publicaciones p
 join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id and sp.visible and sp.estado='activo' and sp.publicar_habilitado
 left join public.kombax_social_media sm on sm.id=p.social_media_id and sm.social_profile_id=p_social and sm.estado='active' and sm.tipo='photo' and sm.bytes<=8388608
 left join public.kombax_club_media cm on cm.id=p.media_id and cm.club_id=sp.club_id and cm.estado='active' and cm.tipo='photo' and cm.bytes<=8388608
 where p.id=p_post and p.autor_perfil_id=p_social and p.estado='activa' and p.audiencia='publica'
 and (p.social_media_id is null or sm.id is not null)
 and not exists(select 1 from kombax_moderation.content_state ms where ms.channel='social' and ms.content_id=p.id and ms.state in ('hidden','deleted'));
 if v is null or v->>'path' is null or v->>'mime'<>'image/jpeg' or v->>'bucket' not in ('kombax-public-media','club-public-media') then raise exception 'META_PUBLIC_JPEG_REQUIRED';end if;
 if coalesce((v->>'width')::numeric,0)<=0 or coalesce((v->>'height')::numeric,0)<=0
  or (v->>'width')::numeric/(v->>'height')::numeric not between 0.8 and 1.91 then raise exception 'META_IMAGE_DIMENSIONS_INVALID';end if;
 return v;
end $$;
revoke all on function public.app_kombax_meta_source_internal_fix20(uuid,uuid) from public,anon,authenticated;
revoke all on function public.app_kombax_meta_internal_fix20(text,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.app_kombax_meta_internal_fix20(text,uuid,uuid,jsonb) to service_role;
-- Deliberately no direct grants or policies for credentials, flows or API callers.
commit;
