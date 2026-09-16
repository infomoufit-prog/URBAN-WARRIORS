-- KOMBAX 20.101 R37 · Brand public projection + explicit Club/Event sponsorship opt-in
begin;

create table if not exists public.kombax_club_brand_preferences_v224(
  club_id uuid primary key references public.clubes(id) on delete cascade,
  discoverable_by_brands boolean not null default false,
  inbound_enabled boolean not null default false,
  collaboration_categories text[] not null default '{}'::text[],
  collaboration_note text,
  updated_by uuid,
  updated_at timestamptz not null default now()
);

create table if not exists public.kombax_event_brand_preferences_v224(
  event_id uuid primary key references public.kombax_eventos_publicos(id) on delete cascade,
  sponsorship_open boolean not null default false,
  inbound_enabled boolean not null default false,
  collaboration_categories text[] not null default '{}'::text[],
  sponsorship_note text,
  updated_by uuid,
  updated_at timestamptz not null default now()
);

alter table public.kombax_club_brand_preferences_v224 enable row level security;
alter table public.kombax_event_brand_preferences_v224 enable row level security;
revoke all on public.kombax_club_brand_preferences_v224 from public,anon,authenticated;
revoke all on public.kombax_event_brand_preferences_v224 from public,anon,authenticated;
create policy r37_rpc_only on public.kombax_club_brand_preferences_v224 for all to public using(false) with check(false);
create policy r37_rpc_only on public.kombax_event_brand_preferences_v224 for all to public using(false) with check(false);

create or replace function public.app_kombax_brand_public_profile_v224(p_brand_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_brand public.perfiles_kombax_directos%rowtype; v_settings jsonb; v_campaigns jsonb;
begin
  select * into v_brand from public.perfiles_kombax_directos where id=p_brand_profile_id and tipo='marca' and publico is true;
  if v_brand.id is null then return null; end if;
  select jsonb_build_object(
    'sector',s.sector,'territories',to_jsonb(s.territories),'disciplines',to_jsonb(s.disciplines),
    'collaboration_open',s.collaboration_open,'public_business_summary',s.public_business_summary
  ) into v_settings from public.kombax_brand_profiles_v223 s where s.brand_profile_id=p_brand_profile_id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'title',c.title,'campaign_type',c.campaign_type,'description',c.description,
    'territory',c.territory,'disciplines',to_jsonb(c.disciplines),'audience_types',to_jsonb(c.audience_types),
    'compensation_type',c.compensation_type,'compensation_summary',c.compensation_summary,
    'conditions_summary',c.conditions_summary,'starts_at',c.starts_at,'ends_at',c.ends_at
  ) order by c.updated_at desc),'[]'::jsonb) into v_campaigns
  from public.kombax_brand_campaigns_v223 c
  where c.brand_profile_id=p_brand_profile_id and c.status='active' and c.visibility='open'
    and (c.starts_at is null or c.starts_at<=now()) and (c.ends_at is null or c.ends_at>=now());
  return jsonb_build_object('brand_profile_id',p_brand_profile_id,'settings',coalesce(v_settings,'{}'::jsonb),'open_campaigns',v_campaigns,'privacy',jsonb_build_object('public_projection_only',true,'private_proposals',false,'private_team',false,'private_weight_history',false));
end $$;

create or replace function public.app_kombax_brand_target_preferences_v224(p_target_type text,p_target_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row jsonb;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_target_type='club' then
   if not public.tiene_rol_club(p_target_id,'direccion','secretaria','comunicacion') then raise exception 'KOMBAX_CLUB_MANAGE_REQUIRED'; end if;
   select coalesce(to_jsonb(x),'{}'::jsonb) into v_row from public.kombax_club_brand_preferences_v224 x where x.club_id=p_target_id;
 elsif p_target_type='event' then
   if not public.app_kombax_evento_puede_gestionar_v160(p_target_id) then raise exception 'KOMBAX_EVENT_MANAGE_REQUIRED'; end if;
   select coalesce(to_jsonb(x),'{}'::jsonb) into v_row from public.kombax_event_brand_preferences_v224 x where x.event_id=p_target_id;
 else raise exception 'KOMBAX_BRAND_TARGET_TYPE_INVALID'; end if;
 return coalesce(v_row,'{}'::jsonb);
end $$;

create or replace function public.app_kombax_brand_target_preferences_mutate_v224(p_operation text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_id uuid;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_operation='club.preferences.save' then
   v_id:=(p_payload->>'club_id')::uuid;
   if not public.tiene_rol_club(v_id,'direccion','secretaria','comunicacion') then raise exception 'KOMBAX_CLUB_MANAGE_REQUIRED'; end if;
   insert into public.kombax_club_brand_preferences_v224(club_id,discoverable_by_brands,inbound_enabled,collaboration_categories,collaboration_note,updated_by,updated_at)
   values(v_id,coalesce((p_payload->>'discoverable_by_brands')::boolean,false),coalesce((p_payload->>'inbound_enabled')::boolean,false),coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'collaboration_categories','[]'::jsonb))),'{}'::text[]),nullif(trim(p_payload->>'collaboration_note'),''),v_uid,now())
   on conflict(club_id) do update set discoverable_by_brands=excluded.discoverable_by_brands,inbound_enabled=excluded.inbound_enabled,collaboration_categories=excluded.collaboration_categories,collaboration_note=excluded.collaboration_note,updated_by=v_uid,updated_at=now();
   return jsonb_build_object('ok',true,'club_id',v_id);
 elsif p_operation='event.preferences.save' then
   v_id:=(p_payload->>'event_id')::uuid;
   if not public.app_kombax_evento_puede_gestionar_v160(v_id) then raise exception 'KOMBAX_EVENT_MANAGE_REQUIRED'; end if;
   insert into public.kombax_event_brand_preferences_v224(event_id,sponsorship_open,inbound_enabled,collaboration_categories,sponsorship_note,updated_by,updated_at)
   values(v_id,coalesce((p_payload->>'sponsorship_open')::boolean,false),coalesce((p_payload->>'inbound_enabled')::boolean,false),coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'collaboration_categories','[]'::jsonb))),'{}'::text[]),nullif(trim(p_payload->>'sponsorship_note'),''),v_uid,now())
   on conflict(event_id) do update set sponsorship_open=excluded.sponsorship_open,inbound_enabled=excluded.inbound_enabled,collaboration_categories=excluded.collaboration_categories,sponsorship_note=excluded.sponsorship_note,updated_by=v_uid,updated_at=now();
   return jsonb_build_object('ok',true,'event_id',v_id);
 else raise exception 'KOMBAX_BRAND_TARGET_OPERATION_UNSUPPORTED'; end if;
end $$;

create or replace function public.app_kombax_brand_discovery_v224(p_brand_profile_id uuid,p_target_type text,p_query text default '',p_discipline text default null,p_territory text default null,p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_limit integer:=least(100,greatest(1,coalesce(p_limit,30))); v_rows jsonb:='[]'::jsonb; v_q text:='%'||coalesce(trim(p_query),'')||'%';
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if not exists(select 1 from public.perfiles_kombax_directos d where d.id=p_brand_profile_id and d.tipo='marca') then raise exception 'KOMBAX_BRAND_PROFILE_REQUIRED'; end if;
 if not public.app_kombax_puede_gestionar_perfil_v070(p_brand_profile_id,'read') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if;
 if p_target_type not in ('fighter','club','event') then raise exception 'KOMBAX_BRAND_DISCOVERY_TARGET_INVALID'; end if;
 if p_target_type='fighter' then
  select coalesce(jsonb_agg(x.item order by x.name),'[]'::jsonb) into v_rows from (select d.nombre_publico name,jsonb_build_object('target_type','direct_profile','id',d.id,'name',d.nombre_publico,'profile_type',d.tipo,'location',d.ubicacion,'disciplines',coalesce(to_jsonb(d.disciplinas),'[]'::jsonb),'category',d.categoria,'club',d.club_declarado,'verified',d.verificacion_estado,'contact_mode',pref.contact_mode,'collaboration_note',pref.collaboration_note) item from public.perfiles_kombax_directos d join public.kombax_brand_collaboration_preferences_v223 pref on pref.direct_profile_id=d.id where d.tipo='competidor' and d.publico is true and pref.discoverable_by_brands and pref.inbound_enabled and (coalesce(trim(p_query),'')='' or d.nombre_publico ilike v_q or coalesce(d.club_declarado,'') ilike v_q or coalesce(d.ubicacion,'') ilike v_q) and (p_discipline is null or p_discipline='' or p_discipline=any(coalesce(d.disciplinas,'{}'::text[]))) and (p_territory is null or p_territory='' or coalesce(d.ubicacion,'') ilike '%'||p_territory||'%') order by d.nombre_publico limit v_limit) x;
 elsif p_target_type='club' then
  select coalesce(jsonb_agg(x.item order by x.name),'[]'::jsonb) into v_rows from (select c.nombre name,jsonb_build_object('target_type','club','id',c.id,'name',c.nombre,'slug',c.slug,'location',c.direccion,'website',c.web,'logo_url',c.logo_url,'verified',sp.verificado,'collaboration_note',pref.collaboration_note,'collaboration_categories',to_jsonb(pref.collaboration_categories)) item from public.clubes c join public.kombax_social_perfiles sp on sp.club_id=c.id and sp.sujeto_tipo='club' and sp.visible and sp.contacto_habilitado and sp.estado='activo' join public.kombax_club_brand_preferences_v224 pref on pref.club_id=c.id and pref.discoverable_by_brands and pref.inbound_enabled where c.activo and (coalesce(trim(p_query),'')='' or c.nombre ilike v_q or coalesce(c.direccion,'') ilike v_q) and (p_territory is null or p_territory='' or coalesce(c.direccion,'') ilike '%'||p_territory||'%') group by c.id,c.nombre,c.slug,c.direccion,c.web,c.logo_url,sp.verificado,pref.collaboration_note,pref.collaboration_categories order by c.nombre limit v_limit) x;
 else
  select coalesce(jsonb_agg(x.item order by x.starts_at asc nulls last),'[]'::jsonb) into v_rows from (select e.fecha_inicio starts_at,jsonb_build_object('target_type','event','id',e.id,'name',e.nombre,'event_type',e.tipo,'starts_at',e.fecha_inicio,'location',concat_ws(', ',e.lugar_nombre,e.municipio,e.provincia,e.pais),'organizer',e.organizador_nombre,'poster_url',e.cartel_url,'banner_url',e.banner_url,'sponsorship_note',pref.sponsorship_note,'collaboration_categories',to_jsonb(pref.collaboration_categories)) item from public.kombax_eventos_publicos e join public.kombax_event_brand_preferences_v224 pref on pref.event_id=e.id and pref.sponsorship_open and pref.inbound_enabled where e.publicado_en is not null and coalesce(e.estado,'')<>'cancelado' and (coalesce(trim(p_query),'')='' or e.nombre ilike v_q or coalesce(e.organizador_nombre,'') ilike v_q or coalesce(e.municipio,'') ilike v_q) and (p_territory is null or p_territory='' or concat_ws(' ',e.municipio,e.provincia,e.pais) ilike '%'||p_territory||'%') order by e.fecha_inicio asc nulls last limit v_limit) x;
 end if;
 return jsonb_build_object('target_type',p_target_type,'items',coalesce(v_rows,'[]'::jsonb),'privacy',jsonb_build_object('public_data_only',true,'explicit_commercial_opt_in',true,'private_weight_history',false,'private_club_data',false));
end $$;

create or replace function public.app_kombax_brand_proposal_target_guard_v224() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.source<>'brand_invite' then return new; end if;
 if new.target_type='direct_profile' then
   if not exists(select 1 from public.kombax_brand_collaboration_preferences_v223 p where p.direct_profile_id=new.target_direct_profile_id and p.discoverable_by_brands and p.inbound_enabled) then raise exception 'KOMBAX_COLLABORATION_NOT_AVAILABLE'; end if;
 elsif new.target_type='club' then
   if not exists(select 1 from public.kombax_club_brand_preferences_v224 p where p.club_id=new.target_club_id and p.discoverable_by_brands and p.inbound_enabled) then raise exception 'KOMBAX_CLUB_BRAND_COLLABORATION_NOT_AVAILABLE'; end if;
 elsif new.target_type='event' then
   if not exists(select 1 from public.kombax_event_brand_preferences_v224 p where p.event_id=new.target_event_id and p.sponsorship_open and p.inbound_enabled) then raise exception 'KOMBAX_EVENT_SPONSORSHIP_NOT_AVAILABLE'; end if;
 end if;
 return new;
end $$;
drop trigger if exists trg_kombax_brand_proposal_target_guard_v224 on public.kombax_brand_proposals_v223;
create trigger trg_kombax_brand_proposal_target_guard_v224 before insert on public.kombax_brand_proposals_v223 for each row execute function public.app_kombax_brand_proposal_target_guard_v224();

revoke all on function public.app_kombax_brand_public_profile_v224(uuid) from public;
grant execute on function public.app_kombax_brand_public_profile_v224(uuid) to anon,authenticated;
revoke all on function public.app_kombax_brand_target_preferences_v224(text,uuid) from public,anon;
grant execute on function public.app_kombax_brand_target_preferences_v224(text,uuid) to authenticated;
revoke all on function public.app_kombax_brand_target_preferences_mutate_v224(text,jsonb) from public,anon;
grant execute on function public.app_kombax_brand_target_preferences_mutate_v224(text,jsonb) to authenticated;
revoke all on function public.app_kombax_brand_discovery_v224(uuid,text,text,text,text,integer) from public,anon;
grant execute on function public.app_kombax_brand_discovery_v224(uuid,text,text,text,text,integer) to authenticated;
revoke all on function public.app_kombax_brand_proposal_target_guard_v224() from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
