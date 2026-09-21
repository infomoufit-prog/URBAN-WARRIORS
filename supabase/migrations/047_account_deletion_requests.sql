begin;

-- KOMBAX 047 · Solicitud trazable de eliminación/cierre.
-- No hace DELETE indiscriminado: separa cuenta personal, perfil público y tenant/club,
-- preservando datos sujetos a retención legal hasta la resolución correspondiente.
create table if not exists public.kombax_solicitudes_eliminacion(
  id uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfiles(id),
  alcance text not null check(alcance in ('account','profile','club')),
  perfil_directo_id uuid references public.perfiles_kombax_directos(id) on delete set null,
  club_id uuid references public.clubes(id) on delete set null,
  estado text not null default 'requested' check(estado in ('requested','in_review','needs_information','confirmed','cancelled','completed','rejected')),
  motivo text,
  nota_retencion text,
  resolucion text,
  solicitado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  completado_en timestamptz,
  resuelto_por uuid references public.perfiles(id),
  constraint kombax_delete_scope_target_v047 check(
    (alcance='account' and perfil_directo_id is null and club_id is null)
    or (alcance='profile' and perfil_directo_id is not null and club_id is null)
    or (alcance='club' and club_id is not null and perfil_directo_id is null)
  )
);
create index if not exists ix_kombax_delete_owner_v047 on public.kombax_solicitudes_eliminacion(perfil_id,solicitado_en desc);
create unique index if not exists uq_kombax_delete_open_v047 on public.kombax_solicitudes_eliminacion(perfil_id,alcance,coalesce(perfil_directo_id,'00000000-0000-0000-0000-000000000000'::uuid),coalesce(club_id,'00000000-0000-0000-0000-000000000000'::uuid)) where estado in ('requested','in_review','needs_information','confirmed');
alter table public.kombax_solicitudes_eliminacion enable row level security;
revoke all on table public.kombax_solicitudes_eliminacion from public,anon,authenticated;

create or replace function public.app_kombax_solicitudes_eliminacion_v047()
returns table(id uuid,alcance text,perfil_directo_id uuid,club_id uuid,estado text,motivo text,nota_retencion text,resolucion text,solicitado_en timestamptz,actualizado_en timestamptz,completado_en timestamptz)
language sql stable security definer set search_path=public,auth as $$
  select s.id,s.alcance,s.perfil_directo_id,s.club_id,s.estado,s.motivo,s.nota_retencion,s.resolucion,s.solicitado_en,s.actualizado_en,s.completado_en
  from public.kombax_solicitudes_eliminacion s where s.perfil_id=auth.uid() order by s.solicitado_en desc;
$$;
revoke all on function public.app_kombax_solicitudes_eliminacion_v047() from public,anon;
grant execute on function public.app_kombax_solicitudes_eliminacion_v047() to authenticated;

create or replace function public.app_kombax_eliminacion_mutate_v047(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_req public.kombax_solicitudes_eliminacion;v_scope text;v_profile uuid;v_club uuid;v_id uuid;v_state text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);end if;

  if p_operation='kombax.deletion.request' then
    v_scope:=lower(coalesce(v_payload->>'alcance','account'));if v_scope not in ('account','profile','club') then raise exception 'KOMBAX_DELETION_SCOPE_INVALID';end if;
    begin v_profile:=nullif(v_payload->>'perfil_directo_id','')::uuid;v_club:=nullif(v_payload->>'club_id','')::uuid;exception when others then raise exception 'KOMBAX_DELETION_TARGET_INVALID';end;
    if v_scope='account' then v_profile:=null;v_club:=null;
    elsif v_scope='profile' then if v_profile is null or not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_profile and d.perfil_id=v_uid) then raise exception 'KOMBAX_DELETION_PROFILE_FORBIDDEN';end if;v_club:=null;
    else if v_club is null or not public.app_puede_gestionar_perfil_club_v035(v_club) then raise exception 'KOMBAX_DELETION_CLUB_FORBIDDEN';end if;v_profile:=null;end if;
    insert into public.kombax_solicitudes_eliminacion(perfil_id,alcance,perfil_directo_id,club_id,motivo,nota_retencion)
    values(v_uid,v_scope,v_profile,v_club,nullif(left(btrim(v_payload->>'motivo'),1200),''),'La solicitud no borra automáticamente trazabilidad económica o legal que deba conservarse.') returning * into v_req;
    v_result:=to_jsonb(v_req);
  elsif p_operation='kombax.deletion.cancel' then
    begin v_id:=(v_payload->>'solicitud_id')::uuid;exception when others then raise exception 'KOMBAX_DELETION_ID_INVALID';end;
    update public.kombax_solicitudes_eliminacion set estado='cancelled',actualizado_en=now() where id=v_id and perfil_id=v_uid and estado in ('requested','needs_information') returning * into v_req;
    if v_req.id is null then raise exception 'KOMBAX_DELETION_CANCEL_NOT_ALLOWED';end if;v_result:=to_jsonb(v_req);
  elsif p_operation='kombax.deletion.review' then
    if not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;
    begin v_id:=(v_payload->>'solicitud_id')::uuid;exception when others then raise exception 'KOMBAX_DELETION_ID_INVALID';end;
    v_state:=lower(coalesce(v_payload->>'estado',''));if v_state not in ('in_review','needs_information','confirmed','completed','rejected') then raise exception 'KOMBAX_DELETION_STATE_INVALID';end if;
    update public.kombax_solicitudes_eliminacion set estado=v_state,resolucion=nullif(left(btrim(v_payload->>'resolucion'),2000),''),nota_retencion=coalesce(nullif(left(btrim(v_payload->>'nota_retencion'),1200),''),nota_retencion),resuelto_por=v_uid,actualizado_en=now(),completado_en=case when v_state='completed' then now() else completado_en end where id=v_id returning * into v_req;
    if v_req.id is null then raise exception 'KOMBAX_DELETION_NOT_FOUND';end if;v_result:=to_jsonb(v_req);
  else raise exception 'KOMBAX_DELETION_OPERATION_NOT_ALLOWED';end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when unique_violation then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise exception 'KOMBAX_DELETION_ALREADY_OPEN';
when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_eliminacion_mutate_v047(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eliminacion_mutate_v047(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
