-- Owner verification repair for frozen build 20177. Apply manually AFTER review.
begin;
-- KOMBAX R114 · Owner Command Center / global Owner alerts / report payload.
-- Additive only. No commercial, identity or RLS rules are relaxed.


create unique index if not exists uq_notificaciones_global_perfil_clave_r114
  on public.notificaciones(perfil_id,clave)
  where club_id is null and perfil_id is not null and clave is not null;

create or replace function public.app_kombax_owner_alerts_r114(p_limit integer default 80)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_limit int:=least(greatest(coalesce(p_limit,80),1),200);v_items jsonb;v_counts jsonb;
begin
  if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.creado_en desc),'[]'::jsonb) into v_items from (
    select n.id,n.tipo,n.titulo,n.cuerpo,n.ruta,n.datos,n.leida,n.creado_en,n.subject_type,n.subject_id,n.push_enviado_en,n.push_intentos,n.push_error
    from public.notificaciones n where n.perfil_id=v_uid and n.club_id is null
    order by n.creado_en desc limit v_limit
  ) x;
  select jsonb_build_object(
    'unread',count(*) filter(where not n.leida),
    'action_required',count(*) filter(where not n.leida and coalesce((n.datos->>'requiere_accion')::boolean,false)),
    'critical',count(*) filter(where not n.leida and n.datos->>'priority'='critical'),
    'warning',count(*) filter(where not n.leida and n.datos->>'priority'='warning'),
    'push_pending',count(*) filter(where not n.leida and n.push_enviado_en is null and coalesce(n.push_intentos,0)<3)
  ) into v_counts from public.notificaciones n where n.perfil_id=v_uid and n.club_id is null;
  return jsonb_build_object('ok',true,'items',v_items,'counts',coalesce(v_counts,'{}'::jsonb));
end $$;
revoke all on function public.app_kombax_owner_alerts_r114(integer) from public,anon;
grant execute on function public.app_kombax_owner_alerts_r114(integer) to authenticated;

create or replace function public.app_kombax_owner_report_payload_r114(p_days integer default 90)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_days int:=least(greatest(coalesce(p_days,90),7),365);v_metrics jsonb;v_agents jsonb;v_alerts jsonb;
begin
 if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
 v_metrics:=public.app_kombax_metrics_platform_v133(v_days);
 -- Preserve the active backend's full dashboard payload, including turns/reports.
 v_agents:=public.app_kombax_owner_agents_dashboard_r105();
 v_alerts:=public.app_kombax_owner_alerts_r114(80)->'counts';
 return jsonb_build_object('ok',true,'generated_at',now(),'days',v_days,'metrics',coalesce(v_metrics,'{}'::jsonb),
  'owner_alerts',coalesce(v_alerts,'{}'::jsonb),'agents',coalesce(v_agents,'{}'::jsonb));
end $$;
revoke all on function public.app_kombax_owner_report_payload_r114(integer) from public,anon;
grant execute on function public.app_kombax_owner_report_payload_r114(integer) to authenticated;

create or replace function public.app_kombax_owner_notify_verification_r114()
returns trigger language plpgsql security definer set search_path=public,auth as $$
begin
  if new.estado='submitted' and (tg_op='INSERT' or old.estado is distinct from new.estado) then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,subject_type,subject_id)
    select null,a.perfil_id,'owner:verification:'||new.id::text||':submitted','owner_action',
      'Nueva verificación pendiente','Hay una nueva solicitud de verificación pendiente de revisión.','platform-admin',
      jsonb_build_object('priority','action_required','requiere_accion',true,'owner_section','owner-verifications','application_type',new.tipo),
      'verification',new.id
    from public.kombax_platform_admins a where a.activo
    on conflict (perfil_id,clave) where club_id is null and perfil_id is not null and clave is not null
    do update set leida=false,leida_en=null,ciclo_estado='activo',archivado_en=null,creado_en=now(),datos=excluded.datos;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_owner_notify_verification_r114() from public,anon,authenticated;

drop trigger if exists trg_kombax_owner_notify_verification_r114 on public.kombax_solicitudes_alta;
create trigger trg_kombax_owner_notify_verification_r114
after insert or update of estado on public.kombax_solicitudes_alta
for each row execute function public.app_kombax_owner_notify_verification_r114();

create or replace function public.app_kombax_owner_notify_agent_r114()
returns trigger language plpgsql security definer set search_path=public,auth,kombax_owner_ai as $$
declare v_priority text;v_required boolean;
begin
  if old.status is not distinct from new.status and old.risk_level is not distinct from new.risk_level then return new; end if;
  if new.status='failed' or (new.status='completed' and new.risk_level in ('high','critical')) then
    v_priority:=case when new.risk_level='critical' then 'critical' when new.status='failed' or new.risk_level='high' then 'warning' else 'info' end;
    v_required:=new.status='failed' or new.risk_level in ('high','critical');
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,subject_type,subject_id)
    values(null,new.requested_by,'owner:agent:'||new.id::text||':'||new.status||':'||coalesce(new.risk_level,'none'),'owner_agent',
      case when new.status='failed' then 'Agente Owner requiere atención' else 'Agente Owner detectó un riesgo' end,
      case when new.status='failed' then 'Una ejecución de agente no pudo completarse. Revisa la trazabilidad en Owner.' else 'Un agente ha marcado un resultado de riesgo alto. Revisa su recomendación antes de actuar.' end,
      'platform-admin',jsonb_build_object('priority',v_priority,'requiere_accion',v_required,'owner_section','owner-agents','agent',new.agent,'status',new.status,'risk_level',new.risk_level),
      'owner_agent_turn',new.id)
    on conflict do nothing;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_owner_notify_agent_r114() from public,anon,authenticated;

drop trigger if exists trg_kombax_owner_notify_agent_r114 on kombax_owner_ai.agent_turns;
create trigger trg_kombax_owner_notify_agent_r114
after update of status,risk_level on kombax_owner_ai.agent_turns
for each row execute function public.app_kombax_owner_notify_agent_r114();

notify pgrst,'reload schema';

create or replace function public.app_kombax_professional_workspace_r118(p_profile_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public','auth'
as $function$
declare
  v_uid uuid:=auth.uid();
  v_base jsonb;
  v_credentials jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists(
    select 1 from public.perfiles_kombax_directos d
    where d.id=p_profile_id and d.tipo in ('profesional','competidor')
      and (d.perfil_id=v_uid or public.app_kombax_puede_gestionar_perfil_v070(d.id,'view'))
  ) then
    raise exception 'KOMBAX_PROFESSIONAL_PROFILE_FORBIDDEN';
  end if;

  v_base:=public.app_kombax_professional_workspace_v198(p_profile_id);
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,
    'professional_profile_id',c.professional_profile_id,
    'specialty_code',c.specialty_code,
    'credential_type',c.credential_type,
    'issuer',c.issuer,
    'reference_public',c.reference_public,
    'verification_url',c.verification_url,
    'estado',case when c.estado='verificada' and c.expires_on is not null and c.expires_on<current_date then 'expirada' else c.estado end,
    'expires_on',c.expires_on,
    'public_visible',c.public_visible,
    'public_reference_visible',c.public_reference_visible,
    'verified_at',c.verified_at,
    'evidence_count',(select count(*) from public.kombax_professional_credential_evidence_r118 e where e.credential_id=c.id and e.estado='active'),
    'declaration_accepted',exists(select 1 from public.kombax_professional_credential_acceptances_r118 a where a.credential_id=c.id),
    'created_at',c.creado_en,
    'updated_at',c.actualizado_en
  ) order by c.creado_en desc),'[]'::jsonb)
  into v_credentials
  from public.kombax_professional_credentials_v198 c
  where c.professional_profile_id=p_profile_id;

  return coalesce(v_base,'{}'::jsonb)||jsonb_build_object(
    'credentials',v_credentials,
    'credential_declaration_version','r118-professional-credential-truth-v1',
    'credential_declaration_text','Declaro que la información, titulaciones, licencias y documentos aportados para esta credencial son auténticos, vigentes cuando corresponda, me pertenecen o estoy autorizado para aportarlos, y autorizo a KOMBAX a utilizarlos exclusivamente para revisar y verificar esta credencial. Soy responsable de comunicar cambios, caducidades o revocaciones y entiendo que aportar información falsa o manipulada puede provocar el rechazo o suspensión de la credencial y de las capacidades asociadas.'::text
  );
end
$function$;

create or replace function public.app_kombax_professional_credential_mutate_r118(
  p_operation text,p_payload jsonb,p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','auth'
as $function$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_profile_id uuid;
  v_credential_id uuid;
  v_credential public.kombax_professional_credentials_v198;
  v_operation text:=lower(btrim(coalesce(p_operation,'')));
  v_specialty text;
  v_type text;
  v_issuer text;
  v_reference text;
  v_url text;
  v_expiry date;
  v_public boolean;
  v_public_reference boolean;
  v_evidence_count integer;
  v_path text;
  v_mime text;
  v_size bigint;
  v_result jsonb;
  v_existing public.app_mutation_requests;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>('r118.'||v_operation) then
      raise exception 'MUTATION_REQUEST_ID_REUSED';
    end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,operation)
    values(p_request_id,v_uid,'r118.'||v_operation);
  end if;

  begin
    v_profile_id:=nullif(v_payload->>'professional_profile_id','')::uuid;
  exception when others then
    raise exception 'KOMBAX_PROFESSIONAL_PROFILE_ID_INVALID';
  end;
  if v_profile_id is null then raise exception 'KOMBAX_PROFESSIONAL_PROFILE_REQUIRED'; end if;

  if v_operation<>'professional.credential.review' then
    if not exists(
      select 1 from public.perfiles_kombax_directos d
      where d.id=v_profile_id and d.tipo='profesional' and d.perfil_id=v_uid
    ) then
      raise exception 'KOMBAX_PROFESSIONAL_CREDENTIAL_OWNER_REQUIRED';
    end if;
  elsif not public.app_kombax_es_verificador_v117() then
    raise exception 'KOMBAX_VERIFIER_REQUIRED';
  end if;

  if v_operation='professional.credential.save' then
    begin v_credential_id:=nullif(v_payload->>'credential_id','')::uuid; exception when others then raise exception 'KOMBAX_CREDENTIAL_ID_INVALID'; end;
    v_specialty:=lower(btrim(coalesce(v_payload->>'specialty_code','')));
    v_type:=left(btrim(coalesce(v_payload->>'credential_type','')),160);
    v_issuer:=left(btrim(coalesce(v_payload->>'issuer','')),220);
    v_reference:=left(btrim(coalesce(v_payload->>'reference_public','')),260);
    v_url:=nullif(left(btrim(coalesce(v_payload->>'verification_url','')),700),'');
    begin v_expiry:=nullif(v_payload->>'expires_on','')::date; exception when others then raise exception 'KOMBAX_CREDENTIAL_EXPIRY_INVALID'; end;
    v_public:=coalesce((v_payload->>'public_visible')::boolean,false);
    v_public_reference:=coalesce((v_payload->>'public_reference_visible')::boolean,true);

    if char_length(v_type)<2 then raise exception 'KOMBAX_CREDENTIAL_TYPE_REQUIRED'; end if;
    if char_length(v_issuer)<2 then raise exception 'KOMBAX_CREDENTIAL_ISSUER_REQUIRED'; end if;
    if v_url is not null and v_url !~* '^https://[^[:space:]]+$' then raise exception 'KOMBAX_CREDENTIAL_VERIFICATION_URL_INVALID'; end if;
    if not exists(select 1 from public.kombax_profesional_especialidades_v196 s where s.codigo=v_specialty and s.activa) then
      raise exception 'KOMBAX_PROFESSIONAL_SPECIALTY_INVALID';
    end if;
    if not (
      exists(select 1 from public.kombax_profesional_perfiles_v196 p where p.perfil_directo_id=v_profile_id and p.especialidad_principal=v_specialty)
      or exists(select 1 from public.kombax_profesional_especialidades_secundarias_v196 s where s.perfil_directo_id=v_profile_id and s.especialidad_codigo=v_specialty)
    ) then
      raise exception 'KOMBAX_CREDENTIAL_SPECIALTY_NOT_IN_PROFILE';
    end if;

    if v_credential_id is null then
      insert into public.kombax_professional_credentials_v198(
        professional_profile_id,specialty_code,credential_type,issuer,reference_public,
        verification_url,estado,expires_on,public_visible,public_reference_visible,creado_por
      ) values(
        v_profile_id,v_specialty,v_type,v_issuer,v_reference,v_url,'declarada',v_expiry,false,v_public_reference,v_uid
      ) returning * into v_credential;
    else
      select * into v_credential from public.kombax_professional_credentials_v198
      where id=v_credential_id and professional_profile_id=v_profile_id for update;
      if v_credential.id is null then raise exception 'KOMBAX_CREDENTIAL_NOT_FOUND'; end if;
      if v_credential.estado not in ('declarada','rechazada') then raise exception 'KOMBAX_CREDENTIAL_LOCKED_FOR_REVIEW'; end if;
      update public.kombax_professional_credentials_v198
      set specialty_code=v_specialty,credential_type=v_type,issuer=v_issuer,reference_public=v_reference,
          verification_url=v_url,expires_on=v_expiry,public_visible=false,
          public_reference_visible=v_public_reference,estado='declarada',
          verified_by=null,verified_at=null,review_note=null,actualizado_en=now()
      where id=v_credential.id returning * into v_credential;
    end if;
    v_result:=jsonb_build_object('ok',true,'credential',to_jsonb(v_credential));

  elsif v_operation='professional.credential.evidence.register' then
    begin v_credential_id:=(v_payload->>'credential_id')::uuid; exception when others then raise exception 'KOMBAX_CREDENTIAL_ID_INVALID'; end;
    select * into v_credential from public.kombax_professional_credentials_v198
    where id=v_credential_id and professional_profile_id=v_profile_id for update;
    if v_credential.id is null then raise exception 'KOMBAX_CREDENTIAL_NOT_FOUND'; end if;
    if v_credential.estado not in ('declarada','rechazada') then raise exception 'KOMBAX_CREDENTIAL_LOCKED_FOR_REVIEW'; end if;
    v_path=btrim(coalesce(v_payload->>'storage_path',''));
    v_mime=lower(btrim(coalesce(v_payload->>'mime_type','')));
    begin v_size:=(v_payload->>'size_bytes')::bigint; exception when others then raise exception 'KOMBAX_CREDENTIAL_FILE_SIZE_INVALID'; end;
    if split_part(v_path,'/',1)<>v_uid::text
       or split_part(v_path,'/',2)<>'professional-credential'
       or split_part(v_path,'/',3)<>v_credential_id::text then
      raise exception 'KOMBAX_CREDENTIAL_EVIDENCE_PATH_INVALID';
    end if;
    if v_mime not in ('application/pdf','image/jpeg','image/png','image/webp') then raise exception 'KOMBAX_CREDENTIAL_EVIDENCE_MIME_INVALID'; end if;
    if v_size<=0 or v_size>15728640 then raise exception 'KOMBAX_CREDENTIAL_EVIDENCE_SIZE_INVALID'; end if;
    insert into public.kombax_professional_credential_evidence_r118(
      credential_id,professional_profile_id,storage_path,mime_type,size_bytes,creado_por
    ) values(v_credential_id,v_profile_id,v_path,v_mime,v_size,v_uid)
    returning jsonb_build_object('id',id,'credential_id',credential_id,'storage_path',storage_path,'mime_type',mime_type,'size_bytes',size_bytes) into v_result;
    v_result:=jsonb_build_object('ok',true,'evidence',v_result);

  elsif v_operation='professional.credential.submit' then
    begin v_credential_id:=(v_payload->>'credential_id')::uuid; exception when others then raise exception 'KOMBAX_CREDENTIAL_ID_INVALID'; end;
    select * into v_credential from public.kombax_professional_credentials_v198
    where id=v_credential_id and professional_profile_id=v_profile_id for update;
    if v_credential.id is null then raise exception 'KOMBAX_CREDENTIAL_NOT_FOUND'; end if;
    if v_credential.estado not in ('declarada','rechazada') then raise exception 'KOMBAX_CREDENTIAL_NOT_SUBMITTABLE'; end if;
    if coalesce((v_payload->>'declaration_accepted')::boolean,false) is not true then raise exception 'KOMBAX_CREDENTIAL_DECLARATION_REQUIRED'; end if;
    select count(*) into v_evidence_count from public.kombax_professional_credential_evidence_r118 e
    where e.credential_id=v_credential_id and e.estado='active';
    if v_evidence_count<1 then raise exception 'KOMBAX_CREDENTIAL_EVIDENCE_REQUIRED'; end if;
    insert into public.kombax_professional_credential_acceptances_r118(
      credential_id,professional_profile_id,perfil_id,declaration_version,declaration_text,user_agent
    ) values(
      v_credential_id,v_profile_id,v_uid,'r118-professional-credential-truth-v1','Declaro que la información, titulaciones, licencias y documentos aportados para esta credencial son auténticos, vigentes cuando corresponda, me pertenecen o estoy autorizado para aportarlos, y autorizo a KOMBAX a utilizarlos exclusivamente para revisar y verificar esta credencial. Soy responsable de comunicar cambios, caducidades o revocaciones y entiendo que aportar información falsa o manipulada puede provocar el rechazo o suspensión de la credencial y de las capacidades asociadas.'::text,
      left(nullif(btrim(v_payload->>'user_agent'),''),500)
    );
    update public.kombax_professional_credentials_v198
    set estado='pendiente',public_visible=false,review_note=null,actualizado_en=now()
    where id=v_credential_id returning * into v_credential;
    insert into public.kombax_actor_audit(actor_perfil_id,accion,objeto_tipo,objeto_id,detalle)
    values(v_uid,'professional.credential.submit.r118','professional_credential',v_credential_id,
      jsonb_build_object('professional_profile_id',v_profile_id,'declaration_version','r118-professional-credential-truth-v1','evidence_count',v_evidence_count));
    v_result:=jsonb_build_object('ok',true,'credential',to_jsonb(v_credential),'evidence_count',v_evidence_count);

  elsif v_operation='professional.credential.visibility' then
    begin v_credential_id:=(v_payload->>'credential_id')::uuid; exception when others then raise exception 'KOMBAX_CREDENTIAL_ID_INVALID'; end;
    select * into v_credential from public.kombax_professional_credentials_v198
    where id=v_credential_id and professional_profile_id=v_profile_id for update;
    if v_credential.id is null then raise exception 'KOMBAX_CREDENTIAL_NOT_FOUND'; end if;
    v_public:=coalesce((v_payload->>'public_visible')::boolean,false);
    v_public_reference:=coalesce((v_payload->>'public_reference_visible')::boolean,true);
    if v_public and (v_credential.estado<>'verificada' or (v_credential.expires_on is not null and v_credential.expires_on<current_date)) then
      raise exception 'KOMBAX_CREDENTIAL_NOT_PUBLICABLE';
    end if;
    update public.kombax_professional_credentials_v198
    set public_visible=v_public,public_reference_visible=v_public_reference,actualizado_en=now()
    where id=v_credential_id returning * into v_credential;
    v_result:=jsonb_build_object('ok',true,'credential',to_jsonb(v_credential));

  elsif v_operation='professional.credential.review' then
    begin v_credential_id:=(v_payload->>'credential_id')::uuid; exception when others then raise exception 'KOMBAX_CREDENTIAL_ID_INVALID'; end;
    select * into v_credential from public.kombax_professional_credentials_v198
    where id=v_credential_id and professional_profile_id=v_profile_id for update;
    if v_credential.id is null then raise exception 'KOMBAX_CREDENTIAL_NOT_FOUND'; end if;
    if v_credential.estado<>'pendiente' then raise exception 'KOMBAX_CREDENTIAL_NOT_PENDING'; end if;
    v_type:=lower(btrim(coalesce(v_payload->>'decision','')));
    if v_type not in ('verificada','rechazada') then raise exception 'KOMBAX_CREDENTIAL_REVIEW_DECISION_INVALID'; end if;
    if v_type='verificada' and not exists(
      select 1 from public.kombax_professional_credential_acceptances_r118 a where a.credential_id=v_credential_id
    ) then raise exception 'KOMBAX_CREDENTIAL_ACCEPTANCE_MISSING'; end if;
    if v_type='verificada' and not exists(
      select 1 from public.kombax_professional_credential_evidence_r118 e
      join storage.objects o on o.bucket_id='kombax-verification-docs' and o.name=e.storage_path
      where e.credential_id=v_credential_id and e.estado='active'
    ) then raise exception 'KOMBAX_CREDENTIAL_EVIDENCE_REQUIRED'; end if;
    if v_type='verificada' and v_credential.expires_on<current_date then
      raise exception 'KOMBAX_CREDENTIAL_EXPIRED';
    end if;
    update public.kombax_professional_credentials_v198
    set estado=v_type,
        verified_by=case when v_type='verificada' then v_uid else null end,
        verified_at=case when v_type='verificada' then now() else null end,
        public_visible=case when v_type='verificada' then public_visible else false end,
        review_note=left(nullif(btrim(v_payload->>'review_note'),''),1600),
        actualizado_en=now()
    where id=v_credential_id returning * into v_credential;
    insert into public.kombax_actor_audit(actor_perfil_id,accion,objeto_tipo,objeto_id,detalle)
    values(v_uid,'professional.credential.review.r118','professional_credential',v_credential_id,
      jsonb_build_object('professional_profile_id',v_profile_id,'decision',v_type));
    v_result:=jsonb_build_object('ok',true,'credential',to_jsonb(v_credential));

  else
    raise exception 'KOMBAX_CREDENTIAL_OPERATION_NOT_ALLOWED';
  end if;

  v_result:=v_result||jsonb_build_object('operation',v_operation,'request_id',p_request_id);
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end
$function$;
-- Private queue: uploads in drafts wait for submission and acceptance.
create table if not exists kombax_owner_ai.verification_jobs_r118(
 id uuid primary key default gen_random_uuid(),context_type text not null,
 context_id uuid not null,requested_by uuid not null references public.perfiles(id),
 status text not null default 'queued' check(status in ('queued','processing','completed','manual')),
 attempts int not null default 0,lease_until timestamptz,turn_id uuid,
 result jsonb,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(context_type,context_id)
);
alter table kombax_owner_ai.verification_jobs_r118 enable row level security;
revoke all on kombax_owner_ai.verification_jobs_r118 from public,anon,authenticated;
create table if not exists kombax_owner_ai.verification_actions_r118(
 turn_id uuid primary key references kombax_owner_ai.agent_turns(id),
 context_type text not null,context_id uuid not null,owner_id uuid not null,
 approved boolean not null,result jsonb not null,created_at timestamptz not null default now()
);
alter table kombax_owner_ai.verification_actions_r118 enable row level security;
revoke all on kombax_owner_ai.verification_actions_r118 from public,anon,authenticated;

alter table kombax_owner_ai.agent_turns drop constraint if exists agent_turns_context_type_check;
alter table kombax_owner_ai.agent_turns add constraint agent_turns_context_type_check
 check(context_type is null or context_type in ('platform_application','seller_application','pilot_summary','platform_summary','professional_credential'));

create or replace function public.app_kombax_owner_credential_turn_start_r118(
 p_agent text,p_message text,p_context_type text default null,p_context_id uuid default null,
 p_reasoning_effort text default 'low',p_conversation_id uuid default null,p_client_request_id uuid default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_result jsonb;
begin
 if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
 if p_agent<>'owner_operations' or p_context_type<>'professional_credential' or not exists(
  select 1 from public.kombax_professional_credentials_v198 where id=p_context_id
 ) then raise exception 'OWNER_AGENT_CONTEXT_INVALID';end if;
 v_result:=public.app_kombax_owner_agent_turn_start_r105(p_agent,p_message,'platform_summary',p_context_id,p_reasoning_effort,p_conversation_id,p_client_request_id);
 update kombax_owner_ai.agent_turns set context_type='professional_credential',context_id=p_context_id
 where id=(v_result->>'turn_id')::uuid and requested_by=v_uid;
 return v_result;
end $$;
revoke all on function public.app_kombax_owner_credential_turn_start_r118(text,text,text,uuid,text,uuid,uuid) from public,anon;
grant execute on function public.app_kombax_owner_credential_turn_start_r118(text,text,text,uuid,text,uuid,uuid) to authenticated,service_role;

-- The client cannot supply paths. Only the documents bound to the authorized target are returned.
create or replace function public.app_kombax_owner_verification_context_r118(p_turn_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t kombax_owner_ai.agent_turns;v_base jsonb;v_context jsonb;v_documents jsonb;
 v_old_sub text:=current_setting('request.jwt.claim.sub',true);v_uid uuid:=auth.uid();
begin
 select * into t from kombax_owner_ai.agent_turns where id=p_turn_id;
 if t.id is null then raise exception 'OWNER_AGENT_TURN_NOT_FOUND';end if;
 if auth.role()='service_role' then
  perform set_config('request.jwt.claim.sub',t.requested_by::text,true);v_uid:=t.requested_by;
 end if;
 if v_uid is null or t.requested_by<>v_uid or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
 v_base:=public.app_kombax_owner_agent_turn_context_r105(p_turn_id);
 if t.context_type='platform_application' then
  select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'storage_bucket','kombax-verification-docs','storage_path',d.storage_path,
   'filename',split_part(d.storage_path,'/',array_length(string_to_array(d.storage_path,'/'),1)),'mime_type',d.mime_type,
   'size_bytes',d.bytes,'category',d.tipo_documento) order by d.creado_en),'[]'::jsonb) into v_documents
  from public.kombax_verificacion_documentos d where d.solicitud_id=t.context_id and d.estado='active';
  select (v_base->'context')||jsonb_build_object('legal_name',a.datos_verificacion->>'nombre_legal',
   'declaration_accepted',a.declaracion_aceptada,'automatic_eligible_type',a.tipo not in ('club','federacion'),
   'review_scope','identity_only') into v_context from public.kombax_solicitudes_alta a where a.id=t.context_id;
 elsif t.context_type='professional_credential' then
  select jsonb_build_object('kind','professional_credential','id',c.id,'type',c.credential_type,'issuer',c.issuer,
   'reference',c.reference_public,'specialty',c.specialty_code,'status',c.estado,'expires_on',c.expires_on,
   'name',d.nombre_publico,'declaration_accepted',exists(select 1 from public.kombax_professional_credential_acceptances_r118 a where a.credential_id=c.id),
   'review_scope','single_credential_only') into v_context
  from public.kombax_professional_credentials_v198 c join public.perfiles_kombax_directos d on d.id=c.professional_profile_id where c.id=t.context_id;
  select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'storage_bucket','kombax-verification-docs','storage_path',e.storage_path,
   'filename',split_part(e.storage_path,'/',array_length(string_to_array(e.storage_path,'/'),1)),
   'mime_type',e.mime_type,'size_bytes',e.size_bytes,'category','professional_credential') order by e.creado_en),'[]'::jsonb) into v_documents
  from public.kombax_professional_credential_evidence_r118 e where e.credential_id=t.context_id and e.estado='active';
 end if;
 v_base:=v_base||jsonb_build_object('context',coalesce(v_context,v_base->'context'),'verification_documents',coalesce(v_documents,'[]'::jsonb));
 perform set_config('request.jwt.claim.sub',coalesce(v_old_sub,''),true);
 return v_base;
exception when others then perform set_config('request.jwt.claim.sub',coalesce(v_old_sub,''),true);raise;
end $$;
revoke all on function public.app_kombax_owner_verification_context_r118(uuid) from public,anon;
grant execute on function public.app_kombax_owner_verification_context_r118(uuid) to authenticated,service_role;

create or replace function public.app_kombax_owner_verification_enqueue_r118(p_kind text,p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_owner uuid;
begin
 select perfil_id into v_owner from public.kombax_platform_admins where activo order by perfil_id limit 1;
 if v_owner is null then return;end if;
 insert into kombax_owner_ai.verification_jobs_r118(context_type,context_id,requested_by) values(p_kind,p_id,v_owner)
 on conflict(context_type,context_id) do update set status='queued',attempts=0,lease_until=null,turn_id=null,result=null,updated_at=now()
 where kombax_owner_ai.verification_jobs_r118.status<>'processing';
end $$;
revoke all on function public.app_kombax_owner_verification_enqueue_r118(text,uuid) from public,anon,authenticated;

create or replace function public.app_kombax_owner_verification_notify_r118(p_kind text,p_id uuid,p_owner uuid,p_approved boolean,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
begin
 insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,subject_type,subject_id)
 values(null,p_owner,'owner:verification-ai:'||p_kind||':'||p_id::text||':'||p_approved::text,'owner_action',
  case when p_approved then 'Verificación automática completada' else 'Verificación requiere revisión manual' end,
  left(p_reason,600),'platform-admin',jsonb_build_object('priority',case when p_approved then 'info' else 'action_required' end,
  'requiere_accion',not p_approved,'owner_section',case when p_kind='professional_credential' then 'owner-professional-credentials' else 'owner-verifications' end),p_kind,p_id)
 on conflict do nothing;
end $$;
revoke all on function public.app_kombax_owner_verification_notify_r118(text,uuid,uuid,boolean,text) from public,anon,authenticated;

create or replace function public.app_kombax_owner_verification_lifecycle_r118()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_id uuid;v_kind text;v_owner uuid;v_pending boolean;v_account uuid;
begin
 if tg_table_name='kombax_verificacion_documentos' then
  if new.estado='active' and exists(select 1 from public.kombax_solicitudes_alta a where a.id=new.solicitud_id and a.estado in ('submitted','under_review')) then
   perform public.app_kombax_owner_verification_enqueue_r118('platform_application',new.solicitud_id);
  end if;return new;
 elsif tg_table_name='kombax_professional_credential_evidence_r118' then
  if new.estado='active' and exists(select 1 from public.kombax_professional_credentials_v198 c where c.id=new.credential_id and c.estado='pendiente') then
   perform public.app_kombax_owner_verification_enqueue_r118('professional_credential',new.credential_id);
  end if;return new;
 elsif tg_table_name='kombax_solicitudes_alta' then
  v_id:=new.id;v_kind:='platform_application';v_account:=new.perfil_id;v_pending:=new.estado in ('submitted','under_review');
  if new.estado='submitted' and (tg_op='INSERT' or old.estado is distinct from new.estado) then perform public.app_kombax_owner_verification_enqueue_r118(v_kind,v_id);end if;
 else
  v_id:=new.id;v_kind:='professional_credential';v_pending:=new.estado='pendiente';
  select perfil_id into v_account from public.perfiles_kombax_directos where id=new.professional_profile_id;
  if new.estado='pendiente' and (tg_op='INSERT' or old.estado is distinct from new.estado) then
   perform public.app_kombax_owner_verification_enqueue_r118(v_kind,v_id);
   insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,subject_type,subject_id)
   select null,a.perfil_id,'owner:credential:'||new.id::text,'owner_action','Credencial profesional pendiente',
    'Hay evidencia privada y una credencial pendiente de revisión.','platform-admin',jsonb_build_object('priority','action_required','requiere_accion',true,'owner_section','owner-professional-credentials'),v_kind,v_id
   from public.kombax_platform_admins a where a.activo
   on conflict (perfil_id,clave) where club_id is null and perfil_id is not null and clave is not null
   do update set leida=false,leida_en=null,ciclo_estado='activo',archivado_en=null,datos=excluded.datos,creado_en=now();
  end if;
 end if;
 if not v_pending then
  update kombax_owner_ai.verification_jobs_r118 set status='completed',lease_until=null,result=jsonb_build_object('resolved',true,'estado',new.estado),updated_at=now()
  where context_type=v_kind and context_id=v_id;
  update public.notificaciones set leida=true,leida_en=coalesce(leida_en,now()),ciclo_estado='archivado',archivado_en=coalesce(archivado_en,now())
  where subject_id=v_id and club_id is null and coalesce((datos->>'requiere_accion')::boolean,false);
 end if;
 if tg_op='UPDATE' and old.estado is distinct from new.estado and v_account is not null then
  insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,subject_type,subject_id)
  values(null,v_account,'verification-result:'||v_kind||':'||v_id::text||':'||new.estado,'verificacion','Estado de verificación actualizado',
   'Resultado de revisión: '||new.estado,'personal-profile',
   jsonb_build_object('estado',new.estado,'requiere_accion',new.estado in ('needs_information','rechazada')),v_kind,v_id)
  on conflict (perfil_id,clave) where club_id is null and perfil_id is not null and clave is not null
  do update set leida=false,leida_en=null,creado_en=now(),cuerpo=excluded.cuerpo,datos=excluded.datos;
 end if;
 return new;
end $$;
revoke all on function public.app_kombax_owner_verification_lifecycle_r118() from public,anon,authenticated;
drop trigger if exists owner_verification_queue_r118 on public.kombax_solicitudes_alta;
create trigger owner_verification_queue_r118 after insert or update of estado on public.kombax_solicitudes_alta for each row execute function public.app_kombax_owner_verification_lifecycle_r118();
drop trigger if exists owner_credential_queue_r118 on public.kombax_professional_credentials_v198;
create trigger owner_credential_queue_r118 after insert or update of estado on public.kombax_professional_credentials_v198 for each row execute function public.app_kombax_owner_verification_lifecycle_r118();
drop trigger if exists owner_document_queue_r118 on public.kombax_verificacion_documentos;
create trigger owner_document_queue_r118 after insert or update of estado on public.kombax_verificacion_documentos for each row execute function public.app_kombax_owner_verification_lifecycle_r118();
drop trigger if exists owner_evidence_queue_r118 on public.kombax_professional_credential_evidence_r118;
create trigger owner_evidence_queue_r118 after insert or update of estado on public.kombax_professional_credential_evidence_r118 for each row execute function public.app_kombax_owner_verification_lifecycle_r118();

create or replace function public.app_kombax_owner_verification_claim_r118()
returns jsonb language plpgsql security definer set search_path='' as $$
declare j kombax_owner_ai.verification_jobs_r118;
begin
 if auth.role()<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED';end if;
 -- Do not overwrite a completed turn after a caller disconnects: retry will consume its audited result.
 select * into j from kombax_owner_ai.verification_jobs_r118 where status='queued' or (status='processing' and lease_until<now()) order by updated_at for update skip locked limit 1;
 if j.id is null then return jsonb_build_object('ok',true,'job',null);end if;
 update kombax_owner_ai.verification_jobs_r118 set status='processing',attempts=attempts+1,lease_until=now()+interval '5 minutes',updated_at=now() where id=j.id returning * into j;
 return jsonb_build_object('ok',true,'job',to_jsonb(j));
end $$;
revoke all on function public.app_kombax_owner_verification_claim_r118() from public,anon,authenticated;
grant execute on function public.app_kombax_owner_verification_claim_r118() to service_role;

create or replace function public.app_kombax_owner_verification_job_start_r118(p_job_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare j kombax_owner_ai.verification_jobs_r118;v_result jsonb;v_sub text:=current_setting('request.jwt.claim.sub',true);
 v_message text:='Analiza todos los documentos de esta solicitud. Verifica legibilidad, pertinencia, identidad y vigencia. Propón verificación automática únicamente si todos los requisitos se cumplen sin dudas; en otro caso solicita revisión manual.';
begin
 if auth.role()<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED';end if;
 select * into j from kombax_owner_ai.verification_jobs_r118 where id=p_job_id and status='processing' for update;
 if j.id is null then raise exception 'VERIFICATION_JOB_NOT_CLAIMED';end if;
 perform set_config('request.jwt.claim.sub',j.requested_by::text,true);
 if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
 if j.turn_id is null then
  if j.context_type='professional_credential' then
   v_result:=public.app_kombax_owner_credential_turn_start_r118('owner_operations',v_message,j.context_type,j.context_id,'low',null,gen_random_uuid());
  else
   v_result:=public.app_kombax_owner_agent_turn_start_r105('owner_operations',v_message,j.context_type,j.context_id,'low',null,gen_random_uuid());
  end if;
  j.turn_id:=(v_result->>'turn_id')::uuid;
  update kombax_owner_ai.verification_jobs_r118 set turn_id=j.turn_id where id=j.id;
 else
  select jsonb_build_object('turn_id',t.id,'conversation_id',t.conversation_id,'already_completed',t.status='completed','already_failed',t.status='failed') into v_result from kombax_owner_ai.agent_turns t where t.id=j.turn_id;
 end if;
 perform set_config('request.jwt.claim.sub',coalesce(v_sub,''),true);
 return v_result||jsonb_build_object('context_type',j.context_type,'context_id',j.context_id,'message',v_message);
exception when others then perform set_config('request.jwt.claim.sub',coalesce(v_sub,''),true);raise;
end $$;
revoke all on function public.app_kombax_owner_verification_job_start_r118(uuid) from public,anon,authenticated;
grant execute on function public.app_kombax_owner_verification_job_start_r118(uuid) to service_role;

create or replace function public.app_kombax_owner_verification_apply_r118(p_turn_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t kombax_owner_ai.agent_turns;v_ctx jsonb;v_docs jsonb;v_result jsonb;v_action jsonb;
 v_sub text:=current_setting('request.jwt.claim.sub',true);v_reason text;v_profile uuid;v_count int;v_claims jsonb;v_dob date;v_approved boolean:=false;
begin
 if auth.role()<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED';end if;
 select * into t from kombax_owner_ai.agent_turns where id=p_turn_id for update;
 select result into v_result from kombax_owner_ai.verification_actions_r118 where turn_id=p_turn_id;
 if v_result is not null then return v_result;end if;
 if t.id is null or t.status<>'completed' then raise exception 'OWNER_AGENT_TURN_NOT_COMPLETED';end if;
 if (t.context_type='professional_credential' and exists(select 1 from public.kombax_professional_credentials_v198 where id=t.context_id and estado<>'pendiente')) or
    (t.context_type='platform_application' and exists(select 1 from public.kombax_solicitudes_alta where id=t.context_id and estado not in ('submitted','under_review'))) then
  v_result:=jsonb_build_object('ok',true,'approved',false,'manual_required',false,'already_resolved',true,'turn_id',t.id);
  insert into kombax_owner_ai.verification_actions_r118(turn_id,context_type,context_id,owner_id,approved,result)
  values(t.id,t.context_type,t.context_id,t.requested_by,false,v_result);
  return v_result;
 end if;
 v_action:=coalesce(t.proposed_action,'{}'::jsonb);
 v_reason:='La IA no ha confirmado todos los requisitos; revisión manual necesaria.';
 if t.agent='owner_operations' and t.context_type in ('platform_application','professional_credential') and
  t.risk_level='low' and t.confidence>=0.90 and v_action->>'action'='recommend_status' and
  v_action->>'status' in ('verified','verificada') and v_action->>'target_id'=t.context_id::text and
  v_action->>'target_type'=t.context_type and v_action->>'requires_human'='false' then
  begin
   perform set_config('request.jwt.claim.sub',t.requested_by::text,true);
   if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
   if t.context_type='professional_credential' then
    select professional_profile_id into v_profile from public.kombax_professional_credentials_v198 where id=t.context_id and estado='pendiente' for update;
    if v_profile is null then raise exception 'CREDENTIAL_NOT_PENDING';end if;
    select coalesce(p.fecha_nacimiento,a.fecha_nacimiento) into v_dob
    from public.perfiles_kombax_directos d left join public.kombax_perfil_persona_privada_v196 p on p.perfil_directo_id=d.id
    left join public.kombax_account_private_r117 a on a.perfil_id=d.perfil_id where d.id=v_profile;
    if v_dob is null or v_dob>current_date-interval '18 years' then raise exception 'ADULT_ACCOUNT_REQUIRED';end if;
    perform 1 from public.kombax_professional_credential_evidence_r118 where credential_id=t.context_id and estado='active' for share;
   else
    perform 1 from public.kombax_solicitudes_alta where id=t.context_id and estado in ('submitted','under_review') and tipo not in ('club','federacion') for update;
    if not found then raise exception 'APPLICATION_REQUIRES_OWNER_REVIEW';end if;
    select p.fecha_nacimiento into v_dob from public.kombax_account_private_r117 p join public.kombax_solicitudes_alta a on a.perfil_id=p.perfil_id where a.id=t.context_id;
    if v_dob is null or v_dob>current_date-interval '18 years' then raise exception 'ADULT_ACCOUNT_REQUIRED';end if;
    perform 1 from public.kombax_verificacion_documentos where solicitud_id=t.context_id and estado='active' for share;
   end if;
   v_ctx:=public.app_kombax_owner_verification_context_r118(t.id);v_docs:=v_ctx->'verification_documents';
   v_count:=jsonb_array_length(v_docs);
   if v_count<1 or v_count>3 then raise exception 'COMPLETE_DOCUMENT_REVIEW_REQUIRED';end if;
   if jsonb_typeof(v_action->'document_checks') is distinct from 'array' or jsonb_array_length(v_action->'document_checks')<>v_count then raise exception 'DOCUMENT_CHECKS_REQUIRED';end if;
   if exists(select 1 from jsonb_array_elements(v_docs) d where not exists(
    select 1 from jsonb_array_elements(v_action->'document_checks') c where c->>'id'=d->>'id' and c->>'readable'='true'
    and c->>'relevant'='true' and c->>'uncertain'='false' and c->>'document_type' in ('license','certificate','accreditation','identity')
   ) or not exists(select 1 from storage.objects o where o.bucket_id='kombax-verification-docs' and o.name=d->>'storage_path')) then raise exception 'DOCUMENT_NOT_VERIFIABLE';end if;
   if t.context_type='professional_credential' and not exists(select 1 from jsonb_array_elements(v_action->'document_checks') c
    where c->>'document_type' in ('license','certificate','accreditation')) then raise exception 'PROFESSIONAL_ACCREDITATION_REQUIRED';end if;
   if v_action->>'all_documents_read' is distinct from 'true' then raise exception 'DOCUMENT_READ_NOT_CONFIRMED';end if;
   if t.context_type='professional_credential' then
    v_result:=public.app_kombax_professional_credential_mutate_r118('professional.credential.review',jsonb_build_object('professional_profile_id',v_profile,'credential_id',t.context_id,'decision','verificada','review_note','AI pilot · turn '||t.id::text),t.id);
   else
    perform public.app_kombax_application_validate_v196(t.context_id);
    v_result:=public.app_kombax_perfil_mutate_v196('kombax.application.review',jsonb_build_object('solicitud_id',t.context_id,'estado','verified','motivo','AI pilot · turn '||t.id::text),t.id);
   end if;
   v_approved:=true;v_reason:='Documentos legibles y pertinentes; validación automática auditada. Turno '||t.id::text;
  exception when others then v_approved:=false;v_reason:='Revisión manual necesaria: '||left(sqlerrm,240);
  end;
 end if;
 perform set_config('request.jwt.claim.sub',coalesce(v_sub,''),true);
 v_result:=jsonb_build_object('ok',true,'approved',v_approved,'manual_required',not v_approved,'reason',v_reason,'turn_id',t.id);
 insert into kombax_owner_ai.verification_actions_r118(turn_id,context_type,context_id,owner_id,approved,result)
 values(t.id,coalesce(t.context_type,'platform_summary'),coalesce(t.context_id,t.id),t.requested_by,v_approved,v_result);
 if t.context_type in ('platform_application','professional_credential') then perform public.app_kombax_owner_verification_notify_r118(t.context_type,t.context_id,t.requested_by,v_approved,v_reason);end if;
 return v_result;
exception when others then perform set_config('request.jwt.claim.sub',coalesce(v_sub,''),true);raise;
end $$;
revoke all on function public.app_kombax_owner_verification_apply_r118(uuid) from public,anon,authenticated;
grant execute on function public.app_kombax_owner_verification_apply_r118(uuid) to service_role;

create or replace function public.app_kombax_owner_verification_job_finish_r118(p_job_id uuid,p_result jsonb,p_error text default null)
returns void language plpgsql security definer set search_path='' as $$
declare j kombax_owner_ai.verification_jobs_r118;
begin
 if auth.role()<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED';end if;
 select * into j from kombax_owner_ai.verification_jobs_r118 where id=p_job_id for update;
 if j.id is null or j.status<>'processing' then return;end if;
 if p_error is not null then
  if j.attempts<3 then
   update kombax_owner_ai.verification_jobs_r118 set status='queued',turn_id=null,lease_until=null,result=jsonb_build_object('error',left(p_error,300)),updated_at=now() where id=j.id;return;
  end if;
  perform public.app_kombax_owner_verification_notify_r118(j.context_type,j.context_id,j.requested_by,false,'El análisis automático no pudo completarse. Se conserva la revisión manual.');
 end if;
 update kombax_owner_ai.verification_jobs_r118 set status=case when p_error is null and p_result->>'approved'='true' then 'completed' else 'manual' end,lease_until=null,result=coalesce(p_result,jsonb_build_object('error',left(p_error,300))),updated_at=now() where id=j.id;
end $$;
revoke all on function public.app_kombax_owner_verification_job_finish_r118(uuid,jsonb,text) from public,anon,authenticated;
grant execute on function public.app_kombax_owner_verification_job_finish_r118(uuid,jsonb,text) to service_role;

-- Backfill only pending work, never already verified applications.
select public.app_kombax_owner_verification_enqueue_r118('platform_application',id) from public.kombax_solicitudes_alta where estado in ('submitted','under_review');
select public.app_kombax_owner_verification_enqueue_r118('professional_credential',id) from public.kombax_professional_credentials_v198 where estado='pendiente';
notify pgrst,'reload schema';
commit;
