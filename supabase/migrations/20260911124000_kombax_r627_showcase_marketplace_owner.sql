-- KOMBAX 20.110 R62.7 · Showcase Marketplace, Seller Center, buyer trust and Owner Control Center
-- QA-ready implementation. Contractual wording is an operational draft and requires legal review before public production.

begin;

create schema if not exists kombax_marketplace;
revoke all on schema kombax_marketplace from public,anon,authenticated;
grant usage on schema kombax_marketplace to service_role;

create table if not exists kombax_marketplace.policy_documents(
  policy_code text not null,
  version text not null,
  title text not null,
  body text not null,
  audience text not null check(audience in('seller','buyer','both')),
  required_for_seller boolean not null default false,
  required_for_buyer boolean not null default false,
  status text not null default 'draft' check(status in('draft','active','retired')),
  legal_review_status text not null default 'pending' check(legal_review_status in('pending','approved','rejected')),
  effective_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(policy_code,version)
);

create table if not exists kombax_marketplace.policy_acceptances(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.perfiles(id) on delete restrict,
  provider_id uuid references public.kombax_showcase_marcas(id) on delete restrict,
  policy_code text not null,
  policy_version text not null,
  acceptance_scope text not null check(acceptance_scope in('seller','buyer')),
  accepted_at timestamptz not null default now(),
  context jsonb not null default '{}'::jsonb,
  unique(user_id,provider_id,policy_code,policy_version,acceptance_scope),
  foreign key(policy_code,policy_version) references kombax_marketplace.policy_documents(policy_code,version) on delete restrict
);
create index if not exists idx_marketplace_policy_acceptances_provider on kombax_marketplace.policy_acceptances(provider_id,accepted_at desc);
create index if not exists idx_marketplace_policy_acceptances_user on kombax_marketplace.policy_acceptances(user_id,accepted_at desc);
create unique index if not exists uq_marketplace_buyer_policy_acceptance on kombax_marketplace.policy_acceptances(user_id,policy_code,policy_version,acceptance_scope) where provider_id is null;

create table if not exists kombax_marketplace.seller_applications(
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null unique references public.kombax_showcase_marcas(id) on delete restrict,
  applicant_user_id uuid not null references public.perfiles(id) on delete restrict,
  base_verification_application_id uuid references public.kombax_solicitudes_alta(id) on delete set null,
  seller_type text not null check(seller_type in('club','marca')),
  legal_name text not null,
  tax_id text not null,
  country text not null default 'ES',
  registered_address text not null,
  support_email text not null,
  support_phone text not null,
  returns_contact text,
  shipping_modes text[] not null default '{}'::text[],
  compliance_statement boolean not null default false,
  marketplace_statement boolean not null default false,
  status text not null default 'draft' check(status in('draft','submitted','under_review','needs_information','verified','limited','suspended','rejected')),
  review_note text,
  reviewed_by uuid references public.perfiles(id) on delete restrict,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_marketplace_seller_apps_status on kombax_marketplace.seller_applications(status,updated_at desc);

create table if not exists kombax_marketplace.seller_events(
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references kombax_marketplace.seller_applications(id) on delete restrict,
  actor_user_id uuid not null references public.perfiles(id) on delete restrict,
  event_type text not null,
  from_status text,
  to_status text,
  detail jsonb not null default '{}'::jsonb,
  request_id uuid unique,
  created_at timestamptz not null default now()
);
create index if not exists idx_marketplace_seller_events_app on kombax_marketplace.seller_events(application_id,created_at desc);

create table if not exists kombax_marketplace.buyer_identity_requests(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.perfiles(id) on delete restrict,
  full_name text not null,
  country text not null default 'ES',
  reason text,
  status text not null default 'submitted' check(status in('submitted','under_review','needs_information','verified','rejected')),
  review_note text,
  reviewed_by uuid references public.perfiles(id) on delete restrict,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists uq_marketplace_buyer_open_request on kombax_marketplace.buyer_identity_requests(user_id) where status in('submitted','under_review','needs_information','verified');
create index if not exists idx_marketplace_buyer_requests_status on kombax_marketplace.buyer_identity_requests(status,updated_at desc);

create table if not exists kombax_marketplace.buyer_identity_documents(
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references kombax_marketplace.buyer_identity_requests(id) on delete restrict,
  user_id uuid not null references public.perfiles(id) on delete restrict,
  document_type text not null check(document_type in('identity','residence','other')),
  storage_path text not null unique,
  mime_type text not null,
  bytes bigint not null check(bytes>0 and bytes<=15728640),
  status text not null default 'active' check(status in('active','removed')),
  created_at timestamptz not null default now()
);
create index if not exists idx_marketplace_buyer_docs_request on kombax_marketplace.buyer_identity_documents(request_id,created_at desc);

create table if not exists kombax_marketplace.buyer_events(
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references kombax_marketplace.buyer_identity_requests(id) on delete restrict,
  actor_user_id uuid not null references public.perfiles(id) on delete restrict,
  event_type text not null,
  from_status text,
  to_status text,
  detail jsonb not null default '{}'::jsonb,
  request_token uuid unique,
  created_at timestamptz not null default now()
);
create index if not exists idx_marketplace_buyer_events_request on kombax_marketplace.buyer_events(request_id,created_at desc);

revoke all on all tables in schema kombax_marketplace from public,anon,authenticated;
grant all on all tables in schema kombax_marketplace to service_role;

insert into kombax_marketplace.policy_documents(policy_code,version,title,body,audience,required_for_seller,required_for_buyer,status,legal_review_status,effective_at)
values
('marketplace_terms','1.0-qa','Condiciones de KOMBAX Showcase',
'BORRADOR OPERATIVO PARA QA · REVISIÓN JURÍDICA OBLIGATORIA ANTES DE PRODUCCIÓN. KOMBAX Showcase es una infraestructura tecnológica que facilita la publicación de productos, el contacto, el checkout y la gestión de pedidos entre vendedores independientes y compradores. La compraventa se celebra entre comprador y vendedor. KOMBAX no adquiere la propiedad de los productos, no mantiene inventario de los vendedores y no es el vendedor del producto. KOMBAX mantiene sus propias obligaciones como prestador de la plataforma y no pretende excluir responsabilidades que legalmente no puedan excluirse. KOMBAX puede retirar contenidos, limitar o suspender cuentas, pedir información adicional, conservar trazabilidad legal y colaborar frente a fraude, seguridad, requerimientos de autoridades o incumplimientos de estas condiciones.',
'both',true,true,'active','pending',now()),
('seller_agreement','1.0-qa','Acuerdo de vendedor KOMBAX Showcase',
'BORRADOR OPERATIVO PARA QA · REVISIÓN JURÍDICA OBLIGATORIA ANTES DE PRODUCCIÓN. El vendedor declara que actúa por cuenta propia y que dispone de capacidad para comercializar los productos que publica. El vendedor responde de la identidad y legitimidad del negocio, la exactitud de la descripción, autenticidad, seguridad y legalidad del producto, precio, impuestos, disponibilidad y stock, preparación, entrega, garantías, devoluciones, atención posventa y cumplimiento de la normativa aplicable. Los pagos se procesan mediante Stripe para la cuenta conectada del vendedor. KOMBAX no cobra comisión por cada compraventa en el modelo actualmente configurado y monetiza el acceso y herramientas de la plataforma mediante sus planes o servicios. El vendedor autoriza a KOMBAX a solicitar documentación, suspender la capacidad de venta, retirar productos e investigar incidencias cuando existan señales de fraude, riesgo, incumplimiento o requerimiento legal. Nada de este acuerdo elimina responsabilidades propias de KOMBAX que no puedan excluirse por ley.',
'seller',true,false,'active','pending',now()),
('buyer_protection','1.0-qa','Política de comprador, incidencias y devoluciones',
'BORRADOR OPERATIVO PARA QA · REVISIÓN JURÍDICA OBLIGATORIA ANTES DE PRODUCCIÓN. El comprador identifica claramente al vendedor antes de pagar. El vendedor es responsable de la entrega, garantía, devolución y servicio posventa conforme a su política y a la normativa aplicable. KOMBAX ofrece trazabilidad del pedido, canal de incidencias y herramientas de moderación, pero no sustituye las obligaciones del vendedor. El comprador debe comunicar incidencias de buena fe y conservar la información necesaria del pedido. KOMBAX puede limitar cuentas, bloquear productos o colaborar con Stripe y las autoridades cuando existan indicios de fraude o riesgo.',
'buyer',false,true,'active','pending',now()),
('prohibited_products','1.0-qa','Política de productos permitidos y prohibidos',
'BORRADOR OPERATIVO PARA QA · REVISIÓN JURÍDICA OBLIGATORIA ANTES DE PRODUCCIÓN. No se permite publicar o vender productos ilegales, falsificados, robados, peligrosos sin autorización, armas o artículos restringidos cuando su venta no sea legal, sustancias o medicamentos sujetos a prescripción o control sin autorización, material que infrinja propiedad intelectual, productos cuya descripción sea engañosa ni artículos prohibidos por la normativa aplicable o por las políticas de Stripe. KOMBAX puede retirar preventivamente una ficha mientras se revisa su cumplimiento.',
'seller',true,false,'active','pending',now())
on conflict(policy_code,version) do update set title=excluded.title,body=excluded.body,audience=excluded.audience,required_for_seller=excluded.required_for_seller,required_for_buyer=excluded.required_for_buyer,status=excluded.status,legal_review_status=excluded.legal_review_status,effective_at=excluded.effective_at,updated_at=now();

create or replace function kombax_marketplace.is_owner_r627(p_actor uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.kombax_platform_admins a where a.perfil_id=p_actor and a.activo);
$$;

create or replace function kombax_marketplace.base_verification_r627(p_provider uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.kombax_showcase_marcas;v public.kombax_solicitudes_alta;
begin
  select * into m from public.kombax_showcase_marcas where id=p_provider;
  if m.id is null then return '{}'::jsonb; end if;
  if m.sujeto_tipo='club' then
    select * into v from public.kombax_solicitudes_alta s where s.club_id=m.club_id and s.tipo='club' and s.estado='verified' order by s.revisado_en desc nulls last,s.actualizado_en desc limit 1;
  else
    select * into v from public.kombax_solicitudes_alta s where s.perfil_directo_id=m.perfil_directo_id and s.tipo='marca' and s.estado='verified' order by s.revisado_en desc nulls last,s.actualizado_en desc limit 1;
  end if;
  if v.id is null then return jsonb_build_object('verified',false); end if;
  return jsonb_build_object(
    'verified',true,'application_id',v.id,'type',v.tipo,'name',v.nombre_publico,
    'legal_name',coalesce(v.datos_verificacion->>'nombre_legal',v.nombre_publico),
    'tax_id',coalesce(v.datos_verificacion->>'cif',''),
    'country',coalesce(v.datos_publicos->>'pais','España'),
    'registered_address',coalesce(v.datos_verificacion->>'direccion',''),
    'support_email',coalesce(v.datos_verificacion->>'email_oficial',''),
    'support_phone',coalesce(v.datos_verificacion->>'telefono',''),
    'responsible',coalesce(v.datos_verificacion->>'responsable',''),
    'responsible_role',coalesce(v.datos_verificacion->>'rol_responsable','')
  );
end $$;

create or replace function kombax_marketplace.seller_policies_ready_r627(p_provider uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select not exists(
    select 1 from kombax_marketplace.policy_documents p
    where p.status='active' and p.required_for_seller
      and not exists(
        select 1 from kombax_marketplace.policy_acceptances a
        where a.provider_id=p_provider and a.policy_code=p.policy_code and a.policy_version=p.version and a.acceptance_scope='seller'
      )
  );
$$;

create or replace function kombax_marketplace.seller_ready_r627(p_provider uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.kombax_showcase_marcas m where m.id=p_provider and m.verificada and m.estado='publicada')
    and exists(select 1 from kombax_marketplace.seller_applications s where s.provider_id=p_provider and s.status='verified')
    and kombax_marketplace.seller_policies_ready_r627(p_provider)
    and exists(select 1 from kombax_payments.connected_accounts a where a.subject_type='showcase_provider' and a.subject_id=p_provider and a.status='active' and a.charges_enabled and a.payouts_enabled);
$$;

create or replace function public.app_showcase_seller_center_r627(p_provider_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());m public.kombax_showcase_marcas;s kombax_marketplace.seller_applications;v_base jsonb;v_policies jsonb;v_stripe jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into m from public.kombax_showcase_marcas where id=p_provider_id;
  if m.id is null then raise exception 'SHOWCASE_PROVIDER_NOT_FOUND'; end if;
  if not kombax_payments.can_manage_provider(v_uid,p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  select * into s from kombax_marketplace.seller_applications where provider_id=p_provider_id;
  v_base:=kombax_marketplace.base_verification_r627(p_provider_id);
  select coalesce(jsonb_agg(jsonb_build_object(
    'code',p.policy_code,'version',p.version,'title',p.title,'body',p.body,'legal_review_status',p.legal_review_status,
    'required',p.required_for_seller,'accepted',exists(select 1 from kombax_marketplace.policy_acceptances a where a.provider_id=p_provider_id and a.policy_code=p.policy_code and a.policy_version=p.version and a.acceptance_scope='seller'),
    'accepted_at',(select max(a.accepted_at) from kombax_marketplace.policy_acceptances a where a.provider_id=p_provider_id and a.policy_code=p.policy_code and a.policy_version=p.version and a.acceptance_scope='seller')
  ) order by p.policy_code),'[]'::jsonb) into v_policies from kombax_marketplace.policy_documents p where p.status='active' and p.required_for_seller;
  select jsonb_build_object('status',a.status,'details_submitted',a.details_submitted,'charges_enabled',a.charges_enabled,'payouts_enabled',a.payouts_enabled,'requirements_due',a.requirements_due,'requirements_pending_verification',a.requirements_pending_verification,'disabled_reason',a.disabled_reason,'charge_model',a.charge_model,'fees_payer',a.stripe_fees_payer,'losses_responsibility',a.losses_responsibility,'dashboard_type',a.stripe_dashboard_type) into v_stripe
  from kombax_payments.connected_accounts a where a.subject_type='showcase_provider' and a.subject_id=p_provider_id order by a.updated_at desc limit 1;
  return jsonb_build_object(
    'ok',true,
    'provider',jsonb_build_object('id',m.id,'name',m.nombre,'type',m.sujeto_tipo,'verified',m.verificada,'state',m.estado),
    'base_verification',coalesce(v_base,'{}'::jsonb),
    'application',case when s.id is null then null else to_jsonb(s) end,
    'policies',coalesce(v_policies,'[]'::jsonb),
    'stripe',coalesce(v_stripe,jsonb_build_object('status','not_configured','charges_enabled',false,'payouts_enabled',false)),
    'checks',jsonb_build_object(
      'identity_verified',coalesce((v_base->>'verified')::boolean,false) and m.verificada and m.estado='publicada',
      'seller_verified',coalesce(s.status='verified',false),
      'policies_accepted',kombax_marketplace.seller_policies_ready_r627(p_provider_id),
      'stripe_ready',coalesce((v_stripe->>'charges_enabled')::boolean,false) and coalesce((v_stripe->>'payouts_enabled')::boolean,false) and coalesce(v_stripe->>'status','')='active',
      'selling_ready',kombax_marketplace.seller_ready_r627(p_provider_id)
    )
  );
end $$;

create or replace function public.app_showcase_seller_application_mutate_r627(p_provider_id uuid,p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());m public.kombax_showcase_marcas;s kombax_marketplace.seller_applications;v_base jsonb;v_old text;v_new text;v_shipping text[];v_existing uuid;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  select e.id into v_existing from kombax_marketplace.seller_events e where e.request_id=p_request_id;
  if v_existing is not null then select * into s from kombax_marketplace.seller_applications where provider_id=p_provider_id; return jsonb_build_object('ok',true,'request_id',p_request_id,'data',to_jsonb(s),'reused',true); end if;
  select * into m from public.kombax_showcase_marcas where id=p_provider_id;
  if m.id is null then raise exception 'SHOWCASE_PROVIDER_NOT_FOUND'; end if;
  if not kombax_payments.can_manage_provider(v_uid,p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  if m.sujeto_tipo not in('club','marca') then raise exception 'SHOWCASE_SELLER_TYPE_NOT_SUPPORTED'; end if;
  v_base:=kombax_marketplace.base_verification_r627(p_provider_id);
  if lower(coalesce(p_operation,'')) not in('save','submit') then raise exception 'SELLER_OPERATION_INVALID'; end if;
  if lower(p_operation)='submit' and not coalesce((v_base->>'verified')::boolean,false) then raise exception 'KOMBAX_BASE_VERIFICATION_REQUIRED'; end if;
  v_shipping:=coalesce(array(select distinct x from jsonb_array_elements_text(coalesce(p_payload->'shipping_modes','[]'::jsonb)) x where x in('seller_shipping','seller_pickup','digital') limit 4),'{}'::text[]);
  select * into s from kombax_marketplace.seller_applications where provider_id=p_provider_id for update;
  v_old:=s.status;
  v_new:=case when lower(p_operation)='submit' then 'submitted' else 'draft' end;
  if s.id is null then
    insert into kombax_marketplace.seller_applications(provider_id,applicant_user_id,base_verification_application_id,seller_type,legal_name,tax_id,country,registered_address,support_email,support_phone,returns_contact,shipping_modes,compliance_statement,marketplace_statement,status,submitted_at)
    values(p_provider_id,v_uid,nullif(v_base->>'application_id','')::uuid,m.sujeto_tipo,
      coalesce(nullif(btrim(p_payload->>'legal_name'),''),nullif(v_base->>'legal_name',''),m.nombre),
      coalesce(nullif(btrim(p_payload->>'tax_id'),''),nullif(v_base->>'tax_id',''),''),
      upper(left(coalesce(nullif(btrim(p_payload->>'country'),''),'ES'),2)),
      coalesce(nullif(btrim(p_payload->>'registered_address'),''),nullif(v_base->>'registered_address',''),''),
      coalesce(nullif(btrim(p_payload->>'support_email'),''),nullif(v_base->>'support_email',''),''),
      coalesce(nullif(btrim(p_payload->>'support_phone'),''),nullif(v_base->>'support_phone',''),''),
      nullif(btrim(p_payload->>'returns_contact'),''),v_shipping,
      coalesce((p_payload->>'compliance_statement')::boolean,false),coalesce((p_payload->>'marketplace_statement')::boolean,false),v_new,case when v_new='submitted' then now() else null end)
    returning * into s;
  else
    if s.status in('verified','suspended') then raise exception 'SELLER_APPLICATION_LOCKED'; end if;
    update kombax_marketplace.seller_applications set
      applicant_user_id=v_uid,base_verification_application_id=coalesce(nullif(v_base->>'application_id','')::uuid,base_verification_application_id),
      legal_name=coalesce(nullif(btrim(p_payload->>'legal_name'),''),legal_name),tax_id=coalesce(nullif(btrim(p_payload->>'tax_id'),''),tax_id),
      country=upper(left(coalesce(nullif(btrim(p_payload->>'country'),''),country),2)),registered_address=coalesce(nullif(btrim(p_payload->>'registered_address'),''),registered_address),
      support_email=coalesce(nullif(btrim(p_payload->>'support_email'),''),support_email),support_phone=coalesce(nullif(btrim(p_payload->>'support_phone'),''),support_phone),
      returns_contact=nullif(btrim(coalesce(p_payload->>'returns_contact',returns_contact)),''),shipping_modes=case when jsonb_typeof(p_payload->'shipping_modes')='array' then v_shipping else shipping_modes end,
      compliance_statement=coalesce((p_payload->>'compliance_statement')::boolean,compliance_statement),marketplace_statement=coalesce((p_payload->>'marketplace_statement')::boolean,marketplace_statement),
      status=v_new,review_note=null,submitted_at=case when v_new='submitted' then now() else submitted_at end,updated_at=now()
    where id=s.id returning * into s;
  end if;
  if lower(p_operation)='submit' then
    if char_length(btrim(s.legal_name))<2 or char_length(btrim(s.tax_id))<3 or char_length(btrim(s.registered_address))<5 or position('@' in s.support_email)<2 or char_length(btrim(s.support_phone))<6 then raise exception 'SELLER_APPLICATION_DATA_INCOMPLETE'; end if;
    if not s.compliance_statement or not s.marketplace_statement then raise exception 'SELLER_DECLARATIONS_REQUIRED'; end if;
    if cardinality(s.shipping_modes)=0 then raise exception 'SELLER_SHIPPING_MODE_REQUIRED'; end if;
  end if;
  insert into kombax_marketplace.seller_events(application_id,actor_user_id,event_type,from_status,to_status,detail,request_id)
  values(s.id,v_uid,'seller.application.'||lower(p_operation),v_old,s.status,jsonb_build_object('provider_id',p_provider_id),p_request_id);
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',to_jsonb(s));
end $$;

create or replace function public.app_showcase_seller_policy_accept_r627(p_provider_id uuid,p_policy_code text,p_policy_version text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());p kombax_marketplace.policy_documents;s kombax_marketplace.seller_applications;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if not kombax_payments.can_manage_provider(v_uid,p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  select * into p from kombax_marketplace.policy_documents where policy_code=p_policy_code and version=p_policy_version and status='active' and required_for_seller;
  if p.policy_code is null then raise exception 'SELLER_POLICY_NOT_ACTIVE'; end if;
  insert into kombax_marketplace.policy_acceptances(user_id,provider_id,policy_code,policy_version,acceptance_scope,context)
  values(v_uid,p_provider_id,p.policy_code,p.version,'seller',jsonb_build_object('request_id',p_request_id,'source','showcase_seller_center')) on conflict do nothing;
  select * into s from kombax_marketplace.seller_applications where provider_id=p_provider_id;
  if s.id is not null then insert into kombax_marketplace.seller_events(application_id,actor_user_id,event_type,from_status,to_status,detail,request_id) values(s.id,v_uid,'seller.policy.accepted',s.status,s.status,jsonb_build_object('policy_code',p.policy_code,'policy_version',p.version),p_request_id) on conflict(request_id) do nothing; end if;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'policy_code',p.policy_code,'policy_version',p.version,'accepted',true);
end $$;

create or replace function public.app_kombax_buyer_trust_r627()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());r kombax_marketplace.buyer_identity_requests;v_policies jsonb;v_payment boolean;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select exists(select 1 from kombax_payments.payment_attempts a where a.actor_user_id=v_uid and a.status='succeeded') into v_payment;
  select * into r from kombax_marketplace.buyer_identity_requests where user_id=v_uid order by created_at desc limit 1;
  select coalesce(jsonb_agg(jsonb_build_object('code',p.policy_code,'version',p.version,'title',p.title,'body',p.body,'legal_review_status',p.legal_review_status,'required',p.required_for_buyer,'accepted',exists(select 1 from kombax_marketplace.policy_acceptances a where a.user_id=v_uid and a.provider_id is null and a.policy_code=p.policy_code and a.policy_version=p.version and a.acceptance_scope='buyer')) order by p.policy_code),'[]'::jsonb)
  into v_policies from kombax_marketplace.policy_documents p where p.status='active' and p.required_for_buyer;
  return jsonb_build_object('ok',true,'account_verified',true,'payment_verified',v_payment,'identity_status',coalesce(r.status,'not_requested'),'identity_verified',coalesce(r.status='verified',false),'identity_request',case when r.id is null then null else to_jsonb(r) end,'policies',coalesce(v_policies,'[]'::jsonb));
end $$;

create or replace function public.app_kombax_buyer_policy_accept_r627(p_policy_code text,p_policy_version text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());p kombax_marketplace.policy_documents;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  select * into p from kombax_marketplace.policy_documents where policy_code=p_policy_code and version=p_policy_version and status='active' and required_for_buyer;
  if p.policy_code is null then raise exception 'BUYER_POLICY_NOT_ACTIVE'; end if;
  insert into kombax_marketplace.policy_acceptances(user_id,provider_id,policy_code,policy_version,acceptance_scope,context)
  values(v_uid,null,p.policy_code,p.version,'buyer',jsonb_build_object('request_id',p_request_id,'source','showcase_buyer')) on conflict do nothing;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'accepted',true,'policy_code',p.policy_code,'policy_version',p.version);
end $$;

create or replace function public.app_kombax_buyer_identity_mutate_r627(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());r kombax_marketplace.buyer_identity_requests;v_old text;v_existing uuid;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  select e.id into v_existing from kombax_marketplace.buyer_events e where e.request_token=p_request_id;
  if v_existing is not null then select * into r from kombax_marketplace.buyer_identity_requests where user_id=v_uid order by created_at desc limit 1; return jsonb_build_object('ok',true,'request_id',p_request_id,'data',to_jsonb(r),'reused',true); end if;
  if lower(coalesce(p_operation,''))<>'submit' then raise exception 'BUYER_IDENTITY_OPERATION_INVALID'; end if;
  if char_length(btrim(coalesce(p_payload->>'full_name','')))<3 then raise exception 'BUYER_FULL_NAME_REQUIRED'; end if;
  select * into r from kombax_marketplace.buyer_identity_requests where user_id=v_uid and status in('submitted','under_review','needs_information','verified') order by created_at desc limit 1 for update;
  v_old:=r.status;
  if r.id is null then
    insert into kombax_marketplace.buyer_identity_requests(user_id,full_name,country,reason,status) values(v_uid,left(btrim(p_payload->>'full_name'),180),upper(left(coalesce(nullif(btrim(p_payload->>'country'),''),'ES'),2)),left(nullif(btrim(p_payload->>'reason'),''),800),'submitted') returning * into r;
  else
    if r.status='verified' then return jsonb_build_object('ok',true,'request_id',p_request_id,'data',to_jsonb(r)); end if;
    update kombax_marketplace.buyer_identity_requests set full_name=left(btrim(p_payload->>'full_name'),180),country=upper(left(coalesce(nullif(btrim(p_payload->>'country'),''),country),2)),reason=left(nullif(btrim(p_payload->>'reason'),''),800),status='submitted',review_note=null,submitted_at=now(),updated_at=now() where id=r.id returning * into r;
  end if;
  insert into kombax_marketplace.buyer_events(request_id,actor_user_id,event_type,from_status,to_status,detail,request_token) values(r.id,v_uid,'buyer.identity.submitted',v_old,r.status,'{}'::jsonb,p_request_id);
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',to_jsonb(r));
end $$;

create or replace function public.app_kombax_buyer_identity_document_r627(p_request_id uuid,p_document_type text,p_storage_path text,p_mime_type text,p_bytes bigint,p_request_token uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());r kombax_marketplace.buyer_identity_requests;d kombax_marketplace.buyer_identity_documents;
begin
  if v_uid is null or p_request_token is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  select * into r from kombax_marketplace.buyer_identity_requests where id=p_request_id and user_id=v_uid;
  if r.id is null then raise exception 'BUYER_IDENTITY_REQUEST_NOT_OWNED'; end if;
  if p_document_type not in('identity','residence','other') then raise exception 'BUYER_DOCUMENT_TYPE_INVALID'; end if;
  if p_storage_path is null or split_part(p_storage_path,'/',1)<>v_uid::text then raise exception 'BUYER_DOCUMENT_PATH_INVALID'; end if;
  if p_mime_type not in('application/pdf','image/jpeg','image/png','image/webp') or p_bytes<=0 or p_bytes>15728640 then raise exception 'BUYER_DOCUMENT_INVALID'; end if;
  insert into kombax_marketplace.buyer_identity_documents(request_id,user_id,document_type,storage_path,mime_type,bytes) values(r.id,v_uid,p_document_type,p_storage_path,p_mime_type,p_bytes) returning * into d;
  insert into kombax_marketplace.buyer_events(request_id,actor_user_id,event_type,from_status,to_status,detail,request_token) values(r.id,v_uid,'buyer.identity.document_added',r.status,r.status,jsonb_build_object('document_id',d.id,'document_type',d.document_type),p_request_token) on conflict(request_token) do nothing;
  return jsonb_build_object('ok',true,'request_id',p_request_token,'data',to_jsonb(d)-'storage_path');
end $$;

create or replace function public.app_kombax_marketplace_owner_dashboard_r627(p_days integer default 30)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_days int:=least(365,greatest(7,coalesce(p_days,30)));v_stats jsonb;v_sellers jsonb;v_buyers jsonb;v_series jsonb;v_policies jsonb;
begin
  if v_uid is null or not kombax_marketplace.is_owner_r627(v_uid) then raise exception 'PLATFORM_OWNER_REQUIRED'; end if;
  select jsonb_build_object(
    'providers_total',(select count(*) from public.kombax_showcase_marcas),
    'seller_applications',(select count(*) from kombax_marketplace.seller_applications),
    'seller_verified',(select count(*) from kombax_marketplace.seller_applications where status='verified'),
    'seller_ready',(select count(*) from public.kombax_showcase_marcas m where kombax_marketplace.seller_ready_r627(m.id)),
    'stripe_ready',(select count(*) from kombax_payments.connected_accounts where subject_type='showcase_provider' and status='active' and charges_enabled and payouts_enabled),
    'products_published',(select count(*) from public.kombax_showcase_elementos where estado='publicado'),
    'products_commerce',(select count(*) from public.kombax_showcase_elementos where estado='publicado' and commerce_enabled),
    'orders',(select count(*) from kombax_payments.showcase_orders where created_at>=now()-(v_days * interval '1 day')),
    'gmv_minor',(select coalesce(sum(amount_total_minor),0) from kombax_payments.showcase_orders where created_at>=now()-(v_days * interval '1 day') and status in('payment_confirmed','preparing','shipped','delivered')),
    'refunds',(select count(*) from kombax_payments.showcase_orders where created_at>=now()-(v_days * interval '1 day') and status='refunded'),
    'incidents',(select count(*) from kombax_payments.showcase_incidents where created_at>=now()-(v_days * interval '1 day')),
    'buyers',(select count(distinct buyer_user_id) from kombax_payments.showcase_orders where created_at>=now()-(v_days * interval '1 day')),
    'payment_verified_buyers',(select count(distinct actor_user_id) from kombax_payments.payment_attempts where status='succeeded' and created_at>=now()-(v_days * interval '1 day')),
    'identity_verified_buyers',(select count(*) from kombax_marketplace.buyer_identity_requests where status='verified'),
    'platform_transaction_fee_minor',0,
    'seller_approval_rate',round(100.0*(select count(*) from kombax_marketplace.seller_applications where status='verified')/nullif((select count(*) from kombax_marketplace.seller_applications),0),1),
    'seller_ready_rate',round(100.0*(select count(*) from public.kombax_showcase_marcas m where kombax_marketplace.seller_ready_r627(m.id))/nullif((select count(*) from public.kombax_showcase_marcas),0),1),
    'commerce_product_rate',round(100.0*(select count(*) from public.kombax_showcase_elementos where estado='publicado' and commerce_enabled)/nullif((select count(*) from public.kombax_showcase_elementos where estado='publicado'),0),1),
    'refund_rate',round(100.0*(select count(*) from kombax_payments.showcase_orders where created_at>=now()-(v_days * interval '1 day') and status='refunded')/nullif((select count(*) from kombax_payments.showcase_orders where created_at>=now()-(v_days * interval '1 day')),0),1),
    'incident_rate',round(100.0*(select count(*) from kombax_payments.showcase_incidents where created_at>=now()-(v_days * interval '1 day'))/nullif((select count(*) from kombax_payments.showcase_orders where created_at>=now()-(v_days * interval '1 day')),0),1)
  ) into v_stats;
  select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'provider_id',s.provider_id,'provider_name',m.nombre,'provider_type',m.sujeto_tipo,'status',s.status,'legal_name',s.legal_name,'tax_id',s.tax_id,'country',s.country,'support_email',s.support_email,'support_phone',s.support_phone,'shipping_modes',s.shipping_modes,'review_note',s.review_note,'submitted_at',s.submitted_at,'updated_at',s.updated_at,'identity_verified',coalesce((kombax_marketplace.base_verification_r627(s.provider_id)->>'verified')::boolean,false),'policies_ready',kombax_marketplace.seller_policies_ready_r627(s.provider_id),'selling_ready',kombax_marketplace.seller_ready_r627(s.provider_id)) order by s.updated_at desc),'[]'::jsonb) into v_sellers
  from kombax_marketplace.seller_applications s join public.kombax_showcase_marcas m on m.id=s.provider_id where s.status in('submitted','under_review','needs_information','verified','limited','suspended','rejected');
  select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'user_id',r.user_id,'name',r.full_name,'country',r.country,'reason',r.reason,'status',r.status,'review_note',r.review_note,'submitted_at',r.submitted_at,'updated_at',r.updated_at,'documents_count',(select count(*) from kombax_marketplace.buyer_identity_documents d where d.request_id=r.id and d.status='active')) order by r.updated_at desc),'[]'::jsonb) into v_buyers from kombax_marketplace.buyer_identity_requests r where r.status in('submitted','under_review','needs_information','verified','rejected');
  select coalesce(jsonb_agg(jsonb_build_object('date',d.metric_date,'orders',d.orders,'gmv_minor',d.gmv_minor,'incidents',d.incidents) order by d.metric_date),'[]'::jsonb) into v_series from (
    select g::date metric_date,
      (select count(*) from kombax_payments.showcase_orders o where o.created_at>=g and o.created_at<g+interval '1 day') orders,
      (select coalesce(sum(o.amount_total_minor),0) from kombax_payments.showcase_orders o where o.created_at>=g and o.created_at<g+interval '1 day' and o.status in('payment_confirmed','preparing','shipped','delivered')) gmv_minor,
      (select count(*) from kombax_payments.showcase_incidents i where i.created_at>=g and i.created_at<g+interval '1 day') incidents
    from generate_series(date_trunc('day',now())-((v_days-1) * interval '1 day'),date_trunc('day',now()),interval '1 day') g
  ) d;
  select coalesce(jsonb_agg(jsonb_build_object('code',policy_code,'version',version,'title',title,'audience',audience,'required_for_seller',required_for_seller,'required_for_buyer',required_for_buyer,'legal_review_status',legal_review_status,'status',status) order by policy_code),'[]'::jsonb) into v_policies from kombax_marketplace.policy_documents where status='active';
  return jsonb_build_object('ok',true,'days',v_days,'stats',v_stats,'seller_queue',v_sellers,'buyer_queue',v_buyers,'series',v_series,'policies',v_policies);
end $$;

create or replace function public.app_kombax_marketplace_owner_seller_review_r627(p_application_id uuid,p_status text,p_note text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());s kombax_marketplace.seller_applications;v_old text;
begin
  if v_uid is null or p_request_id is null or not kombax_marketplace.is_owner_r627(v_uid) then raise exception 'PLATFORM_OWNER_REQUIRED'; end if;
  if p_status not in('under_review','needs_information','verified','limited','suspended','rejected') then raise exception 'SELLER_REVIEW_STATUS_INVALID'; end if;
  select * into s from kombax_marketplace.seller_applications where id=p_application_id for update;
  if s.id is null then raise exception 'SELLER_APPLICATION_NOT_FOUND'; end if;
  if exists(select 1 from kombax_marketplace.seller_events e where e.request_id=p_request_id) then return jsonb_build_object('ok',true,'request_id',p_request_id,'data',to_jsonb(s),'reused',true); end if;
  if p_status='verified' then
    if not coalesce((kombax_marketplace.base_verification_r627(s.provider_id)->>'verified')::boolean,false) then raise exception 'KOMBAX_BASE_VERIFICATION_REQUIRED'; end if;
    if not kombax_marketplace.seller_policies_ready_r627(s.provider_id) then raise exception 'SELLER_POLICIES_REQUIRED'; end if;
    if not s.compliance_statement or not s.marketplace_statement then raise exception 'SELLER_DECLARATIONS_REQUIRED'; end if;
  end if;
  v_old:=s.status;
  update kombax_marketplace.seller_applications set status=p_status,review_note=left(nullif(btrim(p_note),''),2000),reviewed_by=v_uid,reviewed_at=now(),updated_at=now() where id=s.id returning * into s;
  insert into kombax_marketplace.seller_events(application_id,actor_user_id,event_type,from_status,to_status,detail,request_id) values(s.id,v_uid,'owner.seller.review',v_old,p_status,jsonb_build_object('note',left(coalesce(p_note,''),2000)),p_request_id);
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',to_jsonb(s),'selling_ready',kombax_marketplace.seller_ready_r627(s.provider_id));
end $$;

create or replace function public.app_kombax_marketplace_owner_buyer_detail_r627(p_identity_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());r kombax_marketplace.buyer_identity_requests;v_docs jsonb;v_events jsonb;
begin
  if v_uid is null or not kombax_marketplace.is_owner_r627(v_uid) then raise exception 'PLATFORM_OWNER_REQUIRED'; end if;
  select * into r from kombax_marketplace.buyer_identity_requests where id=p_identity_request_id;
  if r.id is null then raise exception 'BUYER_IDENTITY_REQUEST_NOT_FOUND'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'document_type',d.document_type,'storage_path',d.storage_path,'mime_type',d.mime_type,'bytes',d.bytes,'status',d.status,'created_at',d.created_at) order by d.created_at),'[]'::jsonb) into v_docs from kombax_marketplace.buyer_identity_documents d where d.request_id=r.id;
  select coalesce(jsonb_agg(jsonb_build_object('event_type',e.event_type,'from_status',e.from_status,'to_status',e.to_status,'detail',e.detail,'created_at',e.created_at) order by e.created_at),'[]'::jsonb) into v_events from kombax_marketplace.buyer_events e where e.request_id=r.id;
  return jsonb_build_object('ok',true,'request',to_jsonb(r),'documents',v_docs,'events',v_events);
end $$;

create or replace function public.app_kombax_marketplace_owner_buyer_review_r627(p_identity_request_id uuid,p_status text,p_note text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());r kombax_marketplace.buyer_identity_requests;v_old text;
begin
  if v_uid is null or p_request_id is null or not kombax_marketplace.is_owner_r627(v_uid) then raise exception 'PLATFORM_OWNER_REQUIRED'; end if;
  if p_status not in('under_review','needs_information','verified','rejected') then raise exception 'BUYER_REVIEW_STATUS_INVALID'; end if;
  select * into r from kombax_marketplace.buyer_identity_requests where id=p_identity_request_id for update;
  if r.id is null then raise exception 'BUYER_IDENTITY_REQUEST_NOT_FOUND'; end if;
  if exists(select 1 from kombax_marketplace.buyer_events e where e.request_token=p_request_id) then return jsonb_build_object('ok',true,'request_id',p_request_id,'data',to_jsonb(r),'reused',true); end if;
  if p_status='verified' and not exists(select 1 from kombax_marketplace.buyer_identity_documents d where d.request_id=r.id and d.status='active') then raise exception 'BUYER_IDENTITY_DOCUMENT_REQUIRED'; end if;
  v_old:=r.status;
  update kombax_marketplace.buyer_identity_requests set status=p_status,review_note=left(nullif(btrim(p_note),''),2000),reviewed_by=v_uid,reviewed_at=now(),updated_at=now() where id=r.id returning * into r;
  insert into kombax_marketplace.buyer_events(request_id,actor_user_id,event_type,from_status,to_status,detail,request_token) values(r.id,v_uid,'owner.buyer.review',v_old,p_status,jsonb_build_object('note',left(coalesce(p_note,''),2000)),p_request_id);
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',to_jsonb(r));
end $$;

create or replace function public.app_showcase_checkout_gate_r627(p_actor_id uuid,p_product_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare e public.kombax_showcase_elementos;v_missing int;
begin
  if p_actor_id is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into e from public.kombax_showcase_elementos where id=p_product_id;
  if e.id is null or e.estado<>'publicado' or not e.commerce_enabled then raise exception 'SHOWCASE_PRODUCT_NOT_FOR_SALE'; end if;
  if not kombax_marketplace.seller_ready_r627(e.marca_id) then raise exception 'SHOWCASE_SELLER_NOT_READY'; end if;
  select count(*) into v_missing from kombax_marketplace.policy_documents p where p.status='active' and p.required_for_buyer and not exists(select 1 from kombax_marketplace.policy_acceptances a where a.user_id=p_actor_id and a.provider_id is null and a.policy_code=p.policy_code and a.policy_version=p.version and a.acceptance_scope='buyer');
  if v_missing>0 then raise exception 'BUYER_MARKETPLACE_TERMS_REQUIRED'; end if;
  return jsonb_build_object('ok',true,'provider_id',e.marca_id,'seller_ready',true,'buyer_terms_ready',true);
end $$;

-- Strengthen commerce publication and public buy-state with the Seller Center gate.
create or replace function public.app_showcase_commerce_details_v259(p_ids uuid[])
returns table(id uuid,commerce_enabled boolean,precio_venta numeric,stock integer,variantes jsonb,fulfillment text,shipping_policy text,returns_policy text,seller_payments_active boolean)
language sql stable security definer set search_path='' as $$
  select e.id,e.commerce_enabled,e.precio_venta,e.stock,e.variantes,e.fulfillment,e.shipping_policy,e.returns_policy,
    kombax_marketplace.seller_ready_r627(e.marca_id)
  from public.kombax_showcase_elementos e where e.id=any(coalesce(p_ids,'{}'::uuid[]));
$$;

create or replace function public.app_showcase_commerce_mutate_v259(p_item_id uuid,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_item public.kombax_showcase_elementos;v_enabled boolean:=coalesce((p_payload->>'commerce_enabled')::boolean,false);v_price numeric;v_stock integer;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  select * into strict v_item from public.kombax_showcase_elementos where id=p_item_id for update;
  if not kombax_payments.can_manage_provider(v_uid,v_item.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  v_price:=nullif(p_payload->>'precio_venta','')::numeric;v_stock:=nullif(p_payload->>'stock','')::integer;
  if v_enabled and (v_price is null or v_price<=0) then raise exception 'COMMERCE_PRICE_REQUIRED'; end if;
  if v_enabled and not kombax_marketplace.seller_ready_r627(v_item.marca_id) then raise exception 'KOMBAX_SELLER_CENTER_REQUIRED'; end if;
  update public.kombax_showcase_elementos set commerce_enabled=v_enabled,precio_venta=v_price,stock=v_stock,
    variantes=coalesce(p_payload->'variantes','[]'::jsonb),fulfillment=coalesce(nullif(p_payload->>'fulfillment',''),'seller_shipping'),
    shipping_policy=nullif(btrim(p_payload->>'shipping_policy'),''),returns_policy=nullif(btrim(p_payload->>'returns_policy'),''),actualizado_por=v_uid,actualizado_en=now()
  where id=p_item_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',jsonb_build_object('id',p_item_id,'commerce_enabled',v_enabled));
end $$;

revoke all on function kombax_marketplace.is_owner_r627(uuid),kombax_marketplace.base_verification_r627(uuid),kombax_marketplace.seller_policies_ready_r627(uuid),kombax_marketplace.seller_ready_r627(uuid) from public,anon,authenticated;
grant execute on function kombax_marketplace.is_owner_r627(uuid),kombax_marketplace.base_verification_r627(uuid),kombax_marketplace.seller_policies_ready_r627(uuid),kombax_marketplace.seller_ready_r627(uuid) to service_role;

revoke all on function public.app_showcase_seller_center_r627(uuid),public.app_showcase_seller_application_mutate_r627(uuid,text,jsonb,uuid),public.app_showcase_seller_policy_accept_r627(uuid,text,text,uuid),public.app_kombax_buyer_trust_r627(),public.app_kombax_buyer_policy_accept_r627(text,text,uuid),public.app_kombax_buyer_identity_mutate_r627(text,jsonb,uuid),public.app_kombax_buyer_identity_document_r627(uuid,text,text,text,bigint,uuid),public.app_kombax_marketplace_owner_dashboard_r627(integer),public.app_kombax_marketplace_owner_seller_review_r627(uuid,text,text,uuid),public.app_kombax_marketplace_owner_buyer_detail_r627(uuid),public.app_kombax_marketplace_owner_buyer_review_r627(uuid,text,text,uuid) from public,anon;
grant execute on function public.app_showcase_seller_center_r627(uuid),public.app_showcase_seller_application_mutate_r627(uuid,text,jsonb,uuid),public.app_showcase_seller_policy_accept_r627(uuid,text,text,uuid),public.app_kombax_buyer_trust_r627(),public.app_kombax_buyer_policy_accept_r627(text,text,uuid),public.app_kombax_buyer_identity_mutate_r627(text,jsonb,uuid),public.app_kombax_buyer_identity_document_r627(uuid,text,text,text,bigint,uuid),public.app_kombax_marketplace_owner_dashboard_r627(integer),public.app_kombax_marketplace_owner_seller_review_r627(uuid,text,text,uuid),public.app_kombax_marketplace_owner_buyer_detail_r627(uuid),public.app_kombax_marketplace_owner_buyer_review_r627(uuid,text,text,uuid) to authenticated;

revoke all on function public.app_showcase_checkout_gate_r627(uuid,uuid) from public,anon,authenticated;
grant execute on function public.app_showcase_checkout_gate_r627(uuid,uuid) to service_role;

revoke all on function public.app_showcase_commerce_details_v259(uuid[]),public.app_showcase_commerce_mutate_v259(uuid,jsonb,uuid) from public,anon;
grant execute on function public.app_showcase_commerce_details_v259(uuid[]),public.app_showcase_commerce_mutate_v259(uuid,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
