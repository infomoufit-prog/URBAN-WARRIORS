-- KOMBAX R118 · Phase 4 · professional credential governance
-- Additive and non-destructive. No existing credential rows existed at migration design time.

alter table public.kombax_professional_credentials_v198
  add column if not exists verification_url text,
  add column if not exists public_visible boolean not null default false,
  add column if not exists public_reference_visible boolean not null default true,
  add column if not exists verified_by uuid references public.perfiles(id) on delete set null,
  add column if not exists verified_at timestamptz,
  add column if not exists review_note text;

do $$
begin
  if not exists(
    select 1 from pg_constraint
    where conrelid='public.kombax_professional_credentials_v198'::regclass
      and conname='kombax_professional_credentials_verification_url_r118'
  ) then
    alter table public.kombax_professional_credentials_v198
      add constraint kombax_professional_credentials_verification_url_r118
      check (verification_url is null or verification_url ~* '^https://[^[:space:]]+$');
  end if;
end $$;

create table if not exists public.kombax_professional_credential_evidence_r118(
  id uuid primary key default gen_random_uuid(),
  credential_id uuid not null references public.kombax_professional_credentials_v198(id) on delete cascade,
  professional_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
  storage_path text not null unique,
  mime_type text not null check (mime_type in ('application/pdf','image/jpeg','image/png','image/webp')),
  size_bytes bigint not null check (size_bytes>0 and size_bytes<=15728640),
  estado text not null default 'active' check (estado in ('active','withdrawn')),
  creado_por uuid not null references public.perfiles(id) on delete cascade,
  creado_en timestamptz not null default now(),
  retirado_en timestamptz
);
create index if not exists idx_kombax_prof_credential_evidence_active_r118
  on public.kombax_professional_credential_evidence_r118(credential_id,creado_en desc)
  where estado='active';

alter table public.kombax_professional_credential_evidence_r118 enable row level security;
revoke all on public.kombax_professional_credential_evidence_r118 from anon,authenticated;

create table if not exists public.kombax_professional_credential_acceptances_r118(
  id uuid primary key default gen_random_uuid(),
  credential_id uuid not null references public.kombax_professional_credentials_v198(id) on delete cascade,
  professional_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  declaration_version text not null,
  declaration_text text not null,
  user_agent text,
  accepted_at timestamptz not null default now()
);
create index if not exists idx_kombax_prof_credential_acceptance_r118
  on public.kombax_professional_credential_acceptances_r118(credential_id,accepted_at desc);
alter table public.kombax_professional_credential_acceptances_r118 enable row level security;
revoke all on public.kombax_professional_credential_acceptances_r118 from anon,authenticated;

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

create or replace function public.app_kombax_professional_credential_queue_r118()
returns jsonb
language plpgsql
stable security definer
set search_path to 'public','auth'
as $function$
declare v jsonb;
begin
  if not public.app_kombax_es_verificador_v117() then raise exception 'KOMBAX_VERIFIER_REQUIRED'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'professional_profile_id',c.professional_profile_id,'professional_name',d.nombre_publico,
    'specialty_code',c.specialty_code,'credential_type',c.credential_type,'issuer',c.issuer,
    'reference_public',c.reference_public,'verification_url',c.verification_url,'expires_on',c.expires_on,
    'estado',c.estado,'submitted_at',c.actualizado_en,
    'evidence',coalesce((select jsonb_agg(jsonb_build_object(
      'id',e.id,'storage_path',e.storage_path,'mime_type',e.mime_type,'size_bytes',e.size_bytes,'created_at',e.creado_en
    ) order by e.creado_en) from public.kombax_professional_credential_evidence_r118 e where e.credential_id=c.id and e.estado='active'),'[]'::jsonb),
    'acceptance',coalesce((select jsonb_build_object(
      'version',a.declaration_version,'accepted_at',a.accepted_at
    ) from public.kombax_professional_credential_acceptances_r118 a where a.credential_id=c.id order by a.accepted_at desc limit 1),'{}'::jsonb)
  ) order by c.actualizado_en),'[]'::jsonb) into v
  from public.kombax_professional_credentials_v198 c
  join public.perfiles_kombax_directos d on d.id=c.professional_profile_id
  where c.estado='pendiente';
  return jsonb_build_object('ok',true,'credentials',v);
end
$function$;

create or replace function public.app_kombax_professional_public_credentials_r118(p_profile_id uuid)
returns table(
  credential_id uuid,
  specialty_code text,
  credential_type text,
  issuer text,
  reference_public text,
  verification_url text,
  expires_on date,
  verified_at timestamptz
)
language sql
stable security definer
set search_path to 'public'
as $function$
  select c.id,c.specialty_code,c.credential_type,c.issuer,
         case when c.public_reference_visible then nullif(c.reference_public,'') else null end,
         c.verification_url,c.expires_on,c.verified_at
  from public.kombax_professional_credentials_v198 c
  join public.perfiles_kombax_directos d on d.id=c.professional_profile_id
  where c.professional_profile_id=p_profile_id
    and d.tipo='profesional' and d.estado='activo' and d.publico
    and c.estado='verificada' and c.public_visible
    and (c.expires_on is null or c.expires_on>=current_date)
  order by c.verified_at desc nulls last,c.creado_en desc;
$function$;

revoke all on function public.app_kombax_professional_workspace_r118(uuid) from public;
revoke all on function public.app_kombax_professional_credential_mutate_r118(text,jsonb,uuid) from public;
revoke all on function public.app_kombax_professional_credential_queue_r118() from public;
grant execute on function public.app_kombax_professional_workspace_r118(uuid) to authenticated;
grant execute on function public.app_kombax_professional_credential_mutate_r118(text,jsonb,uuid) to authenticated;
grant execute on function public.app_kombax_professional_credential_queue_r118() to authenticated;
grant execute on function public.app_kombax_professional_public_credentials_r118(uuid) to anon,authenticated;

comment on table public.kombax_professional_credential_evidence_r118 is
'Private evidence for a single professional credential. Storage objects remain private; owner/verifier access follows kombax-verification-docs policy.';
comment on table public.kombax_professional_credential_acceptances_r118 is
'Immutable acceptance snapshots for professional credential truthfulness declarations.';

do $$
begin
  if exists(select 1 from public.kombax_professional_credentials_v198 where estado='verified') then
    raise exception 'R118_ASSERT_INVALID_ENGLISH_CREDENTIAL_STATE_PRESENT';
  end if;
end $$;
