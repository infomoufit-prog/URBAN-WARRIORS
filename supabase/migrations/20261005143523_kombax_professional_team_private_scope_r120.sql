-- R120: content delegation does not include professional clients, documents or money.
begin;
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
 where v_type<>'profesional'
   or (x.capacidad_clave not like 'professional.%'
       and (x.capacidad_clave not like 'events.%' or x.capacidad_clave='events.public.read'))
   or public.app_kombax_puede_gestionar_perfil_v070(p_perfil_directo_id,'edit')
 group by x.capacidad_clave,c.sensible order by x.capacidad_clave;
end $$;
revoke all on function public.app_kombax_profile_capabilities_v196(uuid) from public,anon;
grant execute on function public.app_kombax_profile_capabilities_v196(uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.app_kombax_professional_workspace_v198(p_profile_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_uid uuid:=auth.uid();v_type text;v_caps text[]:='{}'::text[];v_result jsonb;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 if p_profile_id is null then raise exception 'KOMBAX_PROFILE_REQUIRED';end if;
 if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'read') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED';end if;
 if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'edit') then raise exception 'KOMBAX_PRIVATE_OPERATIONS_ROLE_REQUIRED';end if;
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
end $function$
;
commit;
