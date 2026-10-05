-- R120: context-bound operational planning and administrative finances.
-- Existing commercial catalogue, subscriptions, pilot benefits and payment records are unchanged.
begin;
create table public.kombax_profile_operations_r120(
 id uuid primary key default gen_random_uuid(),
 profile_id uuid not null references public.perfiles_kombax_directos(id),
 kind text not null check(kind in ('income','expense','refund','task')),
 title text not null check(length(title) between 2 and 180),
 category text not null default '' check(length(category)<=80),
 amount_minor bigint not null default 0 check(amount_minor between 0 and 100000000000),
 currency text not null default 'EUR' check(currency in ('EUR','USD','GBP')),
 occurred_on date not null default current_date,
 due_on date,
 state text not null default 'open' check(state in ('open','done','cancelled')),
 campaign_id uuid references public.kombax_brand_campaigns_v223(id),
 notes text not null default '' check(length(notes)<=2000),
 created_by uuid not null,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check(kind='task' or amount_minor>0),check(kind='task' or due_on is null)
);
create index kombax_profile_operations_context_idx on public.kombax_profile_operations_r120(profile_id,occurred_on desc,id);
create table public.kombax_profile_operations_requests_r120(
 request_id uuid primary key,actor_id uuid not null,operation text not null,payload jsonb not null,response jsonb not null,created_at timestamptz not null default now()
);
alter table public.kombax_profile_operations_r120 enable row level security;
alter table public.kombax_profile_operations_requests_r120 enable row level security;
revoke all on public.kombax_profile_operations_r120,public.kombax_profile_operations_requests_r120 from public,anon,authenticated;

create function public.app_kombax_profile_operations_access_r120(p_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d public.perfiles_kombax_directos%rowtype;plan text;can_finance boolean;can_edit boolean;can_operate boolean;advanced boolean;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 select * into d from public.perfiles_kombax_directos where id=p_profile_id;
 if d.id is null or d.tipo not in ('marca','federacion','profesional') or d.estado<>'activo' then raise exception 'PROFILE_OPERATIONS_UNAVAILABLE';end if;
 if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'read') then raise exception 'PROFILE_ACCESS_REQUIRED';end if;
 can_finance:=public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'admin');
 can_edit:=public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'edit');
 plan:=kombax_commercial.active_plan_r64('direct_profile',p_profile_id);
 can_operate:=d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited') and
  case d.tipo when 'marca' then coalesce(plan in ('brand_start','brand_growth','brand_enterprise','marca_profesional'),false)
  when 'federacion' then coalesce(plan in ('federation','federation_partner','federacion_institucional'),false)
  else exists(select 1 from public.app_kombax_profile_capabilities_v196(p_profile_id) c where c.capacidad_clave='events.public.organize') end;
 advanced:=can_operate and case when d.tipo='marca' then coalesce(plan in ('brand_growth','brand_enterprise','marca_profesional'),false) else true end;
 return jsonb_build_object('profile_id',d.id,'type',d.tipo,'name',d.nombre_publico,'plan',plan,
   'read_finance',can_finance,'write_finance',can_finance and can_operate,
   'edit_tasks',can_edit and can_operate,'advanced',advanced and can_edit,'active_service',can_operate);
end $$;

create function public.app_kombax_profile_operations_workspace_r120(p_profile_id uuid,p_kind text default 'finance',p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a jsonb;rows jsonb;totals jsonb;v_count integer;
begin
 a:=public.app_kombax_profile_operations_access_r120(p_profile_id);
 if p_kind not in ('finance','tasks') then raise exception 'OPERATION_KIND_INVALID';end if;
 if (p_kind='finance' and not (a->>'read_finance')::boolean) or
    (p_kind='tasks' and not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'edit')) then raise exception 'PRIVATE_OPERATIONS_REQUIRED';end if;
 select count(*) into v_count from public.kombax_profile_operations_r120 o where o.profile_id=p_profile_id and (case when p_kind='tasks' then o.kind='task' else o.kind<>'task' end);
 select coalesce(jsonb_agg(to_jsonb(q) order by q.occurred_on desc,q.created_at desc),'[]'::jsonb) into rows from
  (select * from public.kombax_profile_operations_r120 o where o.profile_id=p_profile_id and
    (case when p_kind='tasks' then o.kind='task' else o.kind<>'task' end)
    order by o.occurred_on desc,o.created_at desc limit 10 offset least(100000,greatest(0,coalesce(p_offset,0)))) q;
 select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into totals from
  (select currency,coalesce(sum(amount_minor) filter(where kind='income'),0) income_minor,
    coalesce(sum(amount_minor) filter(where kind='expense'),0) expense_minor,
    coalesce(sum(amount_minor) filter(where kind='refund'),0) refund_minor
   from public.kombax_profile_operations_r120 where profile_id=p_profile_id and state='done' and kind<>'task' group by currency) q;
 return jsonb_build_object('access',a,'rows',rows,'totals',case when p_kind='finance' then totals else '[]'::jsonb end,'total',v_count,'offset',greatest(0,coalesce(p_offset,0)),'page_size',10);
end $$;

create function public.app_kombax_profile_operations_mutate_r120(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a jsonb;pid uuid;rid uuid;r public.kombax_profile_operations_r120%rowtype;old public.kombax_profile_operations_requests_r120%rowtype;out jsonb;kind text;st text;amt numeric;cid uuid;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 if p_request_id is null or p_payload is null then raise exception 'REQUEST_REQUIRED';end if;
 pid:=(p_payload->>'profile_id')::uuid;
 a:=public.app_kombax_profile_operations_access_r120(pid);
 if not public.app_kombax_puede_gestionar_perfil_v070(pid,'edit') then raise exception 'PRIVATE_OPERATIONS_REQUIRED';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,120));
 select * into old from public.kombax_profile_operations_requests_r120 where request_id=p_request_id;
 if found then
  if old.actor_id<>auth.uid() or old.operation<>p_operation or old.payload<>p_payload then raise exception 'REQUEST_ID_REUSED';end if;
  return old.response;
 end if;
 if p_operation='operation.create' then
  kind:=p_payload->>'kind';st:=case when kind='task' then 'open' else 'done' end;
  if kind is null or kind not in ('income','expense','refund','task') then raise exception 'OPERATION_KIND_INVALID';end if;
  if kind<>'task' and not (a->>'write_finance')::boolean then raise exception 'VERIFIED_ACTIVE_SERVICE_AND_FINANCE_REQUIRED';end if;
  if kind='task' and not (a->>'edit_tasks')::boolean then raise exception 'VERIFIED_ACTIVE_SERVICE_REQUIRED';end if;
  cid:=nullif(p_payload->>'campaign_id','')::uuid;
  if cid is not null and not exists(select 1 from public.kombax_brand_campaigns_v223 c where c.id=cid and c.brand_profile_id=pid) then raise exception 'CAMPAIGN_CONTEXT_MISMATCH';end if;
  if kind='task' and coalesce(p_payload->>'category','') in ('ambassadors','attribution') and not (a->>'advanced')::boolean then raise exception 'ADVANCED_SERVICE_REQUIRED';end if;
  amt:=coalesce(nullif(p_payload->>'amount_minor','')::numeric,0);
  if amt<>trunc(amt) or amt<0 or amt>100000000000 then raise exception 'AMOUNT_INVALID';end if;
  insert into public.kombax_profile_operations_r120(profile_id,kind,title,category,amount_minor,currency,occurred_on,due_on,state,campaign_id,notes,created_by)
   values(pid,kind,btrim(p_payload->>'title'),coalesce(p_payload->>'category',''),case when kind='task' then 0 else amt::bigint end,
    coalesce(nullif(p_payload->>'currency',''),'EUR'),coalesce(nullif(p_payload->>'occurred_on','')::date,current_date),
    case when kind='task' then nullif(p_payload->>'due_on','')::date else null end,st,cid,coalesce(p_payload->>'notes',''),auth.uid()) returning * into r;
 elsif p_operation='operation.state' then
  rid:=(p_payload->>'id')::uuid;st:=p_payload->>'state';
  select * into r from public.kombax_profile_operations_r120 where id=rid and profile_id=pid for update;
  if r.id is null then raise exception 'OPERATION_NOT_FOUND';end if;
  if st is null or st not in ('open','done','cancelled') then raise exception 'OPERATION_STATE_INVALID';end if;
  if r.kind<>'task' then
   if not (a->>'read_finance')::boolean or st<>'cancelled' or r.state='cancelled' then raise exception 'FINANCE_CORRECTION_ONLY';end if;
  elsif st<>'cancelled' and not (a->>'edit_tasks')::boolean then raise exception 'VERIFIED_ACTIVE_SERVICE_REQUIRED';end if;
  update public.kombax_profile_operations_r120 set state=st,updated_at=now() where id=r.id returning * into r;
 else raise exception 'OPERATION_UNKNOWN';end if;
 insert into public.kombax_verificacion_eventos(perfil_directo_id,actor_perfil_id,evento,detalle)
   values(pid,auth.uid(),p_operation,jsonb_build_object('id',r.id,'kind',r.kind,'state',r.state,'request_id',p_request_id));
 out:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(r));
 insert into public.kombax_profile_operations_requests_r120 values(p_request_id,auth.uid(),p_operation,p_payload,out,now());
 return out;
end $$;
revoke all on function public.app_kombax_profile_operations_access_r120(uuid),public.app_kombax_profile_operations_workspace_r120(uuid,text,integer),public.app_kombax_profile_operations_mutate_r120(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_profile_operations_access_r120(uuid),public.app_kombax_profile_operations_workspace_r120(uuid,text,integer),public.app_kombax_profile_operations_mutate_r120(text,jsonb,uuid) to authenticated;
CREATE OR REPLACE FUNCTION public.app_kombax_brand_mutate_legacy_r120(p_operation text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid(); v_brand uuid; v_id uuid; v_campaign public.kombax_brand_campaigns_v223%rowtype; v_prop public.kombax_brand_proposals_v223%rowtype; v_before jsonb; v_target_type text; v_target_profile uuid; v_target_club uuid; v_target_event uuid; v_status text; v_profile_type text;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_operation='brand.settings.save' then
  v_brand:=(p_payload->>'brand_profile_id')::uuid; if not exists(select 1 from public.perfiles_kombax_directos where id=v_brand and tipo='marca') then raise exception 'KOMBAX_BRAND_PROFILE_REQUIRED'; end if; if not public.app_kombax_puede_gestionar_perfil_v070(v_brand,'edit') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if;
  insert into public.kombax_brand_profiles_v223(brand_profile_id,sector,territories,disciplines,collaboration_open,inbound_proposals,public_business_summary,updated_by,updated_at) values(v_brand,nullif(trim(p_payload->>'sector'),''),coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'territories','[]'::jsonb))),'{}'::text[]),coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'disciplines','[]'::jsonb))),'{}'::text[]),coalesce((p_payload->>'collaboration_open')::boolean,false),coalesce((p_payload->>'inbound_proposals')::boolean,true),nullif(trim(p_payload->>'public_business_summary'),''),v_uid,now()) on conflict(brand_profile_id) do update set sector=excluded.sector,territories=excluded.territories,disciplines=excluded.disciplines,collaboration_open=excluded.collaboration_open,inbound_proposals=excluded.inbound_proposals,public_business_summary=excluded.public_business_summary,updated_by=v_uid,updated_at=now();
  insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,after_state) values(v_brand,v_uid,p_operation,'brand',v_brand,p_payload); return jsonb_build_object('ok',true,'brand_profile_id',v_brand);
 elsif p_operation='campaign.save' then
  v_brand:=(p_payload->>'brand_profile_id')::uuid; if not public.app_kombax_puede_gestionar_perfil_v070(v_brand,'edit') or not exists(select 1 from public.perfiles_kombax_directos where id=v_brand and tipo='marca') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if; if coalesce(trim(p_payload->>'title'),'')='' then raise exception 'KOMBAX_CAMPAIGN_TITLE_REQUIRED'; end if; v_id:=nullif(p_payload->>'campaign_id','')::uuid;
  if v_id is null then insert into public.kombax_brand_campaigns_v223(brand_profile_id,title,campaign_type,visibility,status,description,territory,disciplines,audience_types,compensation_type,compensation_summary,conditions_summary,starts_at,ends_at,created_by) values(v_brand,trim(p_payload->>'title'),coalesce(nullif(p_payload->>'campaign_type',''),'other'),coalesce(nullif(p_payload->>'visibility',''),'private'),coalesce(nullif(p_payload->>'status',''),'draft'),nullif(trim(p_payload->>'description'),''),nullif(trim(p_payload->>'territory'),''),coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'disciplines','[]'::jsonb))),'{}'::text[]),coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'audience_types','[]'::jsonb))),'{}'::text[]),nullif(p_payload->>'compensation_type',''),nullif(trim(p_payload->>'compensation_summary'),''),nullif(trim(p_payload->>'conditions_summary'),''),nullif(p_payload->>'starts_at','')::timestamptz,nullif(p_payload->>'ends_at','')::timestamptz,v_uid) returning id into v_id;
  else select to_jsonb(c) into v_before from public.kombax_brand_campaigns_v223 c where c.id=v_id and c.brand_profile_id=v_brand; if v_before is null then raise exception 'KOMBAX_CAMPAIGN_NOT_FOUND'; end if; update public.kombax_brand_campaigns_v223 set title=trim(p_payload->>'title'),campaign_type=coalesce(nullif(p_payload->>'campaign_type',''),campaign_type),visibility=coalesce(nullif(p_payload->>'visibility',''),visibility),status=coalesce(nullif(p_payload->>'status',''),status),description=nullif(trim(p_payload->>'description'),''),territory=nullif(trim(p_payload->>'territory'),''),disciplines=coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'disciplines','[]'::jsonb))),disciplines),audience_types=coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'audience_types','[]'::jsonb))),audience_types),compensation_type=nullif(p_payload->>'compensation_type',''),compensation_summary=nullif(trim(p_payload->>'compensation_summary'),''),conditions_summary=nullif(trim(p_payload->>'conditions_summary'),''),starts_at=nullif(p_payload->>'starts_at','')::timestamptz,ends_at=nullif(p_payload->>'ends_at','')::timestamptz,updated_at=now() where id=v_id; end if;
  insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,before_state,after_state) values(v_brand,v_uid,p_operation,'campaign',v_id,v_before,p_payload); return jsonb_build_object('ok',true,'campaign_id',v_id);
 elsif p_operation='campaign.status' then
  v_id:=(p_payload->>'campaign_id')::uuid; v_status:=p_payload->>'status'; select * into v_campaign from public.kombax_brand_campaigns_v223 where id=v_id; if v_campaign.id is null then raise exception 'KOMBAX_CAMPAIGN_NOT_FOUND'; end if; if not public.app_kombax_puede_gestionar_perfil_v070(v_campaign.brand_profile_id,'edit') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if; if v_status not in ('draft','active','paused','closed') then raise exception 'KOMBAX_CAMPAIGN_STATUS_INVALID'; end if; update public.kombax_brand_campaigns_v223 set status=v_status,updated_at=now() where id=v_id; insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,before_state,after_state) values(v_campaign.brand_profile_id,v_uid,p_operation,'campaign',v_id,to_jsonb(v_campaign),jsonb_build_object('status',v_status)); return jsonb_build_object('ok',true,'campaign_id',v_id,'status',v_status);
 elsif p_operation='proposal.send' then
  v_brand:=(p_payload->>'brand_profile_id')::uuid; if not public.app_kombax_puede_gestionar_perfil_v070(v_brand,'edit') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if; if not exists(select 1 from public.perfiles_kombax_directos where id=v_brand and tipo='marca') then raise exception 'KOMBAX_BRAND_PROFILE_REQUIRED'; end if; v_target_type:=p_payload->>'target_type'; v_target_profile:=nullif(p_payload->>'target_direct_profile_id','')::uuid; v_target_club:=nullif(p_payload->>'target_club_id','')::uuid; v_target_event:=nullif(p_payload->>'target_event_id','')::uuid; if nullif(p_payload->>'campaign_id','') is not null and not exists(select 1 from public.kombax_brand_campaigns_v223 where id=(p_payload->>'campaign_id')::uuid and brand_profile_id=v_brand) then raise exception 'KOMBAX_CAMPAIGN_NOT_FOUND'; end if;
  if v_target_type='direct_profile' then if not exists(select 1 from public.kombax_brand_collaboration_preferences_v223 pref join public.perfiles_kombax_directos d on d.id=pref.direct_profile_id where pref.direct_profile_id=v_target_profile and pref.discoverable_by_brands and pref.inbound_enabled and d.publico is true) then raise exception 'KOMBAX_COLLABORATION_NOT_AVAILABLE'; end if; elsif v_target_type='club' then if not exists(select 1 from public.kombax_social_perfiles sp where sp.club_id=v_target_club and sp.sujeto_tipo='club' and sp.visible and sp.contacto_habilitado and sp.estado='activo') then raise exception 'KOMBAX_CLUB_CONTACT_NOT_AVAILABLE'; end if; elsif v_target_type='event' then if not exists(select 1 from public.kombax_eventos_publicos e where e.id=v_target_event and e.publicado_en is not null) then raise exception 'KOMBAX_EVENT_NOT_PUBLIC'; end if; else raise exception 'KOMBAX_PROPOSAL_TARGET_INVALID'; end if;
  insert into public.kombax_brand_proposals_v223(brand_profile_id,campaign_id,target_type,target_direct_profile_id,target_club_id,target_event_id,source,status,message,terms_summary,created_by) values(v_brand,nullif(p_payload->>'campaign_id','')::uuid,v_target_type,v_target_profile,v_target_club,v_target_event,'brand_invite','pending',nullif(trim(p_payload->>'message'),''),nullif(trim(p_payload->>'terms_summary'),''),v_uid) returning id into v_id; insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,after_state) values(v_brand,v_uid,p_operation,'proposal',v_id,p_payload); return jsonb_build_object('ok',true,'proposal_id',v_id,'status','pending');
 elsif p_operation='proposal.respond' then
  v_id:=(p_payload->>'proposal_id')::uuid; v_status:=p_payload->>'status'; select * into v_prop from public.kombax_brand_proposals_v223 where id=v_id; if v_prop.id is null then raise exception 'KOMBAX_PROPOSAL_NOT_FOUND'; end if; if v_status not in ('interested','in_review','accepted','declined','completed') then raise exception 'KOMBAX_PROPOSAL_STATUS_INVALID'; end if; if v_prop.target_type='direct_profile' then if not public.app_kombax_puede_gestionar_perfil_v070(v_prop.target_direct_profile_id,'edit') then raise exception 'KOMBAX_PROPOSAL_TARGET_MANAGE_REQUIRED'; end if; elsif v_prop.target_type='club' then if not public.tiene_rol_club(v_prop.target_club_id,'direccion','secretaria','comunicacion') then raise exception 'KOMBAX_PROPOSAL_TARGET_MANAGE_REQUIRED'; end if; elsif v_prop.target_type='event' then if not public.app_kombax_evento_puede_gestionar_v160(v_prop.target_event_id) then raise exception 'KOMBAX_PROPOSAL_TARGET_MANAGE_REQUIRED'; end if; end if; update public.kombax_brand_proposals_v223 set status=v_status,response_note=nullif(trim(p_payload->>'response_note'),''),responded_by=v_uid,responded_at=now(),updated_at=now() where id=v_id; insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,before_state,after_state) values(v_prop.brand_profile_id,v_uid,p_operation,'proposal',v_id,to_jsonb(v_prop),jsonb_build_object('status',v_status,'response_note',p_payload->>'response_note')); return jsonb_build_object('ok',true,'proposal_id',v_id,'status',v_status);
 elsif p_operation='proposal.brand_status' then
  v_id:=(p_payload->>'proposal_id')::uuid; v_status:=p_payload->>'status'; select * into v_prop from public.kombax_brand_proposals_v223 where id=v_id; if v_prop.id is null then raise exception 'KOMBAX_PROPOSAL_NOT_FOUND'; end if; if not public.app_kombax_puede_gestionar_perfil_v070(v_prop.brand_profile_id,'edit') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if; if v_status not in ('pending','in_review','accepted','declined','completed') then raise exception 'KOMBAX_PROPOSAL_STATUS_INVALID'; end if; update public.kombax_brand_proposals_v223 set status=v_status,updated_at=now() where id=v_id; insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,before_state,after_state) values(v_prop.brand_profile_id,v_uid,p_operation,'proposal',v_id,to_jsonb(v_prop),jsonb_build_object('status',v_status)); return jsonb_build_object('ok',true,'proposal_id',v_id,'status',v_status);
 elsif p_operation='proposal.withdraw' then
  v_id:=(p_payload->>'proposal_id')::uuid; select * into v_prop from public.kombax_brand_proposals_v223 where id=v_id; if v_prop.id is null then raise exception 'KOMBAX_PROPOSAL_NOT_FOUND'; end if; if not public.app_kombax_puede_gestionar_perfil_v070(v_prop.brand_profile_id,'edit') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if; update public.kombax_brand_proposals_v223 set status='withdrawn',updated_at=now() where id=v_id; insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,before_state,after_state) values(v_prop.brand_profile_id,v_uid,p_operation,'proposal',v_id,to_jsonb(v_prop),jsonb_build_object('status','withdrawn')); return jsonb_build_object('ok',true,'proposal_id',v_id,'status','withdrawn');
 elsif p_operation='collaboration.preferences.save' then
  v_target_profile:=(p_payload->>'direct_profile_id')::uuid; if not public.app_kombax_puede_gestionar_perfil_v070(v_target_profile,'edit') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED'; end if; select tipo into v_profile_type from public.perfiles_kombax_directos where id=v_target_profile; if v_profile_type not in ('competidor','profesional') then raise exception 'KOMBAX_COLLABORATION_PROFILE_TYPE_INVALID'; end if; insert into public.kombax_brand_collaboration_preferences_v223(direct_profile_id,discoverable_by_brands,inbound_enabled,categories,contact_mode,collaboration_note,updated_by,updated_at) values(v_target_profile,coalesce((p_payload->>'discoverable_by_brands')::boolean,false),coalesce((p_payload->>'inbound_enabled')::boolean,false),coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'categories','[]'::jsonb))),'{}'::text[]),coalesce(nullif(p_payload->>'contact_mode',''),'profile'),nullif(trim(p_payload->>'collaboration_note'),''),v_uid,now()) on conflict(direct_profile_id) do update set discoverable_by_brands=excluded.discoverable_by_brands,inbound_enabled=excluded.inbound_enabled,categories=excluded.categories,contact_mode=excluded.contact_mode,collaboration_note=excluded.collaboration_note,updated_by=v_uid,updated_at=now(); return jsonb_build_object('ok',true,'direct_profile_id',v_target_profile);
 elsif p_operation='campaign.apply' then
  v_id:=(p_payload->>'campaign_id')::uuid; v_target_profile:=(p_payload->>'direct_profile_id')::uuid; if not public.app_kombax_puede_gestionar_perfil_v070(v_target_profile,'edit') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED'; end if; if not exists(select 1 from public.kombax_brand_collaboration_preferences_v223 where direct_profile_id=v_target_profile and discoverable_by_brands and inbound_enabled) then raise exception 'KOMBAX_COLLABORATION_OPT_IN_REQUIRED'; end if; select * into v_campaign from public.kombax_brand_campaigns_v223 where id=v_id and status='active' and visibility='open' and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>=now()); if v_campaign.id is null then raise exception 'KOMBAX_OPEN_CAMPAIGN_NOT_AVAILABLE'; end if; if exists(select 1 from public.kombax_brand_proposals_v223 where campaign_id=v_id and target_direct_profile_id=v_target_profile and status<>'withdrawn') then raise exception 'KOMBAX_CAMPAIGN_ALREADY_APPLIED'; end if; insert into public.kombax_brand_proposals_v223(brand_profile_id,campaign_id,target_type,target_direct_profile_id,source,status,message,created_by) values(v_campaign.brand_profile_id,v_id,'direct_profile',v_target_profile,'open_campaign_application','interested',nullif(trim(p_payload->>'message'),''),v_uid) returning id into v_id; insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,after_state) values(v_campaign.brand_profile_id,v_uid,p_operation,'proposal',v_id,p_payload); return jsonb_build_object('ok',true,'proposal_id',v_id,'status','interested');
 elsif p_operation='team.role.set' then
  v_brand:=(p_payload->>'brand_profile_id')::uuid; v_target_profile:=(p_payload->>'perfil_id')::uuid; if not public.app_kombax_puede_gestionar_perfil_v070(v_brand,'admin') then raise exception 'KOMBAX_BRAND_MANAGE_REQUIRED'; end if; if not exists(select 1 from public.kombax_perfil_gestores g where g.perfil_directo_id=v_brand and g.perfil_id=v_target_profile and g.estado='activo') then raise exception 'KOMBAX_BRAND_MANAGER_REQUIRED'; end if; insert into public.kombax_brand_team_roles_v223(brand_profile_id,perfil_id,business_role,updated_by,updated_at) values(v_brand,v_target_profile,p_payload->>'business_role',v_uid,now()) on conflict(brand_profile_id,perfil_id) do update set business_role=excluded.business_role,updated_by=v_uid,updated_at=now(); insert into public.kombax_brand_audit_v223(brand_profile_id,actor_id,action,object_type,object_id,after_state) values(v_brand,v_uid,p_operation,'team_member',v_target_profile,p_payload); return jsonb_build_object('ok',true,'perfil_id',v_target_profile,'business_role',p_payload->>'business_role');
 else raise exception 'KOMBAX_BRAND_OPERATION_UNSUPPORTED'; end if;
end $function$;


revoke all on function public.app_kombax_brand_mutate_legacy_r120(text,jsonb) from public,anon,authenticated;
create or replace function public.app_kombax_brand_mutate_v223(p_operation text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare pid uuid;a jsonb;st text;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 if p_operation in ('campaign.save','campaign.status','proposal.send') then
  pid:=nullif(p_payload->>'brand_profile_id','')::uuid;
  if p_operation='campaign.status' then select c.brand_profile_id into pid from public.kombax_brand_campaigns_v223 c where c.id=(p_payload->>'campaign_id')::uuid;end if;
  a:=public.app_kombax_profile_operations_access_r120(pid);
  if not public.app_kombax_puede_gestionar_perfil_v070(pid,'edit') then raise exception 'PRIVATE_OPERATIONS_REQUIRED';end if;
  st:=coalesce(p_payload->>'status','draft');
  if (p_operation='proposal.send' or st='active') and not (a->>'active_service')::boolean then raise exception 'VERIFIED_ACTIVE_SERVICE_REQUIRED';end if;
  if p_operation='campaign.save' and nullif(p_payload->>'campaign_id','') is not null and not (a->>'active_service')::boolean and
   exists(select 1 from public.kombax_brand_campaigns_v223 c where c.id=(p_payload->>'campaign_id')::uuid and c.brand_profile_id=pid and c.status='active') then raise exception 'VERIFIED_ACTIVE_SERVICE_REQUIRED';end if;
 end if;
 return public.app_kombax_brand_mutate_legacy_r120(p_operation,p_payload);
end $$;
revoke all on function public.app_kombax_brand_mutate_v223(text,jsonb) from public,anon;
grant execute on function public.app_kombax_brand_mutate_v223(text,jsonb) to authenticated;


commit;
