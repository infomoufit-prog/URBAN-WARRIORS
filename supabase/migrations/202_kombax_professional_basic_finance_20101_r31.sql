begin;

insert into public.kombax_capacidades(clave,descripcion,sensible) values
 ('professional.finance.manage','Gestión administrativa de finanzas profesionales propias',true),
 ('professional.finance.reports','Lectura de informes y KPIs financieros profesionales propios',true)
on conflict (clave) do update set descripcion=excluded.descripcion,sensible=excluded.sensible;

insert into public.kombax_profile_base_capabilities_v196(perfil_tipo,capacidad_clave,requiere_verificacion) values
 ('profesional','professional.finance.manage',true),
 ('profesional','professional.finance.reports',true)
on conflict (perfil_tipo,capacidad_clave) do update set requiere_verificacion=excluded.requiere_verificacion;

create table if not exists public.kombax_professional_services_v199(
 id uuid primary key default gen_random_uuid(),
 professional_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
 nombre text not null check(char_length(btrim(nombre)) between 2 and 160),
 descripcion text not null default '' check(char_length(descripcion)<=2000),
 tarifa_referencia numeric(12,2) not null default 0 check(tarifa_referencia>=0),
 moneda text not null default 'EUR' check(moneda ~ '^[A-Z]{3}$'),
 estado text not null default 'activo' check(estado in ('activo','archivado')),
 creado_por uuid not null references public.perfiles(id) on delete restrict,
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now()
);
create index if not exists idx_kombax_prof_services_subject_v199 on public.kombax_professional_services_v199(professional_profile_id,estado,actualizado_en desc);
alter table public.kombax_professional_services_v199 enable row level security;
revoke all on public.kombax_professional_services_v199 from public,anon,authenticated;
create policy kombax_prof_services_read_v199 on public.kombax_professional_services_v199 for select to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'read'));

create table if not exists public.kombax_professional_charges_v199(
 id uuid primary key default gen_random_uuid(),
 professional_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
 client_id uuid references public.kombax_professional_clients_v198(id) on delete set null,
 service_id uuid references public.kombax_professional_services_v199(id) on delete set null,
 represented_profile_id uuid references public.perfiles_kombax_directos(id) on delete set null,
 assignment_id uuid references public.kombax_professional_assignments_v198(id) on delete set null,
 concepto text not null check(char_length(btrim(concepto)) between 2 and 220),
 importe numeric(12,2) not null check(importe>0),
 moneda text not null default 'EUR' check(moneda ~ '^[A-Z]{3}$'),
 vence_el date,
 estado text not null default 'pendiente' check(estado in ('pendiente','parcial','pagado','anulado')),
 notas text not null default '' check(char_length(notas)<=2000),
 creado_por uuid not null references public.perfiles(id) on delete restrict,
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now()
);
create index if not exists idx_kombax_prof_charges_subject_due_v199 on public.kombax_professional_charges_v199(professional_profile_id,estado,vence_el,creado_en desc);
create index if not exists idx_kombax_prof_charges_client_v199 on public.kombax_professional_charges_v199(client_id) where client_id is not null;
create index if not exists idx_kombax_prof_charges_represented_v199 on public.kombax_professional_charges_v199(represented_profile_id) where represented_profile_id is not null;
create index if not exists idx_kombax_prof_charges_assignment_v199 on public.kombax_professional_charges_v199(assignment_id) where assignment_id is not null;
alter table public.kombax_professional_charges_v199 enable row level security;
revoke all on public.kombax_professional_charges_v199 from public,anon,authenticated;
create policy kombax_prof_charges_read_v199 on public.kombax_professional_charges_v199 for select to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'read'));

create table if not exists public.kombax_professional_payments_v199(
 id uuid primary key default gen_random_uuid(),
 professional_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
 charge_id uuid not null references public.kombax_professional_charges_v199(id) on delete restrict,
 importe numeric(12,2) not null check(importe>0),
 registrado_el date not null default current_date,
 metodo text not null default 'otro' check(metodo in ('transferencia','bizum','efectivo','tarjeta','otro')),
 referencia text not null default '' check(char_length(referencia)<=240),
 notas text not null default '' check(char_length(notas)<=1200),
 creado_por uuid not null references public.perfiles(id) on delete restrict,
 creado_en timestamptz not null default now()
);
create index if not exists idx_kombax_prof_payments_subject_date_v199 on public.kombax_professional_payments_v199(professional_profile_id,registrado_el desc,creado_en desc);
create index if not exists idx_kombax_prof_payments_charge_v199 on public.kombax_professional_payments_v199(charge_id,creado_en);
alter table public.kombax_professional_payments_v199 enable row level security;
revoke all on public.kombax_professional_payments_v199 from public,anon,authenticated;
create policy kombax_prof_payments_read_v199 on public.kombax_professional_payments_v199 for select to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'read'));

create table if not exists public.kombax_professional_expenses_v199(
 id uuid primary key default gen_random_uuid(),
 professional_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
 concepto text not null check(char_length(btrim(concepto)) between 2 and 220),
 importe numeric(12,2) not null check(importe>0),
 moneda text not null default 'EUR' check(moneda ~ '^[A-Z]{3}$'),
 ocurrido_el date not null default current_date,
 categoria text not null default 'otro' check(char_length(categoria)<=80),
 notas text not null default '' check(char_length(notas)<=1600),
 creado_por uuid not null references public.perfiles(id) on delete restrict,
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now()
);
create index if not exists idx_kombax_prof_expenses_subject_date_v199 on public.kombax_professional_expenses_v199(professional_profile_id,ocurrido_el desc,creado_en desc);
alter table public.kombax_professional_expenses_v199 enable row level security;
revoke all on public.kombax_professional_expenses_v199 from public,anon,authenticated;
create policy kombax_prof_expenses_read_v199 on public.kombax_professional_expenses_v199 for select to authenticated using(public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'read'));

create table if not exists public.kombax_professional_finance_audit_v199(
 id bigint generated always as identity primary key,
 professional_profile_id uuid references public.perfiles_kombax_directos(id) on delete set null,
 actor_profile_id uuid references public.perfiles(id) on delete set null,
 action text not null,
 entity_type text not null,
 entity_id uuid,
 detail jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index if not exists idx_kombax_prof_fin_audit_subject_v199 on public.kombax_professional_finance_audit_v199(professional_profile_id,created_at desc);
alter table public.kombax_professional_finance_audit_v199 enable row level security;
revoke all on public.kombax_professional_finance_audit_v199 from public,anon,authenticated;
create policy kombax_prof_fin_audit_read_v199 on public.kombax_professional_finance_audit_v199 for select to authenticated using((professional_profile_id is not null and public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'read')) or public.app_kombax_es_platform_admin_v055());

notify pgrst,'reload schema';
commit;
