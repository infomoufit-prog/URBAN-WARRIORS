begin;
-- Titular del club: Dirección persistida, nunca la bandera de Coordinación.
create or replace function public.app_kombax_club_owner_fix14(p_club_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.miembros_club m
 where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and m.rol='direccion');
$$;
revoke all on function public.app_kombax_club_owner_fix14(uuid) from public,anon;
grant execute on function public.app_kombax_club_owner_fix14(uuid) to authenticated;

create table public.kombax_club_team_role_audit_fix14(
 id uuid primary key default gen_random_uuid(),club_id uuid not null references public.clubes(id),
 perfil_id uuid not null references public.perfiles(id),actor_id uuid not null references public.perfiles(id),
 previous_roles jsonb not null,new_role text not null,created_at timestamptz not null default now()
);
alter table public.kombax_club_team_role_audit_fix14 enable row level security;
revoke all on public.kombax_club_team_role_audit_fix14 from public,anon,authenticated;
grant select on public.kombax_club_team_role_audit_fix14 to authenticated;
create policy club_owner_role_history on public.kombax_club_team_role_audit_fix14
 for select to authenticated using(public.app_kombax_club_owner_fix14(club_id));

create or replace function public.app_kombax_club_team_role_fix14(p_club_id uuid,p_perfil_id uuid,p_role text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text:=lower(btrim(coalesce(p_role,'')));v_previous jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501';end if;
 -- Serializa cambios del equipo y revalida autorización después del bloqueo.
 perform 1 from public.clubes where id=p_club_id and activo for update;
 if not found then raise exception 'CLUB_NOT_AVAILABLE';end if;
 if not public.app_kombax_club_owner_fix14(p_club_id) then raise exception 'CLUB_OWNER_REQUIRED' using errcode='42501';end if;
 if v_role not in('coordinacion','secretaria','economia','comunicacion','monitor') then raise exception 'TEAM_ROLE_INVALID';end if;
 if exists(select 1 from public.miembros_club where club_id=p_club_id and perfil_id=p_perfil_id and rol='direccion') then raise exception 'OWNER_ROLE_PROTECTED';end if;
 select jsonb_agg(jsonb_build_object('role',rol,'coordination',coordinacion)) into v_previous
 from public.miembros_club where club_id=p_club_id and perfil_id=p_perfil_id and activo and rol in('secretaria','economia','comunicacion','monitor');
 if v_previous is null then raise exception 'ACTIVE_TEAM_MEMBER_REQUIRED';end if;
 update public.miembros_club set activo=false,coordinacion=false
 where club_id=p_club_id and perfil_id=p_perfil_id and rol in('secretaria','economia','comunicacion','monitor');
 if v_role='coordinacion' then
  insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion) values
  (p_club_id,p_perfil_id,'secretaria',true,true),(p_club_id,p_perfil_id,'economia',true,true),(p_club_id,p_perfil_id,'comunicacion',true,true)
  on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=true;
 else
  insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion) values(p_club_id,p_perfil_id,v_role::public.rol_club,true,false)
  on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=false;
 end if;
 -- Una invitación anterior no puede restaurar silenciosamente el rol antiguo.
 update public.invitaciones_club set estado='revocada' where club_id=p_club_id and tipo_invitacion='equipo' and estado='pendiente'
 and (aceptado_por=p_perfil_id or lower(email)=(select lower(email) from auth.users where id=p_perfil_id));
 insert into public.kombax_club_team_role_audit_fix14(club_id,perfil_id,actor_id,previous_roles,new_role)
 values(p_club_id,p_perfil_id,auth.uid(),v_previous,v_role);
 return jsonb_build_object('ok',true,'club_id',p_club_id,'perfil_id',p_perfil_id,'role',v_role);
end $$;
revoke all on function public.app_kombax_club_team_role_fix14(uuid,uuid,text) from public,anon;
grant execute on function public.app_kombax_club_team_role_fix14(uuid,uuid,text) to authenticated;

create or replace function public.app_guardar_grado(p_club_id uuid,p_id uuid,p_disciplina_id uuid,p_nombre text,p_orden smallint,p_color text,p_meses_minimos smallint,p_activo boolean)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;v_previous uuid;
begin
 if auth.uid() is null or not public.tiene_rol_club(p_club_id,'direccion','secretaria','monitor') then raise exception 'No tienes permiso para gestionar grados';end if;
 perform 1 from public.disciplinas where club_id=p_club_id and id=p_disciplina_id for update;
 if not found then raise exception 'Disciplina no válida';end if;
 if nullif(btrim(p_nombre),'') is null then raise exception 'El nombre del grado es obligatorio';end if;
 if coalesce(p_orden,1)<1 or coalesce(p_meses_minimos,0)<0 then raise exception 'GRADE_LEVEL_INVALID';end if;
 if nullif(btrim(p_color),'') is not null and p_color !~ '^#[0-9A-Fa-f]{6}$' then raise exception 'GRADE_COLOR_INVALID';end if;
 if p_id is null then
  insert into public.grados(club_id,disciplina_id,nombre,orden,color,meses_minimos,activo)
  values(p_club_id,p_disciplina_id,btrim(p_nombre),coalesce(p_orden,1),nullif(btrim(p_color),''),p_meses_minimos,coalesce(p_activo,true)) returning id into v_id;
 else
  select disciplina_id into v_previous from public.grados where id=p_id and club_id=p_club_id for update;
  if not found then raise exception 'Grado no encontrado';end if;
  if v_previous<>p_disciplina_id and (exists(select 1 from public.socio_disciplinas where grado_id=p_id)
   or exists(select 1 from public.graduaciones where grado_id=p_id or grado_anterior_id=p_id)) then raise exception 'GRADE_DISCIPLINE_IN_USE';end if;
  update public.grados set disciplina_id=p_disciplina_id,nombre=btrim(p_nombre),orden=coalesce(p_orden,orden),color=nullif(btrim(p_color),''),meses_minimos=p_meses_minimos,activo=coalesce(p_activo,true)
  where id=p_id and club_id=p_club_id returning id into v_id;
 end if;
 return v_id;
end $$;
-- La escritura de grados continúa pasando por la mutación auditada existente.
revoke all on function public.app_guardar_grado(uuid,uuid,uuid,text,smallint,text,smallint,boolean) from public,anon,authenticated;
-- Las funciones de aprobación y contratación se incorporan abajo, conservando sus cuerpos vigentes.
CREATE OR REPLACE FUNCTION kombax_billing.subject(p_actor uuid, p_type text, p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare kind text;verified boolean;
begin
 if p_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';end if;
 if p_type='club' then
  if not exists(select 1 from public.miembros_club m where m.club_id=p_id and m.perfil_id=p_actor and m.activo and m.rol='direccion') then raise exception 'OWNER_REQUIRED' using errcode='42501';end if;
  kind:='club';select exists(select 1 from public.kombax_solicitudes_alta a where a.club_id=p_id and a.tipo='club' and a.estado='verified') into verified;
 elsif p_type='direct_profile' then
  select case d.tipo when 'marca' then 'brand' when 'federacion' then 'federation' end,d.verificacion_estado='verificado' and d.workflow_estado in('verified','limited') into kind,verified
   from public.perfiles_kombax_directos d where d.id=p_id and d.perfil_id=p_actor and d.estado='activo';
  if kind is null then raise exception 'ORGANIZATION_OWNER_REQUIRED' using errcode='42501';end if;
 else raise exception 'INVALID_SUBJECT';end if;
 return jsonb_build_object('audience',kind,'verified',coalesce(verified,false),'pilot',exists(select 1 from kombax_commercial.pilot_entities_r97 p where p.subject_type=p_type and p.subject_id=p_id));
end $function$
;
CREATE OR REPLACE FUNCTION public.app_kombax_commercial_plan_request_r64(p_subject_type text, p_subject_id uuid, p_plan_code text, p_billing_cycle text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid();v_audience text;v_plan kombax_commercial.plan_pricing_r64;v_id uuid;v_founder_open boolean:=false;v_terms kombax_commercial.organization_terms_r64;v_founder_requested boolean:=false;v_cycle text:=lower(p_billing_cycle);
begin
  if p_subject_type='club' and not public.app_kombax_club_owner_fix14(p_subject_id) then raise exception 'CLUB_OWNER_REQUIRED' using errcode='42501';end if;
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if not kombax_commercial.can_manage_subject_r64(p_subject_type,p_subject_id) then raise exception 'COMMERCIAL_SUBJECT_MANAGEMENT_REQUIRED'; end if;
  if v_cycle not in('monthly','annual') then raise exception 'COMMERCIAL_BILLING_CYCLE_INVALID'; end if;
  if p_subject_type='club' then v_audience:='club'; else select case d.tipo when 'marca' then 'brand' when 'federacion' then 'federation' else d.tipo end into v_audience from public.perfiles_kombax_directos d where d.id=p_subject_id; end if;
  select * into v_plan from kombax_commercial.plan_pricing_r64 where plan_code=lower(p_plan_code) and active and audience=v_audience;
  if not found then raise exception 'COMMERCIAL_PLAN_NOT_AVAILABLE_FOR_SUBJECT'; end if;
  if v_audience='brand' and not exists(select 1 from public.perfiles_kombax_directos d where d.id=p_subject_id and d.tipo='marca' and d.estado='activo' and d.verificacion_estado='verificado') then raise exception 'VERIFIED_BRAND_REQUIRED'; end if;
  select coalesce((value#>>'{}')::boolean,false) into v_founder_open from kombax_commercial.runtime_config_r64 where config_key='founder_sales_open';
  select * into v_terms from kombax_commercial.organization_terms_r64 where subject_type=p_subject_type and subject_id=p_subject_id;
  v_founder_requested:=v_cycle='monthly' and (coalesce(v_terms.founder_locked,false) or (coalesce(v_founder_open,false) and v_terms.founder_lost_at is null));
  insert into kombax_commercial.plan_requests_r64(subject_type,subject_id,requested_plan_code,billing_cycle,founder_requested,request_id,requested_by)
  values(p_subject_type,p_subject_id,v_plan.plan_code,v_cycle,v_founder_requested,p_request_id,v_uid)
  on conflict(request_id) do update set updated_at=now() returning id into v_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'plan_request_id',v_id,'status','requested','founder_requested',v_founder_requested,'billing_activation_performed',false);
end $function$
;
CREATE OR REPLACE FUNCTION public.app_kombax_billing_portal_r118(p_subject_type text, p_subject_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare gate jsonb;sub kombax_billing.subscriptions;
begin
 if p_subject_type='club' and not public.app_kombax_club_owner_fix14(p_subject_id) then raise exception 'CLUB_OWNER_REQUIRED' using errcode='42501';end if;
 select * into sub from kombax_billing.subscriptions where subject_type=p_subject_type and subject_id=p_subject_id;
 begin gate:=kombax_billing.subject(auth.uid(),p_subject_type,p_subject_id);exception when insufficient_privilege then if sub.actor_id is distinct from auth.uid() or auth.uid() is null then raise;end if;gate:=jsonb_build_object('pilot',false);end;
 if (gate->>'pilot')::boolean then raise exception 'PILOT_BILLING_EXCLUDED';end if;
 select * into sub from kombax_billing.subscriptions where subject_type=p_subject_type and subject_id=p_subject_id;
 if not found then raise exception 'SUBSCRIPTION_NOT_FOUND';end if;
 return jsonb_build_object('customer_id',sub.customer_id);
end $function$
;


CREATE OR REPLACE FUNCTION public.app_kombax_solicitud_equipo_resolver_v060(p_solicitud_id uuid, p_estado text, p_rol text DEFAULT NULL::text, p_nota text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare s public.kombax_solicitudes_equipo_club; st text:=lower(trim(coalesce(p_estado,''))); role text:=lower(trim(coalesce(p_rol,''))); db_role public.rol_club; is_coord boolean:=false;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  select * into s from public.kombax_solicitudes_equipo_club where id=p_solicitud_id for update;
  if s.id is null then raise exception 'Solicitud no encontrada';end if;
  if not public.app_kombax_club_owner_fix14(s.club_id) then raise exception 'No tienes permiso para revisar esta solicitud';end if;
  if st not in ('aprobada','rechazada') then raise exception 'Estado no válido';end if;
  if s.estado<>'pendiente' then raise exception 'La solicitud ya ha sido revisada';end if;

  if st='aprobada' then
    if role not in ('coordinacion','secretaria','economia','comunicacion','monitor') then raise exception 'Selecciona un rol de equipo válido';end if;
    is_coord:=role='coordinacion';
    if is_coord and not public.tiene_rol_club(s.club_id,'direccion') then raise exception 'Solo el Gestor puede conceder Coordinación';end if;
    if is_coord then
      insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion) values
        (s.club_id,s.perfil_id,'secretaria',true,true),(s.club_id,s.perfil_id,'economia',true,true),(s.club_id,s.perfil_id,'comunicacion',true,true)
      on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=true;
      db_role:='secretaria';
    else
      db_role:=role::public.rol_club;
      insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
      values(s.club_id,s.perfil_id,db_role,true,false)
      on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=false;
    end if;
  end if;

  update public.kombax_solicitudes_equipo_club
     set estado=st,revisado_en=now(),revisado_por=auth.uid(),rol_asignado=case when st='aprobada' then db_role else null end,coordinacion=case when st='aprobada' then is_coord else false end,nota_revision=left(nullif(trim(coalesce(p_nota,'')),''),1000),actualizado_en=now()
   where id=s.id;
  return jsonb_build_object('id',s.id,'club_id',s.club_id,'perfil_id',s.perfil_id,'estado',st,'rol',case when is_coord then 'coordinacion' when st='aprobada' then db_role::text else null end);
end $function$
;

notify pgrst, 'reload schema';
commit;
