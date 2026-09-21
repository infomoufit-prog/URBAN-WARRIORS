begin;

insert into public.kombax_capacidades(clave,descripcion,sensible) values
 ('professional.services.manage','Gestión de servicios profesionales propios',true),
 ('professional.schedule.manage','Gestión de agenda y disponibilidad profesional propia',true),
 ('professional.clients.manage','Gestión de clientes/deportistas profesionales propios',true),
 ('professional.sessions.manage','Gestión de sesiones profesionales propias',true),
 ('professional.training.notes.manage','Notas operativas de entrenamiento no clínicas',true),
 ('professional.represented.manage','Gestión limitada de representados con relación aceptada',true),
 ('professional.delegations.manage','Solicitudes y delegaciones profesionales consentidas',true),
 ('professional.opportunities.manage','Gestión de oportunidades profesionales',true),
 ('professional.credentials.medical','Acreditación de actividad médico-sanitaria deportiva; no concede acceso clínico',true),
 ('events.medical.assignments.read','Lectura de asignaciones médicas propias en Events',true),
 ('professional.credentials.official','Acreditación de árbitro o juez',true),
 ('events.official.assignments.read','Lectura de asignaciones oficiales propias en Events',true),
 ('events.official.results.submit','Envío limitado de resultados cuando exista asignación autorizada',true)
on conflict (clave) do update set descripcion=excluded.descripcion,sensible=excluded.sensible;

create table if not exists public.kombax_professional_specialty_capabilities_v198(
 specialty_code text not null references public.kombax_profesional_especialidades_v196(codigo) on delete cascade,
 capability_key text not null references public.kombax_capacidades(clave) on delete restrict,
 requires_verification boolean not null default false,
 primary key(specialty_code,capability_key)
);
alter table public.kombax_professional_specialty_capabilities_v198 enable row level security;
revoke all on public.kombax_professional_specialty_capabilities_v198 from public,anon,authenticated;
create policy kombax_prof_specialty_caps_read_v198 on public.kombax_professional_specialty_capabilities_v198 for select to authenticated using(true);
grant select on public.kombax_professional_specialty_capabilities_v198 to authenticated;

insert into public.kombax_professional_specialty_capabilities_v198(specialty_code,capability_key,requires_verification) values
 ('entrenador','professional.services.manage',false),
 ('entrenador','professional.schedule.manage',false),
 ('entrenador','professional.clients.manage',false),
 ('entrenador','professional.sessions.manage',false),
 ('entrenador','professional.training.notes.manage',false),
 ('representante_manager','professional.represented.manage',true),
 ('representante_manager','professional.delegations.manage',true),
 ('representante_manager','professional.opportunities.manage',true),
 ('medico_sanitario','professional.services.manage',true),
 ('medico_sanitario','professional.schedule.manage',true),
 ('medico_sanitario','professional.credentials.medical',true),
 ('medico_sanitario','events.medical.assignments.read',true),
 ('arbitro_juez','professional.schedule.manage',true),
 ('arbitro_juez','professional.credentials.official',true),
 ('arbitro_juez','events.official.assignments.read',true),
 ('arbitro_juez','events.official.results.submit',true),
 ('promotor_organizador','professional.services.manage',true),
 ('promotor_organizador','professional.schedule.manage',true),
 ('promotor_organizador','events.public.organize',true),
 ('promotor_organizador','events.public.partners.manage',true),
 ('promotor_organizador','events.public.fights.manage',true)
on conflict do nothing;

create table if not exists public.kombax_professional_clients_v198(
 id uuid primary key default gen_random_uuid(),
 professional_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
 nombre text not null check(char_length(btrim(nombre)) between 2 and 160),
 email text,
 telefono text,
 notas_operativas text not null default '' check(char_length(notas_operativas)<=3000),
 estado text not null default 'activo' check(estado in ('activo','pausado','archivado')),
 creado_por uuid not null references public.perfiles(id) on delete restrict,
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now()
);
create index if not exists idx_kombax_prof_clients_profile_v198 on public.kombax_professional_clients_v198(professional_profile_id,estado,actualizado_en desc);
alter table public.kombax_professional_clients_v198 enable row level security;
create policy kombax_prof_clients_select_v198 on public.kombax_professional_clients_v198 for select to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'read'));
create policy kombax_prof_clients_insert_v198 on public.kombax_professional_clients_v198 for insert to authenticated with check(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'admin') and creado_por=auth.uid());
create policy kombax_prof_clients_update_v198 on public.kombax_professional_clients_v198 for update to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'edit')) with check(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'edit'));
create policy kombax_prof_clients_delete_v198 on public.kombax_professional_clients_v198 for delete to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'admin'));
revoke all on public.kombax_professional_clients_v198 from public,anon,authenticated;

create table if not exists public.kombax_professional_sessions_v198(
 id uuid primary key default gen_random_uuid(),
 professional_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
 client_id uuid references public.kombax_professional_clients_v198(id) on delete set null,
 titulo text not null check(char_length(btrim(titulo)) between 2 and 180),
 starts_at timestamptz not null,
 ends_at timestamptz,
 estado text not null default 'programada' check(estado in ('programada','realizada','cancelada')),
 notas_operativas text not null default '' check(char_length(notas_operativas)<=3000),
 creado_por uuid not null references public.perfiles(id) on delete restrict,
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now(),
 constraint kombax_prof_sessions_dates_v198 check(ends_at is null or ends_at>starts_at)
);
create index if not exists idx_kombax_prof_sessions_profile_v198 on public.kombax_professional_sessions_v198(professional_profile_id,starts_at desc);
create index if not exists idx_kombax_prof_sessions_client_v198 on public.kombax_professional_sessions_v198(client_id) where client_id is not null;
alter table public.kombax_professional_sessions_v198 enable row level security;
create policy kombax_prof_sessions_select_v198 on public.kombax_professional_sessions_v198 for select to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'read'));
create policy kombax_prof_sessions_insert_v198 on public.kombax_professional_sessions_v198 for insert to authenticated with check(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'admin') and creado_por=auth.uid());
create policy kombax_prof_sessions_update_v198 on public.kombax_professional_sessions_v198 for update to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'edit')) with check(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'edit'));
create policy kombax_prof_sessions_delete_v198 on public.kombax_professional_sessions_v198 for delete to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'admin'));
revoke all on public.kombax_professional_sessions_v198 from public,anon,authenticated;

create table if not exists public.kombax_professional_credentials_v198(
 id uuid primary key default gen_random_uuid(),
 professional_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
 specialty_code text not null references public.kombax_profesional_especialidades_v196(codigo) on delete restrict,
 credential_type text not null check(char_length(btrim(credential_type)) between 2 and 120),
 issuer text not null default '' check(char_length(issuer)<=180),
 reference_public text not null default '' check(char_length(reference_public)<=220),
 estado text not null default 'declarada' check(estado in ('declarada','pendiente','verificada','rechazada','expirada')),
 expires_on date,
 creado_por uuid not null references public.perfiles(id) on delete restrict,
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now()
);
create index if not exists idx_kombax_prof_credentials_profile_v198 on public.kombax_professional_credentials_v198(professional_profile_id,specialty_code,estado);
alter table public.kombax_professional_credentials_v198 enable row level security;
create policy kombax_prof_credentials_select_v198 on public.kombax_professional_credentials_v198 for select to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'read'));
create policy kombax_prof_credentials_insert_v198 on public.kombax_professional_credentials_v198 for insert to authenticated with check(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'admin') and creado_por=auth.uid());
create policy kombax_prof_credentials_update_v198 on public.kombax_professional_credentials_v198 for update to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'edit')) with check(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'edit'));
revoke all on public.kombax_professional_credentials_v198 from public,anon,authenticated;

create table if not exists public.kombax_professional_availability_v198(
 id uuid primary key default gen_random_uuid(),
 professional_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 estado text not null default 'disponible' check(estado in ('disponible','reservado','no_disponible')),
 nota text not null default '' check(char_length(nota)<=500),
 creado_por uuid not null references public.perfiles(id) on delete restrict,
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now(),
 constraint kombax_prof_availability_dates_v198 check(ends_at>starts_at)
);
create index if not exists idx_kombax_prof_availability_profile_v198 on public.kombax_professional_availability_v198(professional_profile_id,starts_at);
alter table public.kombax_professional_availability_v198 enable row level security;
create policy kombax_prof_availability_select_v198 on public.kombax_professional_availability_v198 for select to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'read'));
create policy kombax_prof_availability_insert_v198 on public.kombax_professional_availability_v198 for insert to authenticated with check(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'admin') and creado_por=auth.uid());
create policy kombax_prof_availability_update_v198 on public.kombax_professional_availability_v198 for update to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'edit')) with check(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'edit'));
create policy kombax_prof_availability_delete_v198 on public.kombax_professional_availability_v198 for delete to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'admin'));
revoke all on public.kombax_professional_availability_v198 from public,anon,authenticated;

create table if not exists public.kombax_professional_delegations_v198(
 id uuid primary key default gen_random_uuid(),
 professional_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
 target_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
 relation_type text not null default 'manager_competitor' check(relation_type='manager_competitor'),
 status text not null default 'requested' check(status in ('requested','accepted','rejected','revoked','expired')),
 permissions text[] not null default '{}'::text[],
 requested_by uuid not null references public.perfiles(id) on delete restrict,
 accepted_by uuid references public.perfiles(id) on delete restrict,
 requested_at timestamptz not null default now(),
 accepted_at timestamptz,
 starts_at timestamptz,
 expires_at timestamptz,
 revoked_at timestamptz,
 updated_at timestamptz not null default now(),
 constraint kombax_prof_delegation_not_self_v198 check(professional_profile_id<>target_profile_id),
 constraint kombax_prof_delegation_dates_v198 check(expires_at is null or starts_at is null or expires_at>starts_at)
);
create unique index if not exists uq_kombax_prof_delegation_active_v198 on public.kombax_professional_delegations_v198(professional_profile_id,target_profile_id,relation_type) where status in ('requested','accepted');
create index if not exists idx_kombax_prof_delegation_target_v198 on public.kombax_professional_delegations_v198(target_profile_id,status,updated_at desc);
create index if not exists idx_kombax_prof_delegation_manager_v198 on public.kombax_professional_delegations_v198(professional_profile_id,status,updated_at desc);
alter table public.kombax_professional_delegations_v198 enable row level security;
create policy kombax_prof_delegations_select_v198 on public.kombax_professional_delegations_v198 for select to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'read') or public.app_kombax_puede_gestionar_perfil_v070(target_profile_id,'read'));
revoke all on public.kombax_professional_delegations_v198 from public,anon,authenticated;

create table if not exists public.kombax_professional_assignments_v198(
 id uuid primary key default gen_random_uuid(),
 professional_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
 event_id uuid not null references public.kombax_eventos_publicos(id) on delete cascade,
 assignment_type text not null check(assignment_type in ('medical','official')),
 status text not null default 'propuesta' check(status in ('propuesta','aceptada','rechazada','cancelada','completada')),
 permissions text[] not null default '{}'::text[],
 note text not null default '' check(char_length(note)<=1000),
 assigned_by uuid not null references public.perfiles(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(professional_profile_id,event_id,assignment_type)
);
create index if not exists idx_kombax_prof_assignments_profile_v198 on public.kombax_professional_assignments_v198(professional_profile_id,status,created_at desc);
create index if not exists idx_kombax_prof_assignments_event_v198 on public.kombax_professional_assignments_v198(event_id,assignment_type,status);
alter table public.kombax_professional_assignments_v198 enable row level security;
create policy kombax_prof_assignments_select_v198 on public.kombax_professional_assignments_v198 for select to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'read') or public.app_kombax_evento_puede_gestionar_v160(event_id));
revoke all on public.kombax_professional_assignments_v198 from public,anon,authenticated;

create table if not exists public.kombax_professional_audit_v198(
 id bigint generated always as identity primary key,
 professional_profile_id uuid references public.perfiles_kombax_directos(id) on delete set null,
 target_profile_id uuid references public.perfiles_kombax_directos(id) on delete set null,
 actor_profile_id uuid references public.perfiles(id) on delete set null,
 action text not null,
 entity_type text not null,
 entity_id uuid,
 detail jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index if not exists idx_kombax_prof_audit_subject_v198 on public.kombax_professional_audit_v198(professional_profile_id,created_at desc);
create index if not exists idx_kombax_prof_audit_target_v198 on public.kombax_professional_audit_v198(target_profile_id,created_at desc) where target_profile_id is not null;
alter table public.kombax_professional_audit_v198 enable row level security;
create policy kombax_prof_audit_select_v198 on public.kombax_professional_audit_v198 for select to authenticated using((professional_profile_id is not null and public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'read')) or (target_profile_id is not null and public.app_kombax_puede_gestionar_perfil_v070(target_profile_id,'read')) or public.app_kombax_es_platform_admin_v055());
revoke all on public.kombax_professional_audit_v198 from public,anon,authenticated;

create or replace function public.app_kombax_professional_has_specialty_v198(p_profile_id uuid,p_specialty text)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.perfiles_kombax_directos d where d.id=p_profile_id and d.tipo='profesional') and (
   exists(select 1 from public.kombax_profesional_perfiles_v196 p where p.perfil_directo_id=p_profile_id and p.especialidad_principal=p_specialty)
   or exists(select 1 from public.kombax_profesional_especialidades_secundarias_v196 s where s.perfil_directo_id=p_profile_id and s.especialidad_codigo=p_specialty)
 );
$$;
revoke all on function public.app_kombax_professional_has_specialty_v198(uuid,text) from public,anon;
grant execute on function public.app_kombax_professional_has_specialty_v198(uuid,text) to authenticated;

create or replace function public.app_kombax_profile_capabilities_v196(p_perfil_directo_id uuid)
returns table(capacidad_clave text,origen text,sensible boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_type text;v_verified boolean;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 select d.tipo,(d.estado='activo' and d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited')) into v_type,v_verified from public.perfiles_kombax_directos d where d.id=p_perfil_directo_id;
 if v_type is null then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;
 if not public.app_kombax_puede_gestionar_perfil_v070(p_perfil_directo_id,'read') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED';end if;
 return query
 with specialties as(
   select pp.especialidad_principal code from public.kombax_profesional_perfiles_v196 pp where pp.perfil_directo_id=p_perfil_directo_id
   union select ss.especialidad_codigo from public.kombax_profesional_especialidades_secundarias_v196 ss where ss.perfil_directo_id=p_perfil_directo_id
 ), effective as(
   select b.capacidad_clave,'base'::text origin from public.kombax_profile_base_capabilities_v196 b where b.perfil_tipo=v_type and (not b.requiere_verificacion or v_verified)
   union
   select sc.capability_key,'specialty:'||sc.specialty_code from public.kombax_professional_specialty_capabilities_v198 sc join specialties s on s.code=sc.specialty_code where not sc.requires_verification or v_verified
   union
   select e.capacidad_clave,coalesce(e.origen,'manual') from public.kombax_entitlements e where e.sujeto_tipo='perfil_directo' and e.sujeto_id=p_perfil_directo_id and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())
   union
   select 'profile.direct.manage','manager' where public.app_kombax_puede_gestionar_perfil_v070(p_perfil_directo_id,'edit')
 )
 select x.capacidad_clave,min(x.origin),coalesce(c.sensible,false) from effective x left join public.kombax_capacidades c on c.clave=x.capacidad_clave group by x.capacidad_clave,c.sensible order by x.capacidad_clave;
end $$;

create or replace function public.app_kombax_professional_workspace_v198(p_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_type text;v_caps text[]:='{}'::text[];v_result jsonb;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 if p_profile_id is null then raise exception 'KOMBAX_PROFILE_REQUIRED';end if;
 if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'read') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED';end if;
 select d.tipo into v_type from public.perfiles_kombax_directos d where d.id=p_profile_id;
 if v_type not in ('profesional','competidor') then raise exception 'KOMBAX_PROFESSIONAL_WORKSPACE_TYPE_INVALID';end if;
 if v_type='profesional' then select coalesce(array_agg(c.capacidad_clave),'{}'::text[]) into v_caps from public.app_kombax_profile_capabilities_v196(p_profile_id)c;end if;
 v_result:=jsonb_build_object('profile_id',p_profile_id,'type',v_type,'capabilities',to_jsonb(v_caps),'clinical_health_records_enabled',false,'version','r30-v198');
 if v_type='profesional' then
   v_result:=v_result||jsonb_build_object(
    'clients',case when 'professional.clients.manage'=any(v_caps) then coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'nombre',c.nombre,'email',c.email,'telefono',c.telefono,'notas_operativas',c.notas_operativas,'estado',c.estado,'actualizado_en',c.actualizado_en) order by c.actualizado_en desc) from public.kombax_professional_clients_v198 c where c.professional_profile_id=p_profile_id and c.estado<>'archivado'),'[]'::jsonb) else '[]'::jsonb end,
    'sessions',case when 'professional.sessions.manage'=any(v_caps) then coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'client_id',s.client_id,'titulo',s.titulo,'starts_at',s.starts_at,'ends_at',s.ends_at,'estado',s.estado,'notas_operativas',s.notas_operativas) order by s.starts_at desc) from public.kombax_professional_sessions_v198 s where s.professional_profile_id=p_profile_id and s.starts_at>now()-interval '180 days' limit 200),'[]'::jsonb) else '[]'::jsonb end,
    'credentials',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'specialty_code',c.specialty_code,'credential_type',c.credential_type,'issuer',c.issuer,'reference_public',c.reference_public,'estado',c.estado,'expires_on',c.expires_on) order by c.actualizado_en desc) from public.kombax_professional_credentials_v198 c where c.professional_profile_id=p_profile_id),'[]'::jsonb),
    'availability',case when 'professional.schedule.manage'=any(v_caps) then coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'starts_at',a.starts_at,'ends_at',a.ends_at,'estado',a.estado,'nota',a.nota) order by a.starts_at) from public.kombax_professional_availability_v198 a where a.professional_profile_id=p_profile_id and a.ends_at>now()-interval '1 day' limit 120),'[]'::jsonb) else '[]'::jsonb end,
    'delegations',case when 'professional.delegations.manage'=any(v_caps) then coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'target_profile_id',d.target_profile_id,'target_name',t.nombre_publico,'status',case when d.status='accepted' and d.expires_at is not null and d.expires_at<=now() then 'expired' else d.status end,'permissions',to_jsonb(d.permissions),'requested_at',d.requested_at,'accepted_at',d.accepted_at,'expires_at',d.expires_at) order by d.updated_at desc) from public.kombax_professional_delegations_v198 d join public.perfiles_kombax_directos t on t.id=d.target_profile_id where d.professional_profile_id=p_profile_id),'[]'::jsonb) else '[]'::jsonb end,
    'assignments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'event_id',a.event_id,'event_name',e.nombre,'assignment_type',a.assignment_type,'status',a.status,'permissions',to_jsonb(a.permissions),'note',a.note) order by e.fecha_inicio desc nulls last) from public.kombax_professional_assignments_v198 a join public.kombax_eventos_publicos e on e.id=a.event_id where a.professional_profile_id=p_profile_id),'[]'::jsonb)
   );
 else
   v_result:=v_result||jsonb_build_object('incoming_delegations',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'professional_profile_id',d.professional_profile_id,'manager_name',m.nombre_publico,'status',case when d.status='accepted' and d.expires_at is not null and d.expires_at<=now() then 'expired' else d.status end,'permissions',to_jsonb(d.permissions),'requested_at',d.requested_at,'accepted_at',d.accepted_at,'expires_at',d.expires_at) order by d.updated_at desc) from public.kombax_professional_delegations_v198 d join public.perfiles_kombax_directos m on m.id=d.professional_profile_id where d.target_profile_id=p_profile_id),'[]'::jsonb));
 end if;
 return v_result;
end $$;
revoke all on function public.app_kombax_professional_workspace_v198(uuid) from public,anon;
grant execute on function public.app_kombax_professional_workspace_v198(uuid) to authenticated;

create or replace function public.app_kombax_professional_mutate_v198(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_profile uuid;v_target uuid;v_id uuid;v_result jsonb;v_existing public.app_mutation_requests;v_perms text[]:='{}'::text[];v_perm text;v_status text;v_specialty text;v_event uuid;v_assignment text;v_start timestamptz;v_end timestamptz;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
 delete from public.app_mutation_requests where user_id=v_uid and club_id is null and created_at<now()-interval '30 days';
 select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
 if v_existing.request_id is not null then
   if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
   if v_existing.result is not null then return v_existing.result;end if;
 else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation);end if;

 v_profile=public.app_kombax_uuid_or_null_v070(v_payload->>'professional_profile_id');
 if p_operation in ('professional.client.save','professional.session.save','professional.credential.save','professional.availability.save','professional.delegation.request') then
   if v_profile is null or not public.app_kombax_puede_gestionar_perfil_v070(v_profile,'edit') then raise exception 'KOMBAX_PROFESSIONAL_PROFILE_NOT_MANAGED';end if;
   if not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_profile and d.tipo='profesional') then raise exception 'KOMBAX_PROFESSIONAL_PROFILE_REQUIRED';end if;
 end if;

 if p_operation='professional.client.save' then
   if not exists(select 1 from public.app_kombax_profile_capabilities_v196(v_profile)c where c.capacidad_clave='professional.clients.manage') then raise exception 'KOMBAX_CAPABILITY_REQUIRED:professional.clients.manage';end if;
   v_id=public.app_kombax_uuid_or_null_v070(v_payload->>'id');
   if v_id is null then insert into public.kombax_professional_clients_v198(professional_profile_id,nombre,email,telefono,notas_operativas,estado,creado_por) values(v_profile,btrim(v_payload->>'nombre'),nullif(btrim(v_payload->>'email'),''),nullif(btrim(v_payload->>'telefono'),''),left(coalesce(v_payload->>'notas_operativas',''),3000),coalesce(nullif(v_payload->>'estado',''),'activo'),v_uid) returning id into v_id;
   else update public.kombax_professional_clients_v198 set nombre=btrim(v_payload->>'nombre'),email=nullif(btrim(v_payload->>'email'),''),telefono=nullif(btrim(v_payload->>'telefono'),''),notas_operativas=left(coalesce(v_payload->>'notas_operativas',''),3000),estado=coalesce(nullif(v_payload->>'estado',''),'activo'),actualizado_en=now() where id=v_id and professional_profile_id=v_profile; if not found then raise exception 'KOMBAX_CLIENT_NOT_FOUND';end if; end if;
   v_result=jsonb_build_object('id',v_id);
   insert into public.kombax_professional_audit_v198(professional_profile_id,actor_profile_id,action,entity_type,entity_id) values(v_profile,v_uid,'client.save','client',v_id);

 elsif p_operation='professional.session.save' then
   if not exists(select 1 from public.app_kombax_profile_capabilities_v196(v_profile)c where c.capacidad_clave='professional.sessions.manage') then raise exception 'KOMBAX_CAPABILITY_REQUIRED:professional.sessions.manage';end if;
   v_id=public.app_kombax_uuid_or_null_v070(v_payload->>'id');v_target=public.app_kombax_uuid_or_null_v070(v_payload->>'client_id');v_start=nullif(v_payload->>'starts_at','')::timestamptz;v_end=nullif(v_payload->>'ends_at','')::timestamptz;
   if v_target is not null and not exists(select 1 from public.kombax_professional_clients_v198 c where c.id=v_target and c.professional_profile_id=v_profile) then raise exception 'KOMBAX_CLIENT_SCOPE_INVALID';end if;
   if v_id is null then insert into public.kombax_professional_sessions_v198(professional_profile_id,client_id,titulo,starts_at,ends_at,estado,notas_operativas,creado_por) values(v_profile,v_target,btrim(v_payload->>'titulo'),v_start,v_end,coalesce(nullif(v_payload->>'estado',''),'programada'),left(coalesce(v_payload->>'notas_operativas',''),3000),v_uid) returning id into v_id;
   else update public.kombax_professional_sessions_v198 set client_id=v_target,titulo=btrim(v_payload->>'titulo'),starts_at=v_start,ends_at=v_end,estado=coalesce(nullif(v_payload->>'estado',''),'programada'),notas_operativas=left(coalesce(v_payload->>'notas_operativas',''),3000),actualizado_en=now() where id=v_id and professional_profile_id=v_profile; if not found then raise exception 'KOMBAX_SESSION_NOT_FOUND';end if;end if;
   v_result=jsonb_build_object('id',v_id);
   insert into public.kombax_professional_audit_v198(professional_profile_id,actor_profile_id,action,entity_type,entity_id) values(v_profile,v_uid,'session.save','session',v_id);

 elsif p_operation='professional.credential.save' then
   v_specialty=lower(btrim(v_payload->>'specialty_code'));
   if not public.app_kombax_professional_has_specialty_v198(v_profile,v_specialty) then raise exception 'KOMBAX_PROFESSIONAL_SPECIALTY_NOT_OWNED';end if;
   v_id=public.app_kombax_uuid_or_null_v070(v_payload->>'id');
   if v_id is null then insert into public.kombax_professional_credentials_v198(professional_profile_id,specialty_code,credential_type,issuer,reference_public,expires_on,creado_por) values(v_profile,v_specialty,btrim(v_payload->>'credential_type'),left(coalesce(v_payload->>'issuer',''),180),left(coalesce(v_payload->>'reference_public',''),220),nullif(v_payload->>'expires_on','')::date,v_uid) returning id into v_id;
   else update public.kombax_professional_credentials_v198 set credential_type=btrim(v_payload->>'credential_type'),issuer=left(coalesce(v_payload->>'issuer',''),180),reference_public=left(coalesce(v_payload->>'reference_public',''),220),expires_on=nullif(v_payload->>'expires_on','')::date,actualizado_en=now() where id=v_id and professional_profile_id=v_profile and specialty_code=v_specialty; if not found then raise exception 'KOMBAX_CREDENTIAL_NOT_FOUND';end if;end if;
   v_result=jsonb_build_object('id',v_id);
   insert into public.kombax_professional_audit_v198(professional_profile_id,actor_profile_id,action,entity_type,entity_id,detail) values(v_profile,v_uid,'credential.save','credential',v_id,jsonb_build_object('specialty',v_specialty));

 elsif p_operation='professional.availability.save' then
   if not exists(select 1 from public.app_kombax_profile_capabilities_v196(v_profile)c where c.capacidad_clave='professional.schedule.manage') then raise exception 'KOMBAX_CAPABILITY_REQUIRED:professional.schedule.manage';end if;
   v_start=nullif(v_payload->>'starts_at','')::timestamptz;v_end=nullif(v_payload->>'ends_at','')::timestamptz;v_id=public.app_kombax_uuid_or_null_v070(v_payload->>'id');
   if v_id is null then insert into public.kombax_professional_availability_v198(professional_profile_id,starts_at,ends_at,estado,nota,creado_por) values(v_profile,v_start,v_end,coalesce(nullif(v_payload->>'estado',''),'disponible'),left(coalesce(v_payload->>'nota',''),500),v_uid) returning id into v_id;
   else update public.kombax_professional_availability_v198 set starts_at=v_start,ends_at=v_end,estado=coalesce(nullif(v_payload->>'estado',''),'disponible'),nota=left(coalesce(v_payload->>'nota',''),500),actualizado_en=now() where id=v_id and professional_profile_id=v_profile; if not found then raise exception 'KOMBAX_AVAILABILITY_NOT_FOUND';end if;end if;
   v_result=jsonb_build_object('id',v_id);
   insert into public.kombax_professional_audit_v198(professional_profile_id,actor_profile_id,action,entity_type,entity_id) values(v_profile,v_uid,'availability.save','availability',v_id);

 elsif p_operation='professional.delegation.request' then
   if not exists(select 1 from public.app_kombax_profile_capabilities_v196(v_profile)c where c.capacidad_clave='professional.delegations.manage') then raise exception 'KOMBAX_CAPABILITY_REQUIRED:professional.delegations.manage';end if;
   v_target=public.app_kombax_uuid_or_null_v070(v_payload->>'target_profile_id');
   if v_target is null or not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_target and d.tipo='competidor') then raise exception 'KOMBAX_COMPETITOR_TARGET_REQUIRED';end if;
   if jsonb_typeof(coalesce(v_payload->'permissions','[]'::jsonb))<>'array' then raise exception 'KOMBAX_DELEGATION_PERMISSIONS_INVALID';end if;
   for v_perm in select distinct value from jsonb_array_elements_text(coalesce(v_payload->'permissions','[]'::jsonb)) loop
     if v_perm not in ('calendar.read','opportunities.manage','events.requests.manage','professional_fields.edit','representation.documents.manage') then raise exception 'KOMBAX_DELEGATION_PERMISSION_NOT_ALLOWED:%',v_perm;end if;
     v_perms=array_append(v_perms,v_perm);
   end loop;
   if cardinality(v_perms)=0 then v_perms=array['calendar.read','opportunities.manage'];end if;
   insert into public.kombax_professional_delegations_v198(professional_profile_id,target_profile_id,permissions,requested_by,starts_at,expires_at) values(v_profile,v_target,v_perms,v_uid,nullif(v_payload->>'starts_at','')::timestamptz,nullif(v_payload->>'expires_at','')::timestamptz) returning id into v_id;
   v_result=jsonb_build_object('id',v_id,'status','requested');
   insert into public.kombax_professional_audit_v198(professional_profile_id,target_profile_id,actor_profile_id,action,entity_type,entity_id,detail) values(v_profile,v_target,v_uid,'delegation.request','delegation',v_id,jsonb_build_object('permissions',to_jsonb(v_perms)));

 elsif p_operation='professional.delegation.respond' then
   v_id=public.app_kombax_uuid_or_null_v070(v_payload->>'delegation_id');v_status=lower(btrim(v_payload->>'status'));
   if v_status not in ('accepted','rejected') then raise exception 'KOMBAX_DELEGATION_RESPONSE_INVALID';end if;
   select d.professional_profile_id,d.target_profile_id into v_profile,v_target from public.kombax_professional_delegations_v198 d where d.id=v_id and d.status='requested' for update;
   if v_profile is null then raise exception 'KOMBAX_DELEGATION_NOT_REQUESTED';end if;
   if not exists(select 1 from public.perfiles_kombax_directos t where t.id=v_target and t.perfil_id=v_uid) and not public.app_kombax_es_platform_admin_v055() then raise exception 'KOMBAX_DELEGATION_TARGET_OWNER_REQUIRED';end if;
   update public.kombax_professional_delegations_v198 set status=v_status,accepted_by=case when v_status='accepted' then v_uid else null end,accepted_at=case when v_status='accepted' then now() else null end,starts_at=case when v_status='accepted' then coalesce(starts_at,now()) else starts_at end,updated_at=now() where id=v_id;
   v_result=jsonb_build_object('id',v_id,'status',v_status);
   insert into public.kombax_professional_audit_v198(professional_profile_id,target_profile_id,actor_profile_id,action,entity_type,entity_id) values(v_profile,v_target,v_uid,'delegation.'||v_status,'delegation',v_id);

 elsif p_operation='professional.delegation.revoke' then
   v_id=public.app_kombax_uuid_or_null_v070(v_payload->>'delegation_id');
   select d.professional_profile_id,d.target_profile_id into v_profile,v_target from public.kombax_professional_delegations_v198 d where d.id=v_id and d.status in ('requested','accepted') for update;
   if v_profile is null then raise exception 'KOMBAX_DELEGATION_NOT_ACTIVE';end if;
   if not public.app_kombax_puede_gestionar_perfil_v070(v_profile,'admin') and not exists(select 1 from public.perfiles_kombax_directos t where t.id=v_target and t.perfil_id=v_uid) and not public.app_kombax_es_platform_admin_v055() then raise exception 'KOMBAX_DELEGATION_REVOKE_NOT_ALLOWED';end if;
   update public.kombax_professional_delegations_v198 set status='revoked',revoked_at=now(),updated_at=now() where id=v_id;
   v_result=jsonb_build_object('id',v_id,'status','revoked');
   insert into public.kombax_professional_audit_v198(professional_profile_id,target_profile_id,actor_profile_id,action,entity_type,entity_id) values(v_profile,v_target,v_uid,'delegation.revoked','delegation',v_id);

 elsif p_operation='professional.assignment.save' then
   v_profile=public.app_kombax_uuid_or_null_v070(v_payload->>'professional_profile_id');v_event=public.app_kombax_uuid_or_null_v070(v_payload->>'event_id');v_assignment=lower(btrim(v_payload->>'assignment_type'));
   if v_profile is null or v_event is null or v_assignment not in ('medical','official') then raise exception 'KOMBAX_ASSIGNMENT_INVALID';end if;
   if not public.app_kombax_evento_puede_gestionar_v160(v_event) and not public.app_kombax_es_platform_admin_v055() then raise exception 'KOMBAX_EVENT_MANAGE_REQUIRED';end if;
   if v_assignment='medical' and not public.app_kombax_professional_has_specialty_v198(v_profile,'medico_sanitario') then raise exception 'KOMBAX_MEDICAL_SPECIALTY_REQUIRED';end if;
   if v_assignment='official' and not public.app_kombax_professional_has_specialty_v198(v_profile,'arbitro_juez') then raise exception 'KOMBAX_OFFICIAL_SPECIALTY_REQUIRED';end if;
   v_perms=case v_assignment when 'medical' then array['assignment.read']::text[] else array['assignment.read','result.submit']::text[] end;
   insert into public.kombax_professional_assignments_v198(professional_profile_id,event_id,assignment_type,status,permissions,note,assigned_by) values(v_profile,v_event,v_assignment,'propuesta',v_perms,left(coalesce(v_payload->>'note',''),1000),v_uid)
   on conflict(professional_profile_id,event_id,assignment_type) do update set status='propuesta',permissions=excluded.permissions,note=excluded.note,assigned_by=excluded.assigned_by,updated_at=now() returning id into v_id;
   v_result=jsonb_build_object('id',v_id,'status','propuesta');
   insert into public.kombax_professional_audit_v198(professional_profile_id,actor_profile_id,action,entity_type,entity_id,detail) values(v_profile,v_uid,'assignment.save','assignment',v_id,jsonb_build_object('event_id',v_event,'assignment_type',v_assignment));

 elsif p_operation='professional.assignment.respond' then
   v_id=public.app_kombax_uuid_or_null_v070(v_payload->>'assignment_id');v_status=lower(btrim(v_payload->>'status'));
   if v_status not in ('aceptada','rechazada') then raise exception 'KOMBAX_ASSIGNMENT_RESPONSE_INVALID';end if;
   select a.professional_profile_id,a.event_id into v_profile,v_event from public.kombax_professional_assignments_v198 a where a.id=v_id and a.status='propuesta' for update;
   if v_profile is null or not public.app_kombax_puede_gestionar_perfil_v070(v_profile,'admin') then raise exception 'KOMBAX_ASSIGNMENT_PROFILE_REQUIRED';end if;
   update public.kombax_professional_assignments_v198 set status=v_status,updated_at=now() where id=v_id;
   v_result=jsonb_build_object('id',v_id,'status',v_status);
   insert into public.kombax_professional_audit_v198(professional_profile_id,actor_profile_id,action,entity_type,entity_id,detail) values(v_profile,v_uid,'assignment.'||v_status,'assignment',v_id,jsonb_build_object('event_id',v_event));
 else
   raise exception 'KOMBAX_PROFESSIONAL_OPERATION_NOT_ALLOWED';
 end if;
 v_result=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
 update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
 return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_professional_mutate_v198(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_professional_mutate_v198(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
