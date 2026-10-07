-- Five forthcoming competitor accounts: explicit Owner pilot approval, no document review.
create schema if not exists kombax_pilot;
revoke all on schema kombax_pilot from public,anon,authenticated;
create table kombax_pilot.competitor_cohorts(
 id text primary key, capacity integer not null check(capacity=5),
 used integer not null default 0 check(used between 0 and capacity),
 enabled boolean not null default true, created_at timestamptz not null default now()
);
create table kombax_pilot.competitor_grants(
 profile_id uuid primary key references public.perfiles_kombax_directos(id) on delete cascade deferrable initially deferred,
 account_id uuid not null unique references auth.users(id),
 cohort_id text not null references kombax_pilot.competitor_cohorts(id),
 ordinal integer not null check(ordinal between 1 and 5),
 basis text not null default 'owner_pilot_authorization_without_document_review',
 granted_at timestamptz not null default now(),
 unique(cohort_id,ordinal)
);
alter table kombax_pilot.competitor_cohorts enable row level security;
alter table kombax_pilot.competitor_grants enable row level security;
revoke all on all tables in schema kombax_pilot from public,anon,authenticated;
insert into kombax_pilot.competitor_cohorts(id,capacity) values('competitor-pilot-five-fix18',5);

create function kombax_pilot.authorize_next_competitor_fix18() returns trigger
language plpgsql security definer set search_path='' as $fn$
declare v_dob date; v_used integer;
begin
 if new.tipo<>'competidor' then return new;end if;
 -- Preserve age controls; never infer or invent a birth date.
 select a.fecha_nacimiento into v_dob from public.kombax_account_private_r117 a where a.perfil_id=new.perfil_id;
 if v_dob is null or v_dob>current_date-interval '16 years' then return new;end if;
 if exists(select 1 from kombax_pilot.competitor_grants g where g.account_id=new.perfil_id) then return new;end if;
 select c.used into v_used from kombax_pilot.competitor_cohorts c
 where c.id='competitor-pilot-five-fix18' and c.enabled and c.used<c.capacity for update;
 if not found then return new;end if;
 insert into kombax_pilot.competitor_grants(profile_id,account_id,cohort_id,ordinal)
 values(new.id,new.perfil_id,'competitor-pilot-five-fix18',v_used+1);
 update kombax_pilot.competitor_cohorts set used=v_used+1,enabled=(v_used+1<capacity)
 where id='competitor-pilot-five-fix18';
 new.estado:='activo';new.workflow_estado:='verified';new.verificacion_estado:='verificado';
 new.verificacion_version:='pilot-owner-authorized-fix18';
 new.verificado_en:=now();new.verificado_por:=null;
 new.publico:=true;new.fecha_nacimiento_verificada:=v_dob;
 -- Social publication still requires the user's existing acceptance flow.
 return new;
end $fn$;
revoke all on function kombax_pilot.authorize_next_competitor_fix18() from public,anon,authenticated;
create trigger b_competitor_pilot_five_fix18 before insert on public.perfiles_kombax_directos
for each row execute function kombax_pilot.authorize_next_competitor_fix18();

-- Public Social access is free. Publication, messaging actors and commerce keep their own gates.
create or replace function public.app_kombax_social_acceso_v041() returns boolean
language sql stable security definer set search_path='public','auth' as $fn$
select auth.uid() is not null and (
 public.app_kombax_es_moderador_v041()
 or exists(select 1 from public.miembros_club m join public.kombax_entitlements e
  on e.sujeto_tipo='club' and e.sujeto_id=m.club_id and e.capacidad_clave='social.read'
  and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())
  where m.perfil_id=auth.uid() and m.activo)
 or exists(select 1 from public.perfiles_kombax_directos d join public.kombax_entitlements e
  on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='social.read'
  and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())
  where d.perfil_id=auth.uid() and d.estado='activo')
 or exists(select 1 from public.kombax_social_perfiles sp
  left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  left join public.identidades_sociales i on i.id=sp.identidad_social_id
  where sp.visible and sp.estado='activo' and (
   (sp.sujeto_tipo='miembro' and i.perfil_id=auth.uid() and i.estado='activa')
   or (sp.sujeto_tipo='perfil_directo' and d.estado not in ('suspendido','cerrado')
    and d.moderacion_estado='normal' and (
     d.perfil_id=auth.uid() or exists(select 1 from public.kombax_perfil_gestores g
      where g.perfil_directo_id=d.id and g.perfil_id=auth.uid() and g.estado='activo')
    ))
  ))
);
$fn$;
