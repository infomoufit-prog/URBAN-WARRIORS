-- KOMBAX 20.101 R37 · Brand Business Hub RPC/API
begin;

create or replace function public.app_kombax_brand_workspace_v223(p_brand_profile_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_profile public.perfiles_kombax_directos%rowtype;
  v_settings jsonb;
  v_campaigns jsonb;
  v_proposals jsonb;
  v_team jsonb;
  v_stats jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_profile from public.perfiles_kombax_directos where id=p_brand_profile_id;
  if v_profile.id is null or v_profile.tipo<>'marca' then raise exception 'KOMBAX_BRAND_PROFILE_REQUIRED'; end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(p_brand_profile_id,'read') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if;

  select coalesce(to_jsonb(s),'{}'::jsonb) into v_settings from public.kombax_brand_profiles_v223 s where s.brand_profile_id=p_brand_profile_id;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.updated_at desc),'[]'::jsonb) into v_campaigns from public.kombax_brand_campaigns_v223 c where c.brand_profile_id=p_brand_profile_id;
  select coalesce(jsonb_agg(to_jsonb(p) order by p.updated_at desc),'[]'::jsonb) into v_proposals from public.kombax_brand_proposals_v223 p where p.brand_profile_id=p_brand_profile_id;
  select coalesce(jsonb_agg(jsonb_build_object('perfil_id',r.perfil_id,'business_role',r.business_role,'updated_at',r.updated_at) order by r.business_role,r.perfil_id),'[]'::jsonb)
    into v_team from public.kombax_brand_team_roles_v223 r where r.brand_profile_id=p_brand_profile_id;
  select jsonb_build_object(
    'campaigns_total',count(*),
    'campaigns_active',count(*) filter(where status='active'),
    'campaigns_open',count(*) filter(where status='active' and visibility='open')
  ) into v_stats from public.kombax_brand_campaigns_v223 where brand_profile_id=p_brand_profile_id;
  v_stats:=coalesce(v_stats,'{}'::jsonb)||(
    select jsonb_build_object(
      'proposals_total',count(*),
      'proposals_pending',count(*) filter(where status in ('pending','interested','in_review')),
      'proposals_accepted',count(*) filter(where status='accepted'),
      'proposals_completed',count(*) filter(where status='completed')
    ) from public.kombax_brand_proposals_v223 where brand_profile_id=p_brand_profile_id
  );

  return jsonb_build_object(
    'profile',jsonb_build_object('id',v_profile.id,'name',v_profile.nombre_publico,'verified',v_profile.verificacion_estado,'public',v_profile.publico),
    'settings',coalesce(v_settings,'{}'::jsonb),
    'campaigns',v_campaigns,
    'proposals',v_proposals,
    'team_roles',v_team,
    'analytics',v_stats,
    'privacy',jsonb_build_object('private_club_data',false,'private_fighter_weight',false,'private_finance',false),
    'version','r37-v223'
  );
end $$;

create or replace function public.app_kombax_brand_discovery_v223(
  p_brand_profile_id uuid,
  p_target_type text,
  p_query text default '',
  p_discipline text default null,
  p_territory text default null,
  p_limit integer default 30
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_limit integer:=least(100,greatest(1,coalesce(p_limit,30)));
  v_rows jsonb:='[]'::jsonb;
  v_q text:='%'||coalesce(trim(p_query),'')||'%';
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists(select 1 from public.perfiles_kombax_directos d where d.id=p_brand_profile_id and d.tipo='marca') then raise exception 'KOMBAX_BRAND_PROFILE_REQUIRED'; end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(p_brand_profile_id,'read') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if;
  if p_target_type not in ('fighter','club','event') then raise exception 'KOMBAX_BRAND_DISCOVERY_TARGET_INVALID'; end if;

  if p_target_type='fighter' then
    select coalesce(jsonb_agg(x.item order by x.name),'[]'::jsonb) into v_rows
    from (
      select d.nombre_publico as name,
        jsonb_build_object(
          'target_type','direct_profile','id',d.id,'name',d.nombre_publico,'profile_type',d.tipo,
          'location',d.ubicacion,'disciplines',coalesce(to_jsonb(d.disciplinas),'[]'::jsonb),
          'category',d.categoria,'club',d.club_declarado,'verified',d.verificacion_estado,
          'contact_mode',pref.contact_mode,'collaboration_note',pref.collaboration_note
        ) item
      from public.perfiles_kombax_directos d
      join public.kombax_brand_collaboration_preferences_v223 pref on pref.direct_profile_id=d.id
      where d.tipo='competidor' and d.publico is true
        and pref.discoverable_by_brands and pref.inbound_enabled
        and (coalesce(trim(p_query),'')='' or d.nombre_publico ilike v_q or coalesce(d.club_declarado,'') ilike v_q or coalesce(d.ubicacion,'') ilike v_q)
        and (p_discipline is null or p_discipline='' or p_discipline=any(coalesce(d.disciplinas,'{}'::text[])))
        and (p_territory is null or p_territory='' or coalesce(d.ubicacion,'') ilike '%'||p_territory||'%')
      order by d.nombre_publico limit v_limit
    ) x;
  elsif p_target_type='club' then
    select coalesce(jsonb_agg(x.item order by x.name),'[]'::jsonb) into v_rows
    from (
      select c.nombre as name,
        jsonb_build_object('target_type','club','id',c.id,'name',c.nombre,'slug',c.slug,'location',c.direccion,'website',c.web,'logo_url',c.logo_url,'verified',sp.verificado) item
      from public.clubes c
      join public.kombax_social_perfiles sp on sp.club_id=c.id and sp.sujeto_tipo='club' and sp.visible and sp.contacto_habilitado and sp.estado='activo'
      where c.activo and (coalesce(trim(p_query),'')='' or c.nombre ilike v_q or coalesce(c.direccion,'') ilike v_q)
        and (p_territory is null or p_territory='' or coalesce(c.direccion,'') ilike '%'||p_territory||'%')
      group by c.id,c.nombre,c.slug,c.direccion,c.web,c.logo_url,sp.verificado
      order by c.nombre limit v_limit
    ) x;
  else
    select coalesce(jsonb_agg(x.item order by x.starts_at asc nulls last),'[]'::jsonb) into v_rows
    from (
      select e.fecha_inicio starts_at,
        jsonb_build_object(
          'target_type','event','id',e.id,'name',e.nombre,'event_type',e.tipo,'starts_at',e.fecha_inicio,
          'location',concat_ws(', ',e.lugar_nombre,e.municipio,e.provincia,e.pais),'organizer',e.organizador_nombre,
          'poster_url',e.cartel_url,'banner_url',e.banner_url
        ) item
      from public.kombax_eventos_publicos e
      where e.publicado_en is not null and coalesce(e.estado,'')<>'cancelado'
        and (coalesce(trim(p_query),'')='' or e.nombre ilike v_q or coalesce(e.organizador_nombre,'') ilike v_q or coalesce(e.municipio,'') ilike v_q)
        and (p_territory is null or p_territory='' or concat_ws(' ',e.municipio,e.provincia,e.pais) ilike '%'||p_territory||'%')
      order by e.fecha_inicio asc nulls last limit v_limit
    ) x;
  end if;
  return jsonb_build_object('target_type',p_target_type,'items',coalesce(v_rows,'[]'::jsonb),'privacy',jsonb_build_object('public_data_only',true,'private_weight_history',false,'private_club_data',false));
end $$;

create or replace function public.app_kombax_brand_open_campaigns_v223(p_profile_id uuid default null,p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_limit integer:=least(100,greatest(1,coalesce(p_limit,50)));
  v_rows jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_profile_id is not null and not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'read') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'brand_profile_id',c.brand_profile_id,'brand_name',b.nombre_publico,'title',c.title,'campaign_type',c.campaign_type,
    'description',c.description,'territory',c.territory,'disciplines',to_jsonb(c.disciplines),'audience_types',to_jsonb(c.audience_types),
    'compensation_type',c.compensation_type,'compensation_summary',c.compensation_summary,'conditions_summary',c.conditions_summary,
    'starts_at',c.starts_at,'ends_at',c.ends_at
  ) order by c.updated_at desc),'[]'::jsonb) into v_rows
  from public.kombax_brand_campaigns_v223 c
  join public.perfiles_kombax_directos b on b.id=c.brand_profile_id and b.tipo='marca' and b.publico is true
  where c.status='active' and c.visibility='open'
    and (c.starts_at is null or c.starts_at<=now()) and (c.ends_at is null or c.ends_at>=now())
    and (p_profile_id is null or not exists(select 1 from public.kombax_brand_proposals_v223 p where p.campaign_id=c.id and p.target_direct_profile_id=p_profile_id and p.status<>'withdrawn'))
  limit v_limit;
  return coalesce(v_rows,'[]'::jsonb);
end $$;

create or replace function public.app_kombax_brand_collaboration_preferences_v223(p_profile_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_row jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'read') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED'; end if;
  select coalesce(to_jsonb(p),'{}'::jsonb) into v_row from public.kombax_brand_collaboration_preferences_v223 p where p.direct_profile_id=p_profile_id;
  return coalesce(v_row,'{}'::jsonb);
end $$;

create or replace function public.app_kombax_brand_inbox_v223(p_profile_id uuid,p_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_rows jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'read') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',p.id,'brand_profile_id',p.brand_profile_id,'brand_name',b.nombre_publico,'campaign_id',p.campaign_id,'campaign_title',c.title,
    'status',p.status,'source',p.source,'message',p.message,'terms_summary',p.terms_summary,'response_note',p.response_note,'created_at',p.created_at,'updated_at',p.updated_at
  ) order by p.updated_at desc),'[]'::jsonb) into v_rows
  from public.kombax_brand_proposals_v223 p
  join public.perfiles_kombax_directos b on b.id=p.brand_profile_id
  left join public.kombax_brand_campaigns_v223 c on c.id=p.campaign_id
  where p.target_type='direct_profile' and p.target_direct_profile_id=p_profile_id
  limit least(200,greatest(1,coalesce(p_limit,100)));
  return coalesce(v_rows,'[]'::jsonb);
end $$;

create or replace function public.app_kombax_brand_mutate_v223(p_operation text,p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_brand uuid;
  v_id uuid;
  v_campaign public.kombax_brand_campaigns_v223%rowtype;
  v_prop public.kombax_brand_proposals_v223%rowtype;
  v_before jsonb;
  v_target_type text;
  v_target_profile uuid;
  v_target_club uuid;
  v_target_event uuid;
  v_status text;
  v_profile_type text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;

  if p_operation='brand.settings.save' then
    v_brand:=(p_payload->>'brand_profile_id')::uuid;
    if not exists(select 1 from public.perfiles_kombax_directos where id=v_brand and tipo='marca') then raise exception 'KOMBAX_BRAND_PROFILE_REQUIRED'; end if;
    if not public.app_kombax_puede_gestionar_perfil_v070(v_brand,'edit') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if;
    insert into public.kombax_brand_profiles_v223(brand_profile_id,sector,territories,disciplines,collaboration_open,inbound_proposals,public_business_summary,updated_by,updated_at)
    values(v_brand,nullif(trim(p_payload->>'sector'),''),coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'territories','[]'::jsonb))),'{}'::text[]),coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'disciplines','[]'::jsonb))),'{}'::text[]),coalesce((p_payload->>'collaboration_open')::boolean,false),coalesce((p_payload->>'inbound_proposals')::boolean,true),nullif(trim(p_payload->>'public_business_summary'),''),v_uid,now())
    on conflict(brand_profile_id) do update set sector=excluded.sector,territories=excluded.territories,disciplines=excluded.disciplines,collaboration_open=excluded.collaboration_open,inbound_proposals=excluded.inbound_proposals,public_business_summary=excluded.public_business_summary,updated_by=v_uid,updated_at=now();
    insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,after_state) values(v_brand,v_uid,p_operation,'brand',v_brand,p_payload);
    return jsonb_build_object('ok',true,'brand_profile_id',v_brand);

  elsif p_operation='campaign.save' then
    v_brand:=(p_payload->>'brand_profile_id')::uuid;
    if not public.app_kombax_puede_gestionar_perfil_v070(v_brand,'edit') or not exists(select 1 from public.perfiles_kombax_directos where id=v_brand and tipo='marca') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if;
    if coalesce(trim(p_payload->>'title'),'')='' then raise exception 'KOMBAX_CAMPAIGN_TITLE_REQUIRED'; end if;
    v_id:=nullif(p_payload->>'campaign_id','')::uuid;
    if v_id is null then
      insert into public.kombax_brand_campaigns_v223(brand_profile_id,title,campaign_type,visibility,status,description,territory,disciplines,audience_types,compensation_type,compensation_summary,conditions_summary,starts_at,ends_at,created_by)
      values(v_brand,trim(p_payload->>'title'),coalesce(nullif(p_payload->>'campaign_type',''),'other'),coalesce(nullif(p_payload->>'visibility',''),'private'),coalesce(nullif(p_payload->>'status',''),'draft'),nullif(trim(p_payload->>'description'),''),nullif(trim(p_payload->>'territory'),''),coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'disciplines','[]'::jsonb))),'{}'::text[]),coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'audience_types','[]'::jsonb))),'{}'::text[]),nullif(p_payload->>'compensation_type',''),nullif(trim(p_payload->>'compensation_summary'),''),nullif(trim(p_payload->>'conditions_summary'),''),nullif(p_payload->>'starts_at','')::timestamptz,nullif(p_payload->>'ends_at','')::timestamptz,v_uid) returning id into v_id;
    else
      select to_jsonb(c) into v_before from public.kombax_brand_campaigns_v223 c where c.id=v_id and c.brand_profile_id=v_brand;
      if v_before is null then raise exception 'KOMBAX_CAMPAIGN_NOT_FOUND'; end if;
      update public.kombax_brand_campaigns_v223 set title=trim(p_payload->>'title'),campaign_type=coalesce(nullif(p_payload->>'campaign_type',''),campaign_type),visibility=coalesce(nullif(p_payload->>'visibility',''),visibility),status=coalesce(nullif(p_payload->>'status',''),status),description=nullif(trim(p_payload->>'description'),''),territory=nullif(trim(p_payload->>'territory'),''),disciplines=coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'disciplines','[]'::jsonb))),disciplines),audience_types=coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'audience_types','[]'::jsonb))),audience_types),compensation_type=nullif(p_payload->>'compensation_type',''),compensation_summary=nullif(trim(p_payload->>'compensation_summary'),''),conditions_summary=nullif(trim(p_payload->>'conditions_summary'),''),starts_at=nullif(p_payload->>'starts_at','')::timestamptz,ends_at=nullif(p_payload->>'ends_at','')::timestamptz,updated_at=now() where id=v_id;
    end if;
    insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,before_state,after_state) values(v_brand,v_uid,p_operation,'campaign',v_id,v_before,p_payload);
    return jsonb_build_object('ok',true,'campaign_id',v_id);

  elsif p_operation='campaign.status' then
    v_id:=(p_payload->>'campaign_id')::uuid; v_status:=p_payload->>'status';
    select * into v_campaign from public.kombax_brand_campaigns_v223 where id=v_id;
    if v_campaign.id is null then raise exception 'KOMBAX_CAMPAIGN_NOT_FOUND'; end if;
    if not public.app_kombax_puede_gestionar_perfil_v070(v_campaign.brand_profile_id,'edit') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if;
    if v_status not in ('draft','active','paused','closed') then raise exception 'KOMBAX_CAMPAIGN_STATUS_INVALID'; end if;
    update public.kombax_brand_campaigns_v223 set status=v_status,updated_at=now() where id=v_id;
    insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,before_state,after_state) values(v_campaign.brand_profile_id,v_uid,p_operation,'campaign',v_id,to_jsonb(v_campaign),jsonb_build_object('status',v_status));
    return jsonb_build_object('ok',true,'campaign_id',v_id,'status',v_status);

  elsif p_operation='proposal.send' then
    v_brand:=(p_payload->>'brand_profile_id')::uuid;
    if not public.app_kombax_puede_gestionar_perfil_v070(v_brand,'edit') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if;
    if not exists(select 1 from public.perfiles_kombax_directos where id=v_brand and tipo='marca') then raise exception 'KOMBAX_BRAND_PROFILE_REQUIRED'; end if;
    v_target_type:=p_payload->>'target_type';
    v_target_profile:=nullif(p_payload->>'target_direct_profile_id','')::uuid;
    v_target_club:=nullif(p_payload->>'target_club_id','')::uuid;
    v_target_event:=nullif(p_payload->>'target_event_id','')::uuid;
    if nullif(p_payload->>'campaign_id','') is not null and not exists(select 1 from public.kombax_brand_campaigns_v223 where id=(p_payload->>'campaign_id')::uuid and brand_profile_id=v_brand) then raise exception 'KOMBAX_CAMPAIGN_NOT_FOUND'; end if;
    if v_target_type:='direct_profile' then
      if not exists(select 1 from public.kombax_brand_collaboration_preferences_v223 pref join public.perfiles_kombax_directos d on d.id=pref.direct_profile_id where pref.direct_profile_id=v_target_profile and pref.discoverable_by_brands and pref.inbound_enabled and d.publico is true) then raise exception 'KOMBAX_COLLABORATION_NOT_AVAILABLE'; end if;
    elsif v_target_type:='club' then
      if not exists(select 1 from public.kombax_social_perfiles sp where sp.club_id=v_target_club and sp.sujeto_tipo='club' and sp.visible and sp.contacto_habilitado and sp.estado='activo') then raise exception 'KOMBAX_CLUB_CONTACT_NOT_AVAILABLE'; end if;
    elsif v_target_type:='event' then
      if not exists(select 1 from public.kombax_eventos_publicos e where e.id=v_target_event and e.publicado_en is not null) then raise exception 'KOMBAX_EVENT_NOT_PUBLIC'; end if;
    else raise exception 'KOMBAX_PROPOSAL_TARGET_INVALID'; end if;
    insert into public.kombax_brand_proposals_v223(brand_profile_id,campaign_id,target_type,target_direct_profile_id,target_club_id,target_event_id,source,status,message,terms_summary,created_by)
    values(v_brand,nullif(p_payload->>'campaign_id','')::uuid,v_target_type,v_target_profile,v_target_club,v_target_event,'brand_invite','pending',nullif(trim(p_payload->>'message'),''),nullif(trim(p_payload->>'terms_summary'),''),v_uid) returning id into v_id;
    insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,after_state) values(v_brand,v_uid,p_operation,'proposal',v_id,p_payload);
    return jsonb_build_object('ok',true,'proposal_id',v_id,'status','pending');

  elsif p_operation='proposal.respond' then
    v_id:=(p_payload->>'proposal_id')::uuid; v_status:=p_payload->>'status';
    select * into v_prop from public.kombax_brand_proposals_v223 where id=v_id;
    if v_prop.id is null then raise exception 'KOMBAX_PROPOSAL_NOT_FOUND'; end if;
    if v_status not in ('interested','in_review','accepted','declined','completed') then raise exception 'KOMBAX_PROPOSAL_STATUS_INVALID'; end if;
    if v_prop.target_type='direct_profile' then
      if not public.app_kombax_puede_gestionar_perfil_v070(v_prop.target_direct_profile_id,'edit') then raise exception 'KOMBAX_PROPOSAL_TARGET_MANAGE_REQUIRED'; end if;
    elsif v_prop.target_type='club' then
      if not public.tiene_rol_club(v_prop.target_club_id,'direccion','secretaria','comunicacion') then raise exception 'KOMBAX_PROPOSAL_TARGET_MANAGE_REQUIRED'; end if;
    elsif v_prop.target_type='event' then
      if not public.app_kombax_evento_puede_gestionar_v160(v_prop.target_event_id) then raise exception 'KOMBAX_PROPOSAL_TARGET_MANAGE_REQUIRED'; end if;
    end if;
    update public.kombax_brand_proposals_v223 set status=v_status,response_note=nullif(trim(p_payload->>'response_note'),''),responded_by=v_uid,responded_at=now(),updated_at=now() where id=v_id;
    insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,before_state,after_state) values(v_prop.brand_profile_id,v_uid,p_operation,'proposal',v_id,to_jsonb(v_prop),jsonb_build_object('status',v_status,'response_note',p_payload->>'response_note'));
    return jsonb_build_object('ok',true,'proposal_id',v_id,'status',v_status);

  elsif p_operation='proposal.brand_status' then
    v_id:=(p_payload->>'proposal_id')::uuid; v_status:=p_payload->>'status';
    select * into v_prop from public.kombax_brand_proposals_v223 where id=v_id;
    if v_prop.id is null then raise exception 'KOMBAX_PROPOSAL_NOT_FOUND'; end if;
    if not public.app_kombax_puede_gestionar_perfil_v070(v_prop.brand_profile_id,'edit') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if;
    if v_status not in ('pending','in_review','accepted','declined','completed') then raise exception 'KOMBAX_PROPOSAL_STATUS_INVALID'; end if;
    update public.kombax_brand_proposals_v223 set status=v_status,updated_at=now() where id=v_id;
    insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,before_state,after_state) values(v_prop.brand_profile_id,v_uid,p_operation,'proposal',v_id,to_jsonb(v_prop),jsonb_build_object('status',v_status));
    return jsonb_build_object('ok',true,'proposal_id',v_id,'status',v_status);

  elsif p_operation='proposal.withdraw' then
    v_id:=(p_payload->>'proposal_id')::uuid;
    select * into v_prop from public.kombax_brand_proposals_v223 where id=v_id;
    if v_prop.id is null then raise exception 'KOMBAX_PROPOSAL_NOT_FOUND'; end if;
    if not public.app_kombax_puede_gestionar_perfil_v070(v_prop.brand_profile_id,'edit') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if;
    update public.kombax_brand_proposals_v223 set status='withdrawn',updated_at=now() where id=v_id;
    insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,before_state,after_state) values(v_prop.brand_profile_id,v_uid,p_operation,'proposal',v_id,to_jsonb(v_prop),jsonb_build_object('status','withdrawn'));
    return jsonb_build_object('ok',true,'proposal_id',v_id,'status','withdrawn');

  elsif p_operation='collaboration.preferences.save' then
    v_target_profile:=(p_payload->>'direct_profile_id')::uuid;
    if not public.app_kombax_puede_gestionar_perfil_v070(v_target_profile,'edit') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED'; end if;
    select tipo into v_profile_type from public.perfiles_kombax_directos where id=v_target_profile;
    if v_profile_type not in ('competidor','profesional') then raise exception 'KOMBAX_COLLABORATION_PROFILE_TYPE_INVALID'; end if;
    insert into public.kombax_brand_collaboration_preferences_v223(direct_profile_id,discoverable_by_brands,inbound_enabled,categories,contact_mode,collaboration_note,updated_by,updated_at)
    values(v_target_profile,coalesce((p_payload->>'discoverable_by_brands')::boolean,false),coalesce((p_payload->>'inbound_enabled')::boolean,false),coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'categories','[]'::jsonb))),'{}'::text[]),coalesce(nullif(p_payload->>'contact_mode',''),'profile'),nullif(trim(p_payload->>'collaboration_note'),''),v_uid,now())
    on conflict(direct_profile_id) do update set discoverable_by_brands=excluded.discoverable_by_brands,inbound_enabled=excluded.inbound_enabled,categories=excluded.categories,contact_mode=excluded.contact_mode,collaboration_note=excluded.collaboration_note,updated_by=v_uid,updated_at=now();
    return jsonb_build_object('ok',true,'direct_profile_id',v_target_profile);

  elsif p_operation='campaign.apply' then
    v_id:=(p_payload->>'campaign_id')::uuid; v_target_profile:=(p_payload->>'direct_profile_id')::uuid;
    if not public.app_kombax_puede_gestionar_perfil_v070(v_target_profile,'edit') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED'; end if;
    if not exists(select 1 from public.kombax_brand_collaboration_preferences_v223 where direct_profile_id=v_target_profile and discoverable_by_brands and inbound_enabled) then raise exception 'KOMBAX_COLLABORATION_OPT_IN_REQUIRED'; end if;
    select * into v_campaign from public.kombax_brand_campaigns_v223 where id=v_id and status='active' and visibility='open' and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>=now());
    if v_campaign.id is null then raise exception 'KOMBAX_OPEN_CAMPAIGN_NOT_AVAILABLE'; end if;
    if exists(select 1 from public.kombax_brand_proposals_v223 where campaign_id=v_id and target_direct_profile_id=v_target_profile and status<>'withdrawn') then raise exception 'KOMBAX_CAMPAIGN_ALREADY_APPLIED'; end if;
    insert into public.kombax_brand_proposals_v223(brand_profile_id,campaign_id,target_type,target_direct_profile_id,source,status,message,created_by)
    values(v_campaign.brand_profile_id,v_id,'direct_profile',v_target_profile,'open_campaign_application','interested',nullif(trim(p_payload->>'message'),''),v_uid) returning id into v_id;
    insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,after_state) values(v_campaign.brand_profile_id,v_uid,p_operation,'proposal',v_id,p_payload);
    return jsonb_build_object('ok',true,'proposal_id',v_id,'status','interested');

  elsif p_operation='team.role.set' then
    v_brand:=(p_payload->>'brand_profile_id')::uuid; v_target_profile:=(p_payload->>'perfil_id')::uuid;
    if not public.app_kombax_puede_gestionar_perfil_v070(v_brand,'admin') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if;
    if not exists(select 1 from public.kombax_perfil_gestores g where g.perfil_directo_id=v_brand and g.perfil_id=v_target_profile and g.estado='activo') then raise exception 'KOMBAX_BRAND_MANAGER_REQUIRED'; end if;
    insert into public.kombax_brand_team_roles_v223(brand_profile_id,perfil_id,business_role,updated_by,updated_at)
    values(v_brand,v_target_profile,p_payload->>'business_role',v_uid,now()) on conflict(brand_profile_id,perfil_id) do update set business_role=excluded.business_role,updated_by=v_uid,updated_at=now();
    insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,after_state) values(v_brand,v_uid,p_operation,'team_member',v_target_profile,p_payload);
    return jsonb_build_object('ok',true,'perfil_id',v_target_profile,'business_role',p_payload->>'business_role');
  else
    raise exception 'KOMBAX_BRAND_OPERATION_UNSUPPORTED';
  end if;
end $$;

revoke all on function public.app_kombax_brand_workspace_v223(uuid) from public,anon;
revoke all on function public.app_kombax_brand_discovery_v223(uuid,text,text,text,text,integer) from public,anon;
revoke all on function public.app_kombax_brand_open_campaigns_v223(uuid,integer) from public,anon;
revoke all on function public.app_kombax_brand_collaboration_preferences_v223(uuid) from public,anon;
revoke all on function public.app_kombax_brand_inbox_v223(uuid,integer) from public,anon;
revoke all on function public.app_kombax_brand_mutate_v223(text,jsonb) from public,anon;
grant execute on function public.app_kombax_brand_workspace_v223(uuid) to authenticated;
grant execute on function public.app_kombax_brand_discovery_v223(uuid,text,text,text,text,integer) to authenticated;
grant execute on function public.app_kombax_brand_open_campaigns_v223(uuid,integer) to authenticated;
grant execute on function public.app_kombax_brand_collaboration_preferences_v223(uuid) to authenticated;
grant execute on function public.app_kombax_brand_inbox_v223(uuid,integer) to authenticated;
grant execute on function public.app_kombax_brand_mutate_v223(text,jsonb) to authenticated;

notify pgrst,'reload schema';
commit;
