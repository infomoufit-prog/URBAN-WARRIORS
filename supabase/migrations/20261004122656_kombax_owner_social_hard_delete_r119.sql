begin;
CREATE OR REPLACE FUNCTION kombax_moderation.action_before_purge_r119(p_channel text, p_id uuid, p_action text, p_reason text, p_patch jsonb DEFAULT '{}'::jsonb, p_confirmation text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_before jsonb;v_after jsonb;v_author uuid;v_state text;v_lock kombax_moderation.content_state;
begin
 if auth.uid() is null or not coalesce(public.app_kombax_es_moderador_v041(),false) then raise exception 'MODERATOR_REQUIRED';end if;
 if p_action is null or p_action not in ('edit','hide','restore','delete','warn') or p_channel is null or p_channel not in ('social','showcase') then raise exception 'INVALID_ACTION';end if;
 if length(btrim(coalesce(p_reason,''))) not between 10 and 1000 then raise exception 'REASON_REQUIRED';end if;
 if p_action='edit' and (length(btrim(coalesce(p_patch->>'text',''))) not between 1 and 10000 or (p_channel='social' and length(p_patch->>'text')>1500) or (p_channel='showcase' and length(btrim(coalesce(p_patch->>'title',''))) not between 1 and 160)) then raise exception 'INVALID_EDIT';end if;
 if p_action='delete' then
  if not coalesce(public.app_kombax_es_platform_admin_v055(),false) then raise exception 'Necesitas una sesión Owner válida para eliminar. Vuelve a entrar en administración Owner.';end if;
  if coalesce(p_confirmation,'')<>'ELIMINAR' then raise exception 'Escribe ELIMINAR para confirmar la retirada definitiva.';end if;
 end if;
 if p_channel='social' then
  select to_jsonb(p),p.estado into v_before,v_state from public.kombax_social_publicaciones p where p.id=p_id for update;
  select coalesce(d.perfil_id,i.perfil_id) into v_author from public.kombax_social_perfiles s left join public.perfiles_kombax_directos d on d.id=s.perfil_directo_id left join public.identidades_sociales i on i.id=s.identidad_social_id where s.id=(v_before->>'autor_perfil_id')::uuid;
 else select to_jsonb(e),e.estado,e.creado_por into v_before,v_state,v_author from public.kombax_showcase_elementos e where e.id=p_id for update;end if;
 if v_before is null then raise exception 'CONTENT_NOT_FOUND';end if;
 select * into v_lock from kombax_moderation.content_state where channel=p_channel and content_id=p_id;
 if v_lock.state='deleted' then raise exception 'CONTENT_ALREADY_DELETED';end if;
 if p_action in ('hide','delete') then
  insert into kombax_moderation.content_state(channel,content_id,state,reason,previous_state,previous_commerce)
  values(p_channel,p_id,case when p_action='delete' then 'deleted' else 'hidden' end,p_reason,v_state,(v_before->>'commerce_enabled')::boolean)
  on conflict(channel,content_id) do update set state=excluded.state,reason=excluded.reason;
 elsif p_action='restore' then
  if v_lock.content_id is null then raise exception 'CONTENT_NOT_WITHDRAWN';end if;
  if kombax_moderation.prohibited_offer(p_channel,case when p_channel='social' then v_before->>'texto' else (v_before->>'nombre')||' '||coalesce(v_before->>'resumen','')||' '||coalesce(v_before->>'descripcion','') end) then raise exception 'PROHIBITED_OFFER_CORRECT_BEFORE_RESTORE';end if;
  delete from kombax_moderation.content_state where channel=p_channel and content_id=p_id;
 end if;
 if p_channel='social' then
  update public.kombax_social_publicaciones set
   texto=case when p_action='edit' then p_patch->>'text' else texto end,
   estado=case when p_action='delete' then 'retirada' when p_action='hide' then 'oculta' when p_action='restore' then v_lock.previous_state else estado end,
   moderada_por=auth.uid(),moderacion_motivo=p_reason,actualizado_en=now() where id=p_id returning to_jsonb(kombax_social_publicaciones.*) into v_after;
 else
  update public.kombax_showcase_elementos set
   nombre=case when p_action='edit' then coalesce(p_patch->>'title',nombre) else nombre end,
   descripcion=case when p_action='edit' then p_patch->>'text' else descripcion end,
   resumen=case when p_action='edit' then coalesce(p_patch->>'summary',resumen) else resumen end,
   estado=case when p_action='delete' then 'archivado' when p_action='hide' then 'oculto' when p_action='restore' then v_lock.previous_state else estado end,
   commerce_enabled=case when p_action in ('hide','delete') then false when p_action='restore' then coalesce(v_lock.previous_commerce,false) else commerce_enabled end,
   actualizado_por=auth.uid(),actualizado_en=now() where id=p_id returning to_jsonb(kombax_showcase_elementos.*) into v_after;
 end if;
 insert into kombax_moderation.history(channel,content_id,actor_id,action,reason,before_data,after_data) values(p_channel,p_id,auth.uid(),p_action,p_reason,kombax_moderation.snapshot(v_before),kombax_moderation.snapshot(v_after));
 perform kombax_moderation.notify(p_channel,p_id,p_action,p_reason,v_author);
 return jsonb_build_object('ok',true,'state',v_after->>'estado');
end $function$;
create table kombax_moderation.media_cleanup (
 id uuid primary key default gen_random_uuid(), bucket text not null, path text not null,
 state text not null default 'pending' check(state in ('pending','processing','completed','preserved','failed')),
 attempts integer not null default 0, claim_token uuid, updated_at timestamptz not null default now(),
 unique(bucket,path), check(bucket in ('kombax-public-media','kombax-restricted-media'))
);
alter table kombax_moderation.media_cleanup enable row level security;
revoke all on kombax_moderation.media_cleanup from public,anon,authenticated;

-- Conservative check: preserve files referenced by another profile, album, product or legal record.
create function kombax_moderation.path_referenced_r119(p_path text) returns boolean
language plpgsql security definer set search_path='' as $$
declare c record; found_ref boolean;
begin
 if nullif(p_path,'') is null then return true;end if;
 for c in select n.nspname,t.relname,a.attname from pg_catalog.pg_attribute a
 join pg_catalog.pg_class t on t.oid=a.attrelid join pg_catalog.pg_namespace n on n.oid=t.relnamespace
 where n.nspname in ('public','kombax_compliance','kombax_payments','kombax_reputation')
 and t.relkind in ('r','p') and a.attnum>0 and not a.attisdropped
 and (a.attname in ('storage_path','media_presentation','avatar_path','banner_path','imagen_url','galeria','cartel_url','banner_url','logo_url','imagen_presentacion','galeria_presentacion','regulatory_documents')
 or a.attname ~ '(image|photo|logo|attachment|evidence|document|snapshot|media|cover)')
 loop
 execute format('select exists(select 1 from %I.%I where strpos(coalesce(%I::text, ''''),$1)>0)',c.nspname,c.relname,c.attname) into found_ref using p_path;
 if found_ref then return true;end if;
 end loop;return false;
end $$;

create function kombax_moderation.queue_media_r119(p_bucket text,p_path text,p_owner uuid,p_area text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if p_bucket is null or p_bucket not in ('kombax-public-media','kombax-restricted-media') or p_owner is null or
 p_path is null or p_path not like p_owner::text||'/'||p_area||'/%' or
 (p_path like '%..%' or p_path !~ '^[0-9a-f-]+/(social|showcase)/[A-Za-z0-9_./-]+$') or kombax_moderation.path_referenced_r119(p_path) then return;end if;
 insert into kombax_moderation.media_cleanup(bucket,path) values(p_bucket,p_path)
 on conflict(bucket,path) do update set state='pending',attempts=0,claim_token=null,updated_at=now()
 where kombax_moderation.media_cleanup.state in ('preserved','failed');
end $$;

create or replace function public.app_kombax_content_action_r118(p_channel text,p_id uuid,p_action text,p_reason text,p_patch jsonb default '{}',p_confirmation text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare before_row jsonb; result jsonb; media_row jsonb; ref record; has_ref boolean; retained boolean:=false; image text; path text; gallery jsonb;
begin
 if p_action is distinct from 'delete' then return kombax_moderation.action_before_purge_r119(p_channel,p_id,p_action,p_reason,p_patch,p_confirmation);end if;
 if auth.uid() is null or not coalesce(public.app_kombax_es_platform_admin_v055(),false) then raise exception 'Tu sesión Owner no permite eliminar. Vuelve a entrar en administración Owner.';end if;
 if p_channel is null or p_channel not in ('social','showcase') then raise exception 'INVALID_ACTION';end if;
 if p_confirmation is distinct from 'ELIMINAR' then raise exception 'Introduce ELIMINAR para confirmar la eliminación definitiva.';end if;
 if length(btrim(coalesce(p_reason,''))) not between 10 and 1000 then raise exception 'REASON_REQUIRED';end if;
 if p_channel='social' then select to_jsonb(p) into before_row from public.kombax_social_publicaciones p where id=p_id for update;
 else select to_jsonb(p) into before_row from public.kombax_showcase_elementos p where id=p_id for update;end if;
 if before_row is null then
  if exists(select 1 from kombax_moderation.content_state where channel=p_channel and content_id=p_id and state='deleted') then return jsonb_build_object('ok',true,'permanently_deleted',true,'already_deleted',true);end if;
  raise exception 'CONTENT_NOT_FOUND';
 end if;
 if not exists(select 1 from kombax_moderation.content_state where channel=p_channel and content_id=p_id and state='deleted') then
  result:=kombax_moderation.action_before_purge_r119(p_channel,p_id,p_action,p_reason,p_patch,p_confirmation);
 else result:=jsonb_build_object('ok',true);end if;
 if p_channel='social' then
  delete from public.kombax_social_publicaciones where id=p_id;
  select to_jsonb(m) into media_row from public.kombax_social_media m where id=(before_row->>'social_media_id')::uuid for update;
  if media_row is not null and not coalesce((media_row->>'en_album')::boolean,false)
   and not exists(select 1 from public.kombax_social_publicaciones where social_media_id=(media_row->>'id')::uuid) then
   delete from public.kombax_social_media where id=(media_row->>'id')::uuid;
   perform kombax_moderation.queue_media_r119(media_row->>'storage_bucket',media_row->>'storage_path',(media_row->>'creado_por')::uuid,'social');
   perform kombax_moderation.queue_media_r119(coalesce(media_row->'media_presentation'->>'cover_storage_bucket',media_row->>'storage_bucket'),media_row->'media_presentation'->>'cover_storage_path',(media_row->>'creado_por')::uuid,'social');
  end if;
 else
  -- Every restrictive FK matters, including orders, reviews, stock and safety reports.
  for ref in select n.nspname,t.relname,a.attname from pg_catalog.pg_constraint fk
   join pg_catalog.pg_class t on t.oid=fk.conrelid join pg_catalog.pg_namespace n on n.oid=t.relnamespace
   join pg_catalog.pg_attribute a on a.attrelid=t.oid and a.attnum=fk.conkey[1]
   where fk.contype='f' and fk.confrelid='public.kombax_showcase_elementos'::regclass and fk.confdeltype in ('r','a')
  loop
   execute format('select exists(select 1 from %I.%I where %I=$1)',ref.nspname,ref.relname,ref.attname) into has_ref using p_id;
   retained:=retained or has_ref;
  end loop;
  if retained then update public.kombax_showcase_elementos set resumen=null,descripcion=null,imagen_url=null,galeria='[]',estado='archivado',commerce_enabled=false where id=p_id;
   if exists(select 1 from pg_catalog.pg_attribute where attrelid='public.kombax_showcase_elementos'::regclass and attname='imagen_presentacion' and not attisdropped) then
    execute 'update public.kombax_showcase_elementos set imagen_presentacion=''{}'',galeria_presentacion=''{}'' where id=$1' using p_id;
   end if;
  else delete from public.kombax_showcase_elementos where id=p_id;end if;
  gallery:=coalesce(before_row->'galeria','[]');
  if jsonb_typeof(gallery)<>'array' then gallery:='[]';end if;
  for image in select v from (select before_row->>'imagen_url' v union all select case when jsonb_typeof(value)='string' then value#>>'{}' else coalesce(value->>'url',value->>'src') end from jsonb_array_elements(gallery)) urls
  loop
   -- Only owned files on this project's storage; never delete an external image.
   if image ~ '^https://poggsobhtutbuagjiydc\.supabase\.co/storage/v1/object/public/kombax-public-media/' then
    path:=split_part(image,'/storage/v1/object/public/kombax-public-media/',2);
    perform kombax_moderation.queue_media_r119('kombax-public-media',path,(before_row->>'creado_por')::uuid,'showcase');
   end if;
  end loop;
 end if;
 -- Keep the intervention audit, without keeping copies of deleted content and media.
 update kombax_moderation.history set before_data=before_data-'texto'-'descripcion'-'resumen'-'imagen_url'-'galeria',
 after_data=after_data-'texto'-'descripcion'-'resumen'-'imagen_url'-'galeria' where channel=p_channel and content_id=p_id;
 return coalesce(result,'{}')||jsonb_build_object('permanently_deleted',not retained,'history_retained',retained,'media_cleanup','queued_or_preserved');
end $$;
revoke all on function public.app_kombax_content_action_r118(text,uuid,text,text,jsonb,text) from public,anon;
grant execute on function public.app_kombax_content_action_r118(text,uuid,text,text,jsonb,text) to authenticated;

create function public.app_kombax_cleanup_claim_r119() returns jsonb language plpgsql security definer set search_path='' as $$
declare job kombax_moderation.media_cleanup; jobs jsonb:='[]'; token uuid;
begin
 for job in select * from kombax_moderation.media_cleanup where attempts<10 and
 ((state='pending' and updated_at<=now()) or (state='processing' and updated_at<now()-interval '5 minutes')) order by updated_at limit 20 for update skip locked
 loop
  if kombax_moderation.path_referenced_r119(job.path) then
   update kombax_moderation.media_cleanup set state='preserved',updated_at=now() where id=job.id;continue;
  end if;
  token:=gen_random_uuid();update kombax_moderation.media_cleanup set state='processing',attempts=attempts+1,claim_token=token,updated_at=now() where id=job.id;
  jobs:=jobs||jsonb_build_array(jsonb_build_object('id',job.id,'bucket',job.bucket,'path',job.path,'token',token));
 end loop;return jobs;
end $$;
create function public.app_kombax_cleanup_finish_r119(p_id uuid,p_token uuid,p_ok boolean) returns boolean language plpgsql security definer set search_path='' as $$
begin
 update kombax_moderation.media_cleanup set state=case when p_ok then 'completed' when attempts>=10 then 'failed' else 'pending' end,
 claim_token=null,updated_at=case when p_ok then now() else now()+interval '5 minutes' end
 where id=p_id and claim_token=p_token and state='processing';return found;
end $$;
revoke all on function kombax_moderation.action_before_purge_r119(text,uuid,text,text,jsonb,text),kombax_moderation.path_referenced_r119(text),kombax_moderation.queue_media_r119(text,text,uuid,text) from public,anon,authenticated;
revoke all on function public.app_kombax_cleanup_claim_r119(),public.app_kombax_cleanup_finish_r119(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.app_kombax_cleanup_claim_r119(),public.app_kombax_cleanup_finish_r119(uuid,uuid,boolean) to service_role;
commit;

