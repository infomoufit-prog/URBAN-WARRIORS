-- KOMBAX RC13 build 20.091 · 160 · Public Events & Organizations
-- Fase 2 de KOMBAX Eventos. Extiende SOLO public.kombax_eventos_publicos.
-- Nunca consulta ni migra public.eventos_competicion (Mi Club > Eventos).
begin;

insert into public.kombax_capacidades(clave,descripcion,sensible) values
 ('events.public.partners.manage','Gestionar organizadores, avales, colaboradores y patrocinadores de KOMBAX Eventos',true)
on conflict(clave) do nothing;

-- Las federaciones institucionales son organizadores nativos. Club Premium y Profesional Pro
-- se activarán mediante el mismo entitlement cuando se cierre su plan comercial; no se concede
-- automáticamente a club_saas para no convertir futuros Club Básico en organizadores públicos.
insert into public.kombax_plan_capacidades(plan_codigo,capacidad_clave)
select 'federacion_institucional',v.clave from (values('events.public.organize'),('events.public.partners.manage'),('events.public.share')) v(clave)
where exists(select 1 from public.kombax_planes p where p.codigo='federacion_institucional')
on conflict do nothing;

-- Reconciliar únicamente federaciones institucionales ya activas. No toca Club ni Profesional.
do $$ declare r record; begin
  if to_regprocedure('public.app_kombax_reconcile_entitlements_v071(uuid,uuid)') is not null then
    for r in select s.sujeto_id from public.kombax_suscripciones s where s.sujeto_tipo='perfil_directo' and s.modalidad='federacion_institucional' and s.estado in ('prueba','activa') loop
      perform public.app_kombax_reconcile_entitlements_v071(r.sujeto_id,null);
    end loop;
  end if;
end $$;

create table if not exists public.kombax_evento_entidades(
 id uuid primary key default gen_random_uuid(),
 evento_id uuid not null references public.kombax_eventos_publicos(id) on delete cascade,
 rol text not null check(rol in ('organizador_principal','organizador','coorganizador','avala','colaborador','patrocinador_principal','patrocinador_oficial','patrocinador')),
 origen text not null default 'kombax' check(origen in ('kombax','externa')),
 social_profile_id uuid references public.kombax_social_perfiles(id) on delete restrict,
 nombre_externo text,
 logo_url_externo text,
 web_externa text,
 puede_gestionar boolean not null default false,
 estado text not null default 'aceptada' check(estado in ('pendiente','aceptada','rechazada','retirada')),
 orden smallint not null default 0 check(orden between 0 and 100),
 creado_por uuid not null references public.perfiles(id) on delete restrict default auth.uid(),
 respondido_por uuid references public.perfiles(id) on delete set null,
 creado_en timestamptz not null default now(),
 respondido_en timestamptz,
 actualizado_en timestamptz not null default now(),
 constraint kombax_evento_entidades_origen_ck check(
   (origen='kombax' and social_profile_id is not null and nombre_externo is null)
   or (origen='externa' and social_profile_id is null and char_length(btrim(coalesce(nombre_externo,''))) between 2 and 180)
 ),
 constraint kombax_evento_entidades_manage_ck check(not puede_gestionar or rol in ('organizador_principal','organizador','coorganizador')),
 constraint kombax_evento_entidades_logo_ck check(logo_url_externo is null or logo_url_externo ~* '^https://[^[:space:]]+$'),
 constraint kombax_evento_entidades_web_ck check(web_externa is null or web_externa ~* '^https://[^[:space:]]+$')
);
create unique index if not exists uq_kombax_evento_entidad_social_v160 on public.kombax_evento_entidades(evento_id,rol,social_profile_id) where social_profile_id is not null and estado<>'retirada';
create index if not exists idx_kombax_evento_entidades_public_v160 on public.kombax_evento_entidades(evento_id,estado,rol,orden,id);
create index if not exists idx_kombax_evento_entidades_invites_v160 on public.kombax_evento_entidades(social_profile_id,estado,creado_en desc) where estado='pendiente';
alter table public.kombax_evento_entidades enable row level security;
revoke all on public.kombax_evento_entidades from public,anon,authenticated;

create or replace function public.app_kombax_eventos_social_subject_v160(p_social_id uuid)
returns table(sujeto_tipo text,sujeto_id uuid,perfil_tipo text)
language sql stable security definer set search_path=public as $$
  select case when sp.sujeto_tipo='club' then 'club' else 'perfil_directo' end,
         case when sp.sujeto_tipo='club' then sp.club_id else sp.perfil_directo_id end,
         public.app_kombax_social_tipo_v051(sp.id)
  from public.kombax_social_perfiles sp
  where sp.id=p_social_id and sp.sujeto_tipo in ('club','perfil_directo') and sp.visible and sp.estado='activo';
$$;
revoke all on function public.app_kombax_eventos_social_subject_v160(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_eventos_sujeto_puede_organizar_v160(p_sujeto_tipo text,p_sujeto_id uuid)
returns boolean language plpgsql stable security definer set search_path=public,auth as $$
begin
 if auth.uid() is null or p_sujeto_id is null then return false; end if;
 if p_sujeto_tipo='club' then
   return exists(
     select 1 from public.miembros_club m
     join public.kombax_entitlements e on e.sujeto_tipo='club' and e.sujeto_id=m.club_id
       and e.capacidad_clave='events.public.organize' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())
     where m.club_id=p_sujeto_id and m.perfil_id=auth.uid() and m.activo
       and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))
   );
 elsif p_sujeto_tipo='perfil_directo' then
   return exists(
     select 1 from public.perfiles_kombax_directos d
     join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id
       and e.capacidad_clave='events.public.organize' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())
     where d.id=p_sujeto_id and d.perfil_id=auth.uid() and d.estado='activo' and d.verificacion_estado='verificado'
       and d.tipo in ('federacion','profesional','competidor')
   );
 end if;
 return false;
end $$;
revoke all on function public.app_kombax_eventos_sujeto_puede_organizar_v160(text,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_sujeto_puede_organizar_v160(text,uuid) to authenticated;

create or replace function public.app_kombax_eventos_puede_actuar_social_v160(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
 select exists(
   select 1 from public.kombax_social_perfiles sp
   left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
   where sp.id=p_social_id and sp.visible and sp.estado='activo' and (
     (sp.sujeto_tipo='club' and exists(select 1 from public.miembros_club m where m.club_id=sp.club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))))
     or (sp.sujeto_tipo='perfil_directo' and d.perfil_id=auth.uid() and d.estado='activo')
   )
 );
$$;
revoke all on function public.app_kombax_eventos_puede_actuar_social_v160(uuid) from public,anon;
grant execute on function public.app_kombax_eventos_puede_actuar_social_v160(uuid) to authenticated;

create or replace function public.app_kombax_evento_puede_gestionar_v160(p_evento_id uuid)
returns boolean language plpgsql stable security definer set search_path=public,auth as $$
declare e public.kombax_eventos_publicos; r record;
begin
 if auth.uid() is null then return false; end if;
 select * into e from public.kombax_eventos_publicos where id=p_evento_id;
 if e.id is null then return false; end if;
 if e.creador_tipo='club' and public.app_kombax_eventos_sujeto_puede_organizar_v160('club',e.creador_club_id) then return true; end if;
 if e.creador_tipo='perfil_directo' and public.app_kombax_eventos_sujeto_puede_organizar_v160('perfil_directo',e.creador_perfil_directo_id) then return true; end if;
 for r in
   select ee.social_profile_id,s.sujeto_tipo,s.sujeto_id
   from public.kombax_evento_entidades ee
   cross join lateral public.app_kombax_eventos_social_subject_v160(ee.social_profile_id) s
   where ee.evento_id=p_evento_id and ee.estado='aceptada' and ee.puede_gestionar
 loop
   if public.app_kombax_eventos_puede_actuar_social_v160(r.social_profile_id)
      and public.app_kombax_eventos_sujeto_puede_organizar_v160(r.sujeto_tipo,r.sujeto_id) then return true; end if;
 end loop;
 return false;
end $$;
revoke all on function public.app_kombax_evento_puede_gestionar_v160(uuid) from public,anon;
grant execute on function public.app_kombax_evento_puede_gestionar_v160(uuid) to authenticated;

create or replace function public.app_kombax_eventos_mis_organizadores_v160()
returns table(social_profile_id uuid,sujeto_tipo text,sujeto_id uuid,perfil_tipo text,nombre_publico text,slug text,logo_url text,verificado boolean,puede_organizar boolean,motivo text)
language sql stable security definer set search_path=public,auth as $$
 select sp.id,
   case when sp.sujeto_tipo='club' then 'club' else 'perfil_directo' end,
   case when sp.sujeto_tipo='club' then sp.club_id else sp.perfil_directo_id end,
   public.app_kombax_social_tipo_v051(sp.id),sp.nombre_publico,sp.slug,public.app_kombax_social_avatar_url_v063(sp.id),sp.verificado,
   public.app_kombax_eventos_sujeto_puede_organizar_v160(case when sp.sujeto_tipo='club' then 'club' else 'perfil_directo' end,case when sp.sujeto_tipo='club' then sp.club_id else sp.perfil_directo_id end),
   case
     when sp.sujeto_tipo='club' and not exists(select 1 from public.kombax_entitlements e where e.sujeto_tipo='club' and e.sujeto_id=sp.club_id and e.capacidad_clave='events.public.organize' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())) then 'Disponible con Club Premium'
     when sp.sujeto_tipo='perfil_directo' and public.app_kombax_social_tipo_v051(sp.id)='profesional' and not public.app_kombax_eventos_sujeto_puede_organizar_v160('perfil_directo',sp.perfil_directo_id) then 'Disponible con Profesional Pro'
     when sp.sujeto_tipo='perfil_directo' and public.app_kombax_social_tipo_v051(sp.id)='competidor' and not public.app_kombax_eventos_sujeto_puede_organizar_v160('perfil_directo',sp.perfil_directo_id) then 'Disponible para Competidor Pro cuando se active'
     else '' end
 from public.kombax_social_perfiles sp
 left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
 where auth.uid() is not null and sp.visible and sp.estado='activo' and sp.sujeto_tipo in ('club','perfil_directo') and (
   (sp.sujeto_tipo='club' and exists(select 1 from public.miembros_club m where m.club_id=sp.club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))))
   or (sp.sujeto_tipo='perfil_directo' and d.perfil_id=auth.uid() and d.tipo in ('federacion','profesional','competidor') and d.estado='activo')
 )
 order by public.app_kombax_eventos_sujeto_puede_organizar_v160(case when sp.sujeto_tipo='club' then 'club' else 'perfil_directo' end,case when sp.sujeto_tipo='club' then sp.club_id else sp.perfil_directo_id end) desc,sp.nombre_publico;
$$;
revoke all on function public.app_kombax_eventos_mis_organizadores_v160() from public,anon;
grant execute on function public.app_kombax_eventos_mis_organizadores_v160() to authenticated;

create or replace function public.app_kombax_evento_entidades_v160(p_evento_id uuid)
returns table(id uuid,rol text,origen text,social_profile_id uuid,nombre text,slug text,perfil_tipo text,logo_url text,web_url text,verificado boolean,puede_gestionar boolean,estado text,orden smallint)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_manage boolean:=false;
begin
 if auth.uid() is not null then v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_evento_id); end if;
 return query
 select ee.id,ee.rol,ee.origen,ee.social_profile_id,
   case when ee.origen='kombax' then sp.nombre_publico else ee.nombre_externo end,
   case when ee.origen='kombax' then sp.slug else null end,
   case when ee.origen='kombax' then public.app_kombax_social_tipo_v051(sp.id) else 'externa' end,
   case when ee.origen='kombax' then public.app_kombax_social_avatar_url_v063(sp.id) else ee.logo_url_externo end,
   case when ee.origen='externa' then ee.web_externa else null end,
   case when ee.origen='kombax' then sp.verificado else false end,
   ee.puede_gestionar,ee.estado,ee.orden
 from public.kombax_evento_entidades ee
 left join public.kombax_social_perfiles sp on sp.id=ee.social_profile_id
 where ee.evento_id=p_evento_id and (ee.estado='aceptada' or v_manage)
 order by case ee.rol when 'organizador_principal' then 0 when 'organizador' then 1 when 'coorganizador' then 2 when 'avala' then 3 when 'colaborador' then 4 when 'patrocinador_principal' then 5 when 'patrocinador_oficial' then 6 else 7 end,ee.orden,ee.creado_en;
end $$;
revoke all on function public.app_kombax_evento_entidades_v160(uuid) from public;
grant execute on function public.app_kombax_evento_entidades_v160(uuid) to anon,authenticated;

create or replace function public.app_kombax_evento_publico_detalle_v160(p_evento_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_event jsonb;v_entities jsonb;v_manage boolean:=false;
begin
 select to_jsonb(e) - 'creado_por' - 'creador_club_id' - 'creador_perfil_directo_id' into v_event
 from public.kombax_eventos_publicos e
 where e.id=p_evento_id and (e.visibilidad='publico' or (auth.uid() is not null and public.app_kombax_evento_puede_gestionar_v160(e.id)))
   and (e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') or (auth.uid() is not null and public.app_kombax_evento_puede_gestionar_v160(e.id)))
 limit 1;
 if v_event is null then return null; end if;
 if auth.uid() is not null then v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_evento_id); end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.orden,x.id),'[]'::jsonb) into v_entities from public.app_kombax_evento_entidades_v160(p_evento_id) x;
 return jsonb_build_object('event',v_event,'entities',coalesce(v_entities,'[]'::jsonb),'can_manage',v_manage);
end $$;
revoke all on function public.app_kombax_evento_publico_detalle_v160(uuid) from public;
grant execute on function public.app_kombax_evento_publico_detalle_v160(uuid) to anon,authenticated;

create or replace function public.app_kombax_eventos_invitaciones_v160()
returns table(id uuid,evento_id uuid,evento_nombre text,evento_fecha timestamptz,rol text,social_profile_id uuid,identidad_nombre text,identidad_tipo text,creado_en timestamptz)
language sql stable security definer set search_path=public,auth as $$
 select ee.id,e.id,e.nombre,e.fecha_inicio,ee.rol,ee.social_profile_id,sp.nombre_publico,public.app_kombax_social_tipo_v051(sp.id),ee.creado_en
 from public.kombax_evento_entidades ee
 join public.kombax_eventos_publicos e on e.id=ee.evento_id
 join public.kombax_social_perfiles sp on sp.id=ee.social_profile_id
 where ee.estado='pendiente' and public.app_kombax_eventos_puede_actuar_social_v160(ee.social_profile_id)
 order by ee.creado_en desc;
$$;
revoke all on function public.app_kombax_eventos_invitaciones_v160() from public,anon;
grant execute on function public.app_kombax_eventos_invitaciones_v160() to authenticated;

create or replace function public.app_kombax_eventos_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
 v_uid uuid:=auth.uid(); v_payload jsonb:=coalesce(p_payload,'{}'::jsonb); v_existing public.app_mutation_requests; v_result jsonb;
 v_event public.kombax_eventos_publicos; v_event_id uuid; v_subject_type text; v_subject_id uuid; v_social_id uuid; v_name text; v_slug text;
 v_entity public.kombax_evento_entidades; v_role text; v_origin text; v_target_social uuid; v_target_type text; v_target_id uuid; v_accept boolean;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
 if p_operation not in ('event.save','event.entity.add','event.entity.remove','event.entity.respond') then raise exception 'EVENTS_OPERATION_NOT_ALLOWED'; end if;
 select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
 if v_existing.request_id is not null then
   if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
   if v_existing.result is not null then return v_existing.result; end if;
 else
   insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation);
 end if;

 if p_operation='event.save' then
   v_subject_type:=nullif(v_payload->>'sujeto_tipo',''); v_subject_id:=nullif(v_payload->>'sujeto_id','')::uuid;
   if not public.app_kombax_eventos_sujeto_puede_organizar_v160(v_subject_type,v_subject_id) then raise exception 'EVENTS_ORGANIZE_ENTITLEMENT_REQUIRED'; end if;
   if nullif(v_payload->>'id','') is not null then
     v_event_id:=(v_payload->>'id')::uuid;
     if not public.app_kombax_evento_puede_gestionar_v160(v_event_id) then raise exception 'EVENTS_MANAGE_DENIED'; end if;
   end if;
   if char_length(btrim(coalesce(v_payload->>'nombre','')))<3 then raise exception 'EVENT_NAME_REQUIRED'; end if;
   if v_subject_type='club' then
     select sp.id,sp.nombre_publico into v_social_id,v_name from public.kombax_social_perfiles sp where sp.sujeto_tipo='club' and sp.club_id=v_subject_id and sp.visible and sp.estado='activo' limit 1;
   else
     select sp.id,sp.nombre_publico into v_social_id,v_name from public.kombax_social_perfiles sp where sp.sujeto_tipo='perfil_directo' and sp.perfil_directo_id=v_subject_id and sp.visible and sp.estado='activo' limit 1;
   end if;
   if v_social_id is null then raise exception 'EVENTS_PUBLIC_PROFILE_REQUIRED'; end if;
   v_slug:=public.app_kombax_slug_v043(v_payload->>'nombre');
   if v_event_id is null then
     if v_slug='' then v_slug:='evento'; end if;
     while exists(select 1 from public.kombax_eventos_publicos x where x.slug=v_slug) loop v_slug:=left(v_slug,48)||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,7); end loop;
     insert into public.kombax_eventos_publicos(slug,tipo,nombre,resumen,descripcion,estado,visibilidad,fecha_inicio,fecha_fin,timezone,lugar_nombre,municipio,provincia,pais,cartel_url,banner_url,tema_visual,creador_tipo,creador_club_id,creador_perfil_directo_id,organizador_nombre,creado_por,publicado_en)
     values(v_slug,coalesce(nullif(v_payload->>'tipo',''),'otro'),btrim(v_payload->>'nombre'),left(coalesce(v_payload->>'resumen',''),500),left(coalesce(v_payload->>'descripcion',''),6000),coalesce(nullif(v_payload->>'estado',''),'borrador'),coalesce(nullif(v_payload->>'visibilidad',''),'publico'),nullif(v_payload->>'fecha_inicio','')::timestamptz,nullif(v_payload->>'fecha_fin','')::timestamptz,coalesce(nullif(v_payload->>'timezone',''),'Europe/Madrid'),left(coalesce(v_payload->>'lugar_nombre',''),220),left(coalesce(v_payload->>'municipio',''),120),left(coalesce(v_payload->>'provincia',''),120),left(coalesce(nullif(v_payload->>'pais',''),'España'),120),nullif(v_payload->>'cartel_url',''),nullif(v_payload->>'banner_url',''),coalesce(nullif(v_payload->>'tema_visual',''),'fight'),case when v_subject_type='club' then 'club' else 'perfil_directo' end,case when v_subject_type='club' then v_subject_id end,case when v_subject_type='perfil_directo' then v_subject_id end,v_name,v_uid,case when coalesce(v_payload->>'estado','borrador')='borrador' then null else now() end)
     returning * into v_event;
     insert into public.kombax_evento_entidades(evento_id,rol,origen,social_profile_id,puede_gestionar,estado,orden,creado_por)
     values(v_event.id,'organizador_principal','kombax',v_social_id,true,'aceptada',0,v_uid) on conflict do nothing;
   else
     update public.kombax_eventos_publicos set tipo=coalesce(nullif(v_payload->>'tipo',''),tipo),nombre=btrim(v_payload->>'nombre'),resumen=left(coalesce(v_payload->>'resumen',resumen),500),descripcion=left(coalesce(v_payload->>'descripcion',descripcion),6000),estado=coalesce(nullif(v_payload->>'estado',''),estado),visibilidad=coalesce(nullif(v_payload->>'visibilidad',''),visibilidad),fecha_inicio=case when v_payload ? 'fecha_inicio' then nullif(v_payload->>'fecha_inicio','')::timestamptz else fecha_inicio end,fecha_fin=case when v_payload ? 'fecha_fin' then nullif(v_payload->>'fecha_fin','')::timestamptz else fecha_fin end,lugar_nombre=left(coalesce(v_payload->>'lugar_nombre',lugar_nombre),220),municipio=left(coalesce(v_payload->>'municipio',municipio),120),provincia=left(coalesce(v_payload->>'provincia',provincia),120),pais=left(coalesce(v_payload->>'pais',pais),120),cartel_url=case when v_payload ? 'cartel_url' then nullif(v_payload->>'cartel_url','') else cartel_url end,banner_url=case when v_payload ? 'banner_url' then nullif(v_payload->>'banner_url','') else banner_url end,tema_visual=coalesce(nullif(v_payload->>'tema_visual',''),tema_visual),publicado_en=case when publicado_en is null and coalesce(v_payload->>'estado',estado)<>'borrador' then now() else publicado_en end,actualizado_en=now() where id=v_event_id returning * into v_event;
   end if;
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_event)-'creado_por');

 elsif p_operation='event.entity.add' then
   v_event_id:=(v_payload->>'evento_id')::uuid;
   if not public.app_kombax_evento_puede_gestionar_v160(v_event_id) then raise exception 'EVENTS_MANAGE_DENIED'; end if;
   v_role:=v_payload->>'rol'; v_origin:=coalesce(nullif(v_payload->>'origen',''),'kombax');
   if v_role not in ('organizador','coorganizador','avala','colaborador','patrocinador_principal','patrocinador_oficial','patrocinador') then raise exception 'EVENT_ENTITY_ROLE_INVALID'; end if;
   if v_origin='kombax' then
     v_target_social:=(v_payload->>'social_profile_id')::uuid;
     if not exists(select 1 from public.kombax_social_perfiles sp where sp.id=v_target_social and sp.visible and sp.estado='activo' and sp.sujeto_tipo in ('club','perfil_directo')) then raise exception 'EVENT_ENTITY_PROFILE_INVALID'; end if;
     insert into public.kombax_evento_entidades(evento_id,rol,origen,social_profile_id,puede_gestionar,estado,orden,creado_por)
     values(v_event_id,v_role,'kombax',v_target_social,v_role in ('organizador','coorganizador'),case when v_role in ('organizador','coorganizador') then 'pendiente' else 'aceptada' end,least(100,greatest(0,coalesce((v_payload->>'orden')::smallint,0))),v_uid) returning * into v_entity;
   elsif v_origin='externa' then
     if v_role in ('organizador','coorganizador') then raise exception 'EVENT_EXTERNAL_ENTITY_CANNOT_MANAGE'; end if;
     insert into public.kombax_evento_entidades(evento_id,rol,origen,nombre_externo,logo_url_externo,web_externa,puede_gestionar,estado,orden,creado_por)
     values(v_event_id,v_role,'externa',left(btrim(v_payload->>'nombre'),180),nullif(v_payload->>'logo_url',''),nullif(v_payload->>'web_url',''),false,'aceptada',least(100,greatest(0,coalesce((v_payload->>'orden')::smallint,0))),v_uid) returning * into v_entity;
   else raise exception 'EVENT_ENTITY_ORIGIN_INVALID'; end if;
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_entity));

 elsif p_operation='event.entity.remove' then
   select * into v_entity from public.kombax_evento_entidades where id=(v_payload->>'entity_id')::uuid for update;
   if v_entity.id is null or not public.app_kombax_evento_puede_gestionar_v160(v_entity.evento_id) then raise exception 'EVENTS_MANAGE_DENIED'; end if;
   if v_entity.rol='organizador_principal' then raise exception 'EVENT_PRIMARY_ORGANIZER_REQUIRED'; end if;
   update public.kombax_evento_entidades set estado='retirada',actualizado_en=now() where id=v_entity.id;
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('id',v_entity.id));

 else
   select * into v_entity from public.kombax_evento_entidades where id=(v_payload->>'entity_id')::uuid and estado='pendiente' for update;
   if v_entity.id is null or v_entity.social_profile_id is null or not public.app_kombax_eventos_puede_actuar_social_v160(v_entity.social_profile_id) then raise exception 'EVENT_INVITATION_NOT_AVAILABLE'; end if;
   v_accept:=coalesce((v_payload->>'aceptar')::boolean,false);
   if v_accept and v_entity.puede_gestionar then
     select s.sujeto_tipo,s.sujeto_id into v_target_type,v_target_id from public.app_kombax_eventos_social_subject_v160(v_entity.social_profile_id) s;
     if not public.app_kombax_eventos_sujeto_puede_organizar_v160(v_target_type,v_target_id) then raise exception 'EVENTS_ORGANIZE_ENTITLEMENT_REQUIRED'; end if;
   end if;
   update public.kombax_evento_entidades set estado=case when v_accept then 'aceptada' else 'rechazada' end,respondido_por=v_uid,respondido_en=now(),actualizado_en=now() where id=v_entity.id returning * into v_entity;
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_entity));
 end if;
 update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
 return v_result;
end $$;
revoke all on function public.app_kombax_eventos_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v160(text,jsonb,uuid) to authenticated;

comment on table public.kombax_evento_entidades is 'Organización pública de KOMBAX Eventos: organizadores, avales, colaboradores y patrocinadores. Independiente de Mi Club.';
comment on function public.app_kombax_eventos_mutate_v160(text,jsonb,uuid) is 'Puerta idempotente de Fase 2 para ficha pública y ecosistema institucional. No gestiona inscripciones ni combates.';
notify pgrst,'reload schema';
commit;
