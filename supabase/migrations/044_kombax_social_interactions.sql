-- KOMBAX RC13 build 20027 · Social: límites, comentarios/respuestas, guardados y media.
-- Una sola capa de respuesta. Guardados privados. Sin seguidores y sin chat libre.

begin;

alter table public.kombax_social_publicaciones
  add column if not exists comentarios_estado text not null default 'open',
  add column if not exists comentarios_count integer not null default 0,
  add column if not exists guardados_count integer not null default 0,
  add column if not exists media_id uuid references public.kombax_perfil_media(id) on delete set null;
alter table public.kombax_social_publicaciones drop constraint if exists kombax_social_publicaciones_comentarios_estado_check;
alter table public.kombax_social_publicaciones add constraint kombax_social_publicaciones_comentarios_estado_check check(comentarios_estado in ('open','verified_only','closed'));
alter table public.kombax_social_publicaciones drop constraint if exists kombax_social_publicaciones_comentarios_count_check;
alter table public.kombax_social_publicaciones add constraint kombax_social_publicaciones_comentarios_count_check check(comentarios_count>=0 and guardados_count>=0);

create table if not exists public.kombax_social_comentarios(
  id uuid primary key default gen_random_uuid(),
  publicacion_id uuid not null references public.kombax_social_publicaciones(id) on delete cascade,
  autor_social_id uuid not null references public.kombax_social_perfiles(id) on delete restrict,
  parent_id uuid references public.kombax_social_comentarios(id) on delete cascade,
  texto text not null check(char_length(btrim(texto)) between 1 and 800),
  estado text not null default 'active' check(estado in ('active','hidden','removed')),
  moderado_por uuid references public.perfiles(id) on delete set null,
  moderacion_motivo text check(char_length(coalesce(moderacion_motivo,''))<=1000),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
create index if not exists idx_kombax_social_comments_v044 on public.kombax_social_comentarios(publicacion_id,creado_en,id);
create index if not exists idx_kombax_social_comments_parent_v044 on public.kombax_social_comentarios(parent_id,creado_en) where parent_id is not null;

create table if not exists public.kombax_social_guardados(
  publicacion_id uuid not null references public.kombax_social_publicaciones(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  creado_en timestamptz not null default now(),
  primary key(publicacion_id,perfil_id)
);
create index if not exists idx_kombax_social_saved_user_v044 on public.kombax_social_guardados(perfil_id,creado_en desc);

alter table public.kombax_social_comentarios enable row level security;
alter table public.kombax_social_guardados enable row level security;
revoke all on public.kombax_social_comentarios,public.kombax_social_guardados from public,anon,authenticated;

create or replace function public.app_kombax_social_comment_guard_v044()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_parent public.kombax_social_comentarios;
begin
  if new.parent_id is not null then
    select * into v_parent from public.kombax_social_comentarios where id=new.parent_id;
    if v_parent.id is null or v_parent.publicacion_id<>new.publicacion_id then raise exception 'KOMBAX_COMMENT_PARENT_INVALID';end if;
    if v_parent.parent_id is not null then raise exception 'KOMBAX_COMMENT_ONE_REPLY_LEVEL_ONLY';end if;
  end if;
  new.actualizado_en:=now();return new;
end $$;
revoke all on function public.app_kombax_social_comment_guard_v044() from public,anon,authenticated;
drop trigger if exists kombax_social_comment_guard_v044 on public.kombax_social_comentarios;
create trigger kombax_social_comment_guard_v044 before insert or update on public.kombax_social_comentarios for each row execute function public.app_kombax_social_comment_guard_v044();

create or replace function public.trg_kombax_social_comments_count_v044()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' and new.estado='active' then update public.kombax_social_publicaciones set comentarios_count=comentarios_count+1 where id=new.publicacion_id;return new;
  elsif tg_op='DELETE' and old.estado='active' then update public.kombax_social_publicaciones set comentarios_count=greatest(comentarios_count-1,0) where id=old.publicacion_id;return old;
  elsif tg_op='UPDATE' and old.estado is distinct from new.estado then update public.kombax_social_publicaciones set comentarios_count=greatest(comentarios_count+(case when new.estado='active' then 1 else -1 end),0) where id=new.publicacion_id;return new;
  end if;return coalesce(new,old);
end $$;
revoke all on function public.trg_kombax_social_comments_count_v044() from public,anon,authenticated;
drop trigger if exists kombax_social_comments_count_v044 on public.kombax_social_comentarios;
create trigger kombax_social_comments_count_v044 after insert or update of estado or delete on public.kombax_social_comentarios for each row execute function public.trg_kombax_social_comments_count_v044();

create or replace function public.trg_kombax_social_saved_count_v044()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' then update public.kombax_social_publicaciones set guardados_count=guardados_count+1 where id=new.publicacion_id;return new;
  else update public.kombax_social_publicaciones set guardados_count=greatest(guardados_count-1,0) where id=old.publicacion_id;return old;end if;
end $$;
revoke all on function public.trg_kombax_social_saved_count_v044() from public,anon,authenticated;
drop trigger if exists kombax_social_saved_count_v044 on public.kombax_social_guardados;
create trigger kombax_social_saved_count_v044 after insert or delete on public.kombax_social_guardados for each row execute function public.trg_kombax_social_saved_count_v044();

create or replace function public.app_kombax_social_mis_perfiles_v044()
returns table(id uuid,sujeto_tipo text,nombre_publico text,slug text,avatar_url text,verificado boolean,contacto_habilitado boolean,perfil_directo_id uuid,perfil_tipo text)
language sql stable security definer set search_path=public,auth as $$
  select sp.id,sp.sujeto_tipo,sp.nombre_publico,sp.slug,sp.avatar_url,sp.verificado,public.app_kombax_social_contactable_v041(sp.id),sp.perfil_directo_id,
    case when sp.sujeto_tipo='club' then 'club' when sp.sujeto_tipo='miembro' then 'competidor' else coalesce(d.tipo,'profesional') end
  from public.kombax_social_perfiles sp left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  where public.app_kombax_social_puede_publicar_v041(sp.id)
  order by case sp.sujeto_tipo when 'miembro' then 0 when 'club' then 1 else 2 end,sp.nombre_publico;
$$;
revoke all on function public.app_kombax_social_mis_perfiles_v044() from public,anon;
grant execute on function public.app_kombax_social_mis_perfiles_v044() to authenticated;

create or replace function public.app_kombax_social_feed_v044(p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 20)
returns table(id uuid,tipo text,texto text,likes_count integer,comentarios_count integer,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_tipo text,autor_slug text,autor_avatar_url text,autor_verificado boolean,liked_by_me boolean,saved_by_me boolean,contactable boolean,comentarios_estado text,media_id uuid,media_tipo text,media_path text,media_mime text,media_duration numeric)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  return query
  select p.id,p.tipo,p.texto,p.likes_count,p.comentarios_count,p.creado_en,sp.id,sp.nombre_publico,sp.sujeto_tipo,sp.slug,sp.avatar_url,sp.verificado,
    exists(select 1 from public.kombax_social_likes l where l.publicacion_id=p.id and l.perfil_id=auth.uid()),
    exists(select 1 from public.kombax_social_guardados g where g.publicacion_id=p.id and g.perfil_id=auth.uid()),
    public.app_kombax_social_contactable_v041(sp.id),p.comentarios_estado,m.id,m.tipo,m.storage_path,m.mime_type,m.duration_seconds
  from public.kombax_social_publicaciones p join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id left join public.kombax_perfil_media m on m.id=p.media_id and m.estado='active'
  where p.estado='activa' and sp.estado='activo' and sp.visible
    and (p_cursor is null or (p.creado_en,p.id)<(p_cursor,p_cursor_id))
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
  order by p.creado_en desc,p.id desc limit least(greatest(coalesce(p_limit,20),1),20);
end $$;
revoke all on function public.app_kombax_social_feed_v044(timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v044(timestamptz,uuid,integer) to authenticated;

create or replace function public.app_kombax_social_directorio_v044(p_query text default '',p_limit integer default 30)
returns table(id uuid,sujeto_tipo text,perfil_tipo text,slug text,nombre_publico text,bio text,avatar_url text,banner_url text,verificado boolean,contactable boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_q text:=lower(btrim(coalesce(p_query,'')));
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  return query
  select sp.id,sp.sujeto_tipo,
    case when sp.sujeto_tipo='club' then 'club' when sp.sujeto_tipo='miembro' then 'competidor' else coalesce(d.tipo,'profesional') end,
    sp.slug,sp.nombre_publico,sp.bio,sp.avatar_url,sp.banner_url,sp.verificado,public.app_kombax_social_contactable_v041(sp.id)
  from public.kombax_social_perfiles sp
  left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  where sp.visible and sp.estado='activo'
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (v_q='' or lower(sp.nombre_publico) like '%'||v_q||'%' or lower(sp.slug) like '%'||v_q||'%' or lower(coalesce(sp.bio,'')) like '%'||v_q||'%'
      or lower(coalesce(d.tipo,'')) like '%'||v_q||'%' or exists(select 1 from unnest(coalesce(d.disciplinas,'{}'::text[])) x where lower(x) like '%'||v_q||'%'))
  order by sp.verificado desc,sp.nombre_publico limit least(greatest(coalesce(p_limit,30),1),50);
end $$;
revoke all on function public.app_kombax_social_directorio_v044(text,integer) from public,anon;
grant execute on function public.app_kombax_social_directorio_v044(text,integer) to authenticated;

create or replace function public.app_kombax_social_comentarios_v044(p_publicacion_id uuid,p_limit integer default 100)
returns table(id uuid,parent_id uuid,texto text,estado text,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_slug text,autor_avatar_url text,autor_verificado boolean,propio boolean)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  if not exists(select 1 from public.kombax_social_publicaciones where id=p_publicacion_id and estado='activa') then raise exception 'KOMBAX_POST_NOT_AVAILABLE';end if;
  return query select c.id,c.parent_id,c.texto,c.estado,c.creado_en,sp.id,sp.nombre_publico,sp.slug,sp.avatar_url,sp.verificado,public.app_kombax_social_puede_publicar_v041(sp.id)
  from public.kombax_social_comentarios c join public.kombax_social_perfiles sp on sp.id=c.autor_social_id
  where c.publicacion_id=p_publicacion_id and c.estado='active' and sp.estado='activo' and sp.visible
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
  order by coalesce(c.parent_id,c.id),case when c.parent_id is null then 0 else 1 end,c.creado_en,c.id limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_social_comentarios_v044(uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_comentarios_v044(uuid,integer) to authenticated;

create or replace function public.app_kombax_social_guardados_v044(p_limit integer default 100)
returns table(id uuid,tipo text,texto text,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_slug text)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  return query select p.id,p.tipo,p.texto,p.creado_en,sp.id,sp.nombre_publico,sp.slug
  from public.kombax_social_guardados g join public.kombax_social_publicaciones p on p.id=g.publicacion_id join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id
  where g.perfil_id=auth.uid() and p.estado='activa' order by g.creado_en desc limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_social_guardados_v044(integer) from public,anon;
grant execute on function public.app_kombax_social_guardados_v044(integer) to authenticated;

create or replace function public.app_kombax_contact_reason_allowed_v044(p_from uuid,p_to uuid,p_reason text)
returns boolean language plpgsql stable security definer set search_path=public,auth as $$
declare a public.kombax_social_perfiles;b public.kombax_social_perfiles;at text;bt text;r text:=lower(coalesce(p_reason,''));
begin
  select * into a from public.kombax_social_perfiles where id=p_from;select * into b from public.kombax_social_perfiles where id=p_to;if a.id is null or b.id is null then return false;end if;
  at:=case when a.sujeto_tipo='club' then 'club' when a.sujeto_tipo='miembro' then 'competidor' else coalesce((select tipo from public.perfiles_kombax_directos where id=a.perfil_directo_id),'profesional') end;
  bt:=case when b.sujeto_tipo='club' then 'club' when b.sujeto_tipo='miembro' then 'competidor' else coalesce((select tipo from public.perfiles_kombax_directos where id=b.perfil_directo_id),'profesional') end;
  if at='club' and bt='club' then return r in ('evento','entrenamiento','competicion','colaboracion');end if;
  if (at='club' and bt='competidor') or (at='competidor' and bt='club') then return r in ('evento','competicion','entrenamiento','informacion');end if;
  if (at='marca' and bt in ('club','competidor')) or (bt='marca' and at in ('club','competidor')) then return r in ('patrocinio','colaboracion','informacion');end if;
  if (at='federacion' and bt='club') or (bt='federacion' and at='club') then return r in ('competicion','evento','informacion');end if;
  if at='profesional' or bt='profesional' then return r in ('colaboracion','evento','patrocinio','informacion');end if;
  return r in ('evento','competicion','colaboracion','informacion');
end $$;
revoke all on function public.app_kombax_contact_reason_allowed_v044(uuid,uuid,text) from public,anon;
grant execute on function public.app_kombax_contact_reason_allowed_v044(uuid,uuid,text) to authenticated;

create or replace function public.app_kombax_social_mutate_v044(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_actor uuid;v_target uuid;v_post public.kombax_social_publicaciones;v_comment public.kombax_social_comentarios;v_text text;v_type text;v_mode text;v_parent uuid;v_media uuid;v_active boolean;v_count integer;v_reason text;v_from uuid;v_to uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  -- Las operaciones antiguas se delegan salvo las que necesitan límites/reglas nuevas.
  if p_operation not in ('kombax.social.publicar','kombax.social.guardar','kombax.social.comentar','kombax.social.comentario.eliminar','kombax.social.contactar') then
    return public.app_kombax_social_mutate_v041(p_operation,p_payload,p_request_id);
  end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);end if;

  if p_operation='kombax.social.publicar' then
    begin v_actor:=(v_payload->>'autor_perfil_id')::uuid;v_media:=nullif(v_payload->>'media_id','')::uuid;exception when others then raise exception 'KOMBAX_POST_PROFILE_OR_MEDIA_INVALID';end;
    if not public.app_kombax_social_puede_publicar_v041(v_actor) then raise exception 'KOMBAX_POST_NOT_ALLOWED';end if;
    select count(*) into v_count from public.kombax_social_publicaciones where autor_perfil_id=v_actor and estado='activa';if v_count>=30 then raise exception 'KOMBAX_POST_ACTIVE_LIMIT_30';end if;
    select count(*) into v_count from public.kombax_social_publicaciones where autor_perfil_id=v_actor and creado_en>=date_trunc('day',now()) and estado<>'retirada';if v_count>=3 then raise exception 'KOMBAX_POST_DAILY_LIMIT_3';end if;
    if v_media is not null then
      if not exists(select 1 from public.kombax_perfil_media m join public.kombax_social_perfiles sp on sp.perfil_directo_id=m.perfil_directo_id where m.id=v_media and m.estado='active' and sp.id=v_actor) then raise exception 'KOMBAX_POST_MEDIA_NOT_OWNED';end if;
      if exists(select 1 from public.kombax_perfil_media where id=v_media and tipo='video') then select count(*) into v_count from public.kombax_social_publicaciones p join public.kombax_perfil_media m on m.id=p.media_id where p.autor_perfil_id=v_actor and p.estado='activa' and m.tipo='video';if v_count>=10 then raise exception 'KOMBAX_POST_VIDEO_ACTIVE_LIMIT_10';end if;end if;
    end if;
    v_type:=lower(coalesce(v_payload->>'tipo','actualizacion'));if v_type not in ('actualizacion','resultado','evento','oportunidad') then raise exception 'KOMBAX_POST_TYPE_INVALID';end if;
    v_text:=btrim(coalesce(v_payload->>'texto',''));if char_length(v_text)<1 or char_length(v_text)>1500 then raise exception 'KOMBAX_POST_TEXT_INVALID';end if;
    v_mode:=lower(coalesce(v_payload->>'comentarios_estado','open'));if v_mode not in ('open','verified_only','closed') then raise exception 'KOMBAX_COMMENT_MODE_INVALID';end if;
    insert into public.kombax_social_publicaciones(autor_perfil_id,tipo,texto,comentarios_estado,media_id) values(v_actor,v_type,v_text,v_mode,v_media) returning * into v_post;v_result:=to_jsonb(v_post);

  elsif p_operation='kombax.social.guardar' then
    begin v_target:=(v_payload->>'publicacion_id')::uuid;exception when others then raise exception 'KOMBAX_POST_ID_INVALID';end;
    if not exists(select 1 from public.kombax_social_publicaciones where id=v_target and estado='activa') then raise exception 'KOMBAX_POST_NOT_AVAILABLE';end if;
    v_active:=coalesce((v_payload->>'activo')::boolean,true);if v_active then insert into public.kombax_social_guardados(publicacion_id,perfil_id) values(v_target,v_uid) on conflict do nothing;else delete from public.kombax_social_guardados where publicacion_id=v_target and perfil_id=v_uid;end if;
    v_result:=jsonb_build_object('publicacion_id',v_target,'activo',v_active);

  elsif p_operation='kombax.social.comentar' then
    begin v_target:=(v_payload->>'publicacion_id')::uuid;v_actor:=(v_payload->>'autor_social_id')::uuid;v_parent:=nullif(v_payload->>'parent_id','')::uuid;exception when others then raise exception 'KOMBAX_COMMENT_IDENTIFIERS_INVALID';end;
    if not public.app_kombax_social_puede_publicar_v041(v_actor) then raise exception 'KOMBAX_COMMENT_PROFILE_NOT_ALLOWED';end if;
    select * into v_post from public.kombax_social_publicaciones where id=v_target and estado='activa';if v_post.id is null or v_post.comentarios_estado='closed' then raise exception 'KOMBAX_COMMENTS_CLOSED';end if;
    if v_post.comentarios_estado='verified_only' and not exists(select 1 from public.kombax_social_perfiles where id=v_actor and verificado) then raise exception 'KOMBAX_COMMENT_VERIFIED_ONLY';end if;
    v_text:=btrim(coalesce(v_payload->>'texto',''));if char_length(v_text)<1 or char_length(v_text)>800 then raise exception 'KOMBAX_COMMENT_TEXT_INVALID';end if;
    insert into public.kombax_social_comentarios(publicacion_id,autor_social_id,parent_id,texto) values(v_target,v_actor,v_parent,v_text) returning * into v_comment;v_result:=to_jsonb(v_comment);

  elsif p_operation='kombax.social.comentario.eliminar' then
    begin v_target:=(v_payload->>'comentario_id')::uuid;exception when others then raise exception 'KOMBAX_COMMENT_ID_INVALID';end;
    select * into v_comment from public.kombax_social_comentarios where id=v_target for update;if v_comment.id is null then raise exception 'KOMBAX_COMMENT_NOT_FOUND';end if;
    if not public.app_kombax_social_puede_publicar_v041(v_comment.autor_social_id) and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_COMMENT_DELETE_FORBIDDEN';end if;
    update public.kombax_social_comentarios set estado='removed',moderado_por=case when public.app_kombax_es_moderador_v041() then v_uid else moderado_por end,moderacion_motivo=case when public.app_kombax_es_moderador_v041() then left(nullif(btrim(v_payload->>'motivo'),''),1000) else moderacion_motivo end,actualizado_en=now() where id=v_target returning * into v_comment;v_result:=jsonb_build_object('id',v_comment.id,'estado',v_comment.estado);

  elsif p_operation='kombax.social.contactar' then
    begin v_from:=(v_payload->>'remitente_social_id')::uuid;v_to:=(v_payload->>'destinatario_social_id')::uuid;exception when others then raise exception 'KOMBAX_CONTACT_PROFILES_INVALID';end;
    v_reason:=lower(coalesce(v_payload->>'motivo','otro'));if not public.app_kombax_contact_reason_allowed_v044(v_from,v_to,v_reason) then raise exception 'KOMBAX_CONTACT_REASON_NOT_ALLOWED_FOR_RELATION';end if;
    -- El gateway 041 conserva las salvaguardas de menores, duplicados y longitud.
    delete from public.app_mutation_requests where request_id=p_request_id and result is null;
    return public.app_kombax_social_mutate_v041(p_operation,p_payload,p_request_id);
  end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_social_mutate_v044(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v044(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
