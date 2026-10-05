-- R120: general professional verification enables ordinary activity.
-- Additional accreditation is required only for explicitly restricted services.
-- Preparation and financial history remain available under their existing policies.
begin;

insert into public.kombax_profesional_especialidades_v196(codigo,nombre,descripcion,orden,activa)
values
 ('psicologo_deportivo','Psicólogo deportivo','Actividad profesional sujeta a verificación general; acreditación adicional según servicio.',60,true),
 ('psicoterapeuta','Psicoterapeuta','Actividad profesional sujeta a verificación general; acreditación adicional según servicio.',70,true)
on conflict(codigo) do nothing;

insert into public.kombax_professional_specialty_capabilities_v198(specialty_code,capability_key,requires_verification)
select s,k,true from unnest(array['psicologo_deportivo','psicoterapeuta']) s
cross join unnest(array['professional.services.manage','professional.schedule.manage']) k
on conflict do nothing;

-- No blanket second verification. Only the existing medical/official operations
-- are restricted here; further service requirements need an explicit catalog rule.
create table public.kombax_specialty_service_requirements_r120(
 specialty_code text not null references public.kombax_profesional_especialidades_v196(codigo),
 capability_key text not null references public.kombax_capacidades(clave),
 primary key(specialty_code,capability_key)
);
alter table public.kombax_specialty_service_requirements_r120 enable row level security;
revoke all on public.kombax_specialty_service_requirements_r120 from public,anon,authenticated;
insert into public.kombax_specialty_service_requirements_r120 values
 ('medico_sanitario','professional.credentials.medical'),
 ('medico_sanitario','events.medical.assignments.read'),
 ('arbitro_juez','professional.credentials.official'),
 ('arbitro_juez','events.official.assignments.read'),
 ('arbitro_juez','events.official.results.submit');

create or replace function public.app_kombax_specialty_accredited_r120(p_profile_id uuid,p_specialty text)
returns boolean language sql stable security definer set search_path=public,auth
as $$
 select auth.uid() is not null
 and public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'read')
 and public.app_kombax_professional_has_specialty_v198(p_profile_id,p_specialty)
 and exists(select 1 from public.perfiles_kombax_directos d
   where d.id=p_profile_id and d.tipo='profesional' and d.estado='activo'
     and d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited'))
 and exists(select 1 from public.kombax_professional_credentials_v198 c
   where c.professional_profile_id=p_profile_id and c.specialty_code=p_specialty
     and c.estado='verificada' and c.verified_at is not null and c.verified_by is not null
     and (c.expires_on is null or c.expires_on>=current_date)
     and exists(select 1 from public.kombax_professional_credential_acceptances_r118 a
       where a.credential_id=c.id and a.professional_profile_id=p_profile_id)
     and exists(select 1 from public.kombax_professional_credential_evidence_r118 e
       join storage.objects o on o.bucket_id='kombax-verification-docs' and o.name=e.storage_path
       where e.credential_id=c.id and e.professional_profile_id=p_profile_id and e.estado='active'));
$$;
revoke all on function public.app_kombax_specialty_accredited_r120(uuid,text) from public,anon;
grant execute on function public.app_kombax_specialty_accredited_r120(uuid,text) to authenticated;

-- Editing a reviewed document through either the current or legacy API invalidates
-- approval; changing visibility alone does not. This prevents extending a reviewed
-- expiry date or replacing its reference without a new review.
create or replace function public.app_kombax_credential_change_reset_r120()
returns trigger language plpgsql set search_path=public as $$
begin
 if row(new.professional_profile_id,new.specialty_code,new.credential_type,new.issuer,
        new.reference_public,new.verification_url,new.expires_on)
    is distinct from
    row(old.professional_profile_id,old.specialty_code,old.credential_type,old.issuer,
        old.reference_public,old.verification_url,old.expires_on) then
   new.estado:='declarada'; new.public_visible:=false;
   new.verified_by:=null; new.verified_at:=null; new.review_note:=null;
 end if;
 return new;
end $$;
revoke all on function public.app_kombax_credential_change_reset_r120() from public,anon,authenticated;
create trigger kombax_credential_change_reset_r120 before update
on public.kombax_professional_credentials_v198 for each row
execute function public.app_kombax_credential_change_reset_r120();

create or replace function public.app_kombax_profile_capabilities_v196(p_perfil_directo_id uuid)
returns table(capacidad_clave text,origen text,sensible boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_type text; v_verified boolean;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 select d.tipo,(d.estado='activo' and d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited'))
 into v_type,v_verified from public.perfiles_kombax_directos d where d.id=p_perfil_directo_id;
 if v_type is null then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;
 if not public.app_kombax_puede_gestionar_perfil_v070(p_perfil_directo_id,'read') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED';end if;
 return query
 with specialties as (
   select p.especialidad_principal code from public.kombax_profesional_perfiles_v196 p where p.perfil_directo_id=p_perfil_directo_id
   union select s.especialidad_codigo from public.kombax_profesional_especialidades_secundarias_v196 s where s.perfil_directo_id=p_perfil_directo_id
 ), approved as (
   select s.code from specialties s where public.app_kombax_specialty_accredited_r120(p_perfil_directo_id,s.code)
 ), effective as (
   select b.capacidad_clave,'base'::text origin from public.kombax_profile_base_capabilities_v196 b
   where b.perfil_tipo=v_type and (not b.requiere_verificacion or v_verified)
   union
   select sc.capability_key,'specialty:'||sc.specialty_code
   from public.kombax_professional_specialty_capabilities_v198 sc join specialties s on s.code=sc.specialty_code
   where v_verified and (not exists(select 1 from public.kombax_specialty_service_requirements_r120 r
     where r.specialty_code=sc.specialty_code and r.capability_key=sc.capability_key)
     or exists(select 1 from approved a where a.code=sc.specialty_code))
   union
   select e.capacidad_clave,coalesce(e.origen,'manual') from public.kombax_entitlements e
   where e.sujeto_tipo='perfil_directo' and e.sujeto_id=p_perfil_directo_id and e.activa
     and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())
   union select 'profile.direct.manage','manager'
     where public.app_kombax_puede_gestionar_perfil_v070(p_perfil_directo_id,'edit')
 ), scoped as (
   select x.* from effective x where v_type<>'profesional'
   or not exists(select 1 from public.kombax_professional_specialty_capabilities_v198 sc where sc.capability_key=x.capacidad_clave)
   or (v_verified and exists(select 1 from public.kombax_professional_specialty_capabilities_v198 sc
     join specialties s on s.code=sc.specialty_code where sc.capability_key=x.capacidad_clave
       and (not exists(select 1 from public.kombax_specialty_service_requirements_r120 r
         where r.specialty_code=sc.specialty_code and r.capability_key=sc.capability_key)
         or exists(select 1 from approved a where a.code=sc.specialty_code))))
 )
 select x.capacidad_clave,min(x.origin),coalesce(c.sensible,false)
 from scoped x left join public.kombax_capacidades c on c.clave=x.capacidad_clave
 group by x.capacidad_clave,c.sensible order by x.capacidad_clave;
end $$;
revoke all on function public.app_kombax_profile_capabilities_v196(uuid) from public,anon;
grant execute on function public.app_kombax_profile_capabilities_v196(uuid) to authenticated;
commit;
