begin;
alter table public.notificaciones drop constraint if exists notificaciones_subject_scope_v199;
alter table public.notificaciones add constraint notificaciones_subject_scope_v199 check(club_id is not null or (subject_type='direct_profile' and subject_id is not null) or (subject_type='moderation' and subject_id is not null and perfil_id is not null));
create schema if not exists kombax_moderation;
revoke all on schema kombax_moderation from public,anon,authenticated;
create table kombax_moderation.content_state(
 channel text not null check(channel in ('social','showcase')),
 content_id uuid not null, state text not null check(state in ('hidden','deleted')),
 reason text not null, previous_state text not null, previous_commerce boolean,
 primary key(channel,content_id)
);
create table kombax_moderation.history(
 id bigint generated always as identity primary key,
 channel text not null,content_id uuid not null,actor_id uuid,
 action text not null,reason text not null,before_data jsonb,after_data jsonb,
 created_at timestamptz not null default now()
);
alter table kombax_moderation.content_state enable row level security;
alter table kombax_moderation.history enable row level security;
revoke all on all tables in schema kombax_moderation from public,anon,authenticated;
revoke all on all sequences in schema kombax_moderation from public,anon,authenticated;
create function kombax_moderation.snapshot(p_data jsonb)
returns jsonb language sql immutable set search_path='' as $$
 select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) from jsonb_each(p_data) where key in ('id','nombre','resumen','descripcion','texto','estado','commerce_enabled','imagen_url','galeria','media_id','social_media_id','moderacion_motivo');
$$;

create function kombax_moderation.notify(p_channel text,p_id uuid,p_action text,p_reason text,p_author uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_event uuid:=gen_random_uuid();
begin
 insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,subject_type,subject_id)
 select null,r.uid,'moderation:'||v_event::text,'owner_action',
 'Revisión de contenido: '||p_action,left(p_reason,1000),case when r.uid=p_author then 'notifications' else 'platform-admin' end,
 jsonb_build_object('owner_section','owner-moderation','channel',p_channel,'action',p_action,'content_id',p_id,'review_available',true),
 'moderation',p_id
 from (select p_author uid where p_author is not null union select a.perfil_id from public.kombax_platform_admins a where a.activo
  union select m.perfil_id from public.miembros_club m where m.activo and m.rol in ('direccion','comunicacion') and m.club_id=case when p_channel='social' then (select s.club_id from public.kombax_social_publicaciones p join public.kombax_social_perfiles s on s.id=p.autor_perfil_id where p.id=p_id) else (select b.club_id from public.kombax_showcase_elementos e join public.kombax_showcase_marcas b on b.id=e.marca_id where e.id=p_id) end) r
 on conflict do nothing;
end $$;

create function kombax_moderation.prohibited_offer(p_channel text,p_text text)
returns boolean language sql immutable set search_path='' as $$
 select coalesce(p_text,'') ~* '(arma[s]? de fuego|munici[oó]n|cartuchos? (de|para) (pistola|escopeta|rifle)|pistola[s]? (de fuego|9 ?mm)|rifle[s]? (de fuego|de asalto)|explosivos?)'
 and (coalesce(p_text,'') ~* '(vendo|en venta|a la venta)' or (p_channel='showcase' and btrim(coalesce(p_text,'')) ~* '^(arma[s]? de fuego|munici[oó]n|cartuchos? (de|para) (pistola|escopeta|rifle)|pistola[s]? (de fuego|9 ?mm)|rifle[s]? (de fuego|de asalto)|explosivos?)( |$)'));
$$;

create function kombax_moderation.guard_content()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_channel text:=case when tg_table_name='kombax_social_publicaciones' then 'social' else 'showcase' end;
 v_lock kombax_moderation.content_state;v_text text;v_author uuid;v_before jsonb;v_prior text;
begin
 select * into v_lock from kombax_moderation.content_state where channel=v_channel and content_id=new.id;
 if v_channel='social' then
  v_text:=new.texto;v_prior:=new.estado;
  if v_lock.content_id is not null then new.estado:=case when v_lock.state='deleted' then 'retirada' else 'oculta' end;end if;
 else
  v_text:=new.nombre||' '||coalesce(new.resumen,'')||' '||coalesce(new.descripcion,'');v_prior:=new.estado;
  if v_lock.content_id is not null then new.estado:=case when v_lock.state='deleted' then 'archivado' else 'oculto' end;new.commerce_enabled:=false;end if;
 end if;
 if v_lock.content_id is null and kombax_moderation.prohibited_offer(v_channel,v_text) then
  v_before:=to_jsonb(new);
  insert into kombax_moderation.content_state(channel,content_id,state,reason,previous_state,previous_commerce)
  values(v_channel,new.id,'hidden','Oferta de armas de fuego, munición o explosivos prohibida. Solicita revisión si se trata de un error.',v_prior,case when v_channel='showcase' then (to_jsonb(new)->>'commerce_enabled')::boolean else null end);
  if v_channel='social' then
   new.estado:='oculta';new.moderacion_motivo:='Oferta prohibida: revisión requerida';
   select coalesce(d.perfil_id,i.perfil_id) into v_author from public.kombax_social_perfiles s
    left join public.perfiles_kombax_directos d on d.id=s.perfil_directo_id
    left join public.identidades_sociales i on i.id=s.identidad_social_id where s.id=new.autor_perfil_id;
  else new.estado:='oculto';new.commerce_enabled:=false;v_author:=new.creado_por;end if;
  insert into kombax_moderation.history(channel,content_id,action,reason,before_data,after_data)
  values(v_channel,new.id,'automatic_hide','prohibited_weapons_offer',kombax_moderation.snapshot(v_before),kombax_moderation.snapshot(to_jsonb(new)));
  perform kombax_moderation.notify(v_channel,new.id,'Retirada automática','Oferta de armas de fuego, munición o explosivos prohibida. Puedes solicitar revisión al equipo de moderación.',v_author);
 end if;
 return new;
end $$;
create trigger kx_moderation_guard before insert or update on public.kombax_social_publicaciones for each row execute function kombax_moderation.guard_content();
create trigger kx_moderation_guard before insert or update on public.kombax_showcase_elementos for each row execute function kombax_moderation.guard_content();

create function public.app_kombax_content_browse_r118(p_channel text,p_state text default '',p_search text default '',p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or not coalesce(public.app_kombax_es_moderador_v041(),false) then raise exception 'MODERATOR_REQUIRED';end if;
 if p_channel='social' then
  select coalesce(jsonb_agg(row_data),'[]'::jsonb) into result from (
   select jsonb_build_object('id',p.id,'title',s.nombre_publico,'text',p.texto,'state',p.estado,'created_at',p.creado_en,
    'moderation_state',l.state,'reason',l.reason,'media',coalesce(to_jsonb(m),to_jsonb(pm)),'author_id',p.autor_perfil_id) row_data
   from public.kombax_social_publicaciones p join public.kombax_social_perfiles s on s.id=p.autor_perfil_id
   left join public.kombax_social_media m on m.id=p.social_media_id
   left join public.kombax_perfil_media pm on pm.id=p.media_id
   left join kombax_moderation.content_state l on l.channel='social' and l.content_id=p.id
   where (coalesce(p_state,'')='' or p.estado=p_state) and (coalesce(p_search,'')='' or p.texto ilike '%'||left(p_search,120)||'%' or s.nombre_publico ilike '%'||left(p_search,120)||'%')
   order by p.creado_en desc,p.id desc limit 24 offset greatest(0,least(coalesce(p_offset,0),100000))
  ) q;
 elsif p_channel='showcase' then
  select coalesce(jsonb_agg(row_data),'[]'::jsonb) into result from (
   select jsonb_build_object('id',e.id,'title',e.nombre,'text',e.descripcion,'summary',e.resumen,'state',e.estado,'created_at',e.creado_en,
    'moderation_state',l.state,'reason',l.reason,'image_url',e.imagen_url,'gallery',e.galeria,'seller',m.nombre,'commerce_enabled',e.commerce_enabled) row_data
   from public.kombax_showcase_elementos e join public.kombax_showcase_marcas m on m.id=e.marca_id
   left join kombax_moderation.content_state l on l.channel='showcase' and l.content_id=e.id
   where (coalesce(p_state,'')='' or e.estado=p_state) and (coalesce(p_search,'')='' or e.nombre ilike '%'||left(p_search,120)||'%' or e.descripcion ilike '%'||left(p_search,120)||'%' or m.nombre ilike '%'||left(p_search,120)||'%')
   order by e.creado_en desc,e.id desc limit 24 offset greatest(0,least(coalesce(p_offset,0),100000))
  ) q;
 else raise exception 'INVALID_CHANNEL';end if;
 return result;
end $$;

create function public.app_kombax_content_action_r118(p_channel text,p_id uuid,p_action text,p_reason text,p_patch jsonb default '{}',p_confirmation text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_before jsonb;v_after jsonb;v_author uuid;v_state text;v_lock kombax_moderation.content_state;
begin
 if auth.uid() is null or not coalesce(public.app_kombax_es_moderador_v041(),false) then raise exception 'MODERATOR_REQUIRED';end if;
 if p_action is null or p_action not in ('edit','hide','restore','delete','warn') or p_channel is null or p_channel not in ('social','showcase') then raise exception 'INVALID_ACTION';end if;
 if length(btrim(coalesce(p_reason,''))) not between 10 and 1000 then raise exception 'REASON_REQUIRED';end if;
 if p_action='edit' and (length(btrim(coalesce(p_patch->>'text',''))) not between 1 and 10000 or (p_channel='social' and length(p_patch->>'text')>1500) or (p_channel='showcase' and length(btrim(coalesce(p_patch->>'title',''))) not between 1 and 160)) then raise exception 'INVALID_EDIT';end if;
 if p_action='delete' and (not coalesce(public.app_kombax_es_platform_admin_v055(),false) or coalesce(p_confirmation,'')<>'ELIMINAR') then raise exception 'OWNER_DELETE_CONFIRMATION_REQUIRED';end if;
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
end $$;

create function public.app_kombax_my_moderation_notices_r118()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 return coalesce((select jsonb_agg(to_jsonb(n) order by n.creado_en desc) from (select id,titulo,cuerpo,creado_en,datos from public.notificaciones where perfil_id=auth.uid() and subject_type='moderation' order by creado_en desc limit 100) n),'[]'::jsonb);
end $$;
create function public.app_kombax_content_history_r118(p_channel text,p_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.app_kombax_es_moderador_v041(),false) then raise exception 'MODERATOR_REQUIRED';end if;
 return coalesce((select jsonb_agg(to_jsonb(h) order by h.created_at desc,h.id desc) from kombax_moderation.history h where h.channel=p_channel and h.content_id=p_id),'[]'::jsonb);
end $$;
create function public.app_kombax_moderation_appeal_r118(p_notice_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare n public.notificaciones;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 if length(btrim(coalesce(p_reason,''))) not between 10 and 1000 then raise exception 'REASON_REQUIRED';end if;
 select * into n from public.notificaciones where id=p_notice_id and perfil_id=auth.uid() and subject_type='moderation' for update;
 if n.id is null then raise exception 'NOTICE_NOT_FOUND';end if;
 if exists(select 1 from kombax_moderation.history where channel=n.datos->>'channel' and content_id=n.subject_id and actor_id=auth.uid() and action='appeal' and created_at>now()-interval '24 hours') then raise exception 'REVIEW_ALREADY_REQUESTED';end if;
 insert into kombax_moderation.history(channel,content_id,actor_id,action,reason) values(n.datos->>'channel',n.subject_id,auth.uid(),'appeal',p_reason);
 perform kombax_moderation.notify(n.datos->>'channel',n.subject_id,'Revisión solicitada',p_reason,auth.uid());
 return jsonb_build_object('ok',true);
end $$;
create function public.app_kombax_moderation_media_allowed_r118(p_path text)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and coalesce(public.app_kombax_es_moderador_v041(),false) and exists(select 1 from public.kombax_social_media m join public.kombax_social_publicaciones p on p.social_media_id=m.id where m.storage_bucket='kombax-restricted-media' and m.storage_path=p_path);
$$;
create policy kx_moderation_restricted_media_select_r118 on storage.objects for select to authenticated using(bucket_id='kombax-restricted-media' and public.app_kombax_moderation_media_allowed_r118(name));
create function kombax_moderation.guard_purchase()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.kombax_showcase_elementos e where e.id=new.product_id and e.estado='publicado' and e.commerce_enabled
  and not exists(select 1 from kombax_moderation.content_state s where s.channel='showcase' and s.content_id=e.id) for share;
 if not found then raise exception 'SHOWCASE_PRODUCT_NOT_FOR_SALE';end if;
 return new;
end $$;
create trigger kx_moderation_purchase_guard before insert on kombax_payments.showcase_order_items for each row execute function kombax_moderation.guard_purchase();
revoke all on all functions in schema kombax_moderation from public,anon,authenticated;
revoke all on function public.app_kombax_content_browse_r118(text,text,text,integer),public.app_kombax_content_action_r118(text,uuid,text,text,jsonb,text),public.app_kombax_content_history_r118(text,uuid) from public,anon;
grant execute on function public.app_kombax_content_browse_r118(text,text,text,integer),public.app_kombax_content_action_r118(text,uuid,text,text,jsonb,text),public.app_kombax_content_history_r118(text,uuid) to authenticated;
revoke all on function public.app_kombax_my_moderation_notices_r118() from public,anon;
grant execute on function public.app_kombax_my_moderation_notices_r118() to authenticated;
revoke all on function public.app_kombax_moderation_appeal_r118(uuid,text),public.app_kombax_moderation_media_allowed_r118(text) from public,anon;
grant execute on function public.app_kombax_moderation_appeal_r118(uuid,text),public.app_kombax_moderation_media_allowed_r118(text) to authenticated;
commit;
