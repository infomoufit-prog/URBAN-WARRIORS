begin;
create or replace function kombax_moderation.guard_content()
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
  v_author:=coalesce(v_author,auth.uid());
  perform kombax_moderation.notify(v_channel,new.id,'Retirada automática','Oferta de armas de fuego, munición o explosivos prohibida. Puedes solicitar revisión al equipo de moderación.',v_author);
 end if;
 return new;
end $$;
create or replace function public.app_kombax_moderation_appeal_r118(p_notice_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare n public.notificaciones;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 if length(btrim(coalesce(p_reason,''))) not between 10 and 1000 then raise exception 'REASON_REQUIRED';end if;
 select * into n from public.notificaciones where id=p_notice_id and perfil_id=auth.uid() and subject_type='moderation' for update;
 if n.id is null then raise exception 'NOTICE_NOT_FOUND';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':'||n.subject_id::text,0));
 if exists(select 1 from kombax_moderation.history where channel=n.datos->>'channel' and content_id=n.subject_id and actor_id=auth.uid() and action='appeal' and created_at>now()-interval '24 hours') then raise exception 'REVIEW_ALREADY_REQUESTED';end if;
 insert into kombax_moderation.history(channel,content_id,actor_id,action,reason) values(n.datos->>'channel',n.subject_id,auth.uid(),'appeal',p_reason);
 perform kombax_moderation.notify(n.datos->>'channel',n.subject_id,'Revisión solicitada',p_reason,auth.uid());
 return jsonb_build_object('ok',true);
end $$;
commit;
