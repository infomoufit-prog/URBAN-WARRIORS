begin;
create or replace function kombax_ai_ops.assistant_identity_context_fix16(p_uid uuid,p_tenant_ref text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_id uuid;v_type text;v_name text;
begin
 if p_uid is null or not kombax_ai_ops.org_assist_access_allowed(p_uid,p_tenant_ref) then raise exception 'ASSIST_CONTEXT_FORBIDDEN' using errcode='42501';end if;
 if p_tenant_ref like 'club:%' then
  v_id:=substring(p_tenant_ref from 6)::uuid;
  select nombre into strict v_name from public.clubes where id=v_id and activo;
  return jsonb_build_object('entity_type','club','entity_id',v_id,'entity_name',v_name,'scope','authorized_catalog',
    'disciplines',coalesce((select jsonb_agg(x) from(select id,nombre from public.disciplinas where club_id=v_id and activa order by nombre limit 100)x),'[]'::jsonb),
    'groups',coalesce((select jsonb_agg(x) from(select id,nombre,disciplina_id from public.grupos where club_id=v_id and activo order by nombre limit 100)x),'[]'::jsonb),
    'tariffs',coalesce((select jsonb_agg(x) from(select id,nombre,disciplina_id from public.tarifas where club_id=v_id and activa order by nombre limit 100)x),'[]'::jsonb));
 end if;
 if p_tenant_ref like 'profile:%' then
  v_id:=substring(p_tenant_ref from 9)::uuid;
  select tipo,nombre_publico into strict v_type,v_name from public.perfiles_kombax_directos where id=v_id and estado='activo';
  return jsonb_build_object('entity_type',v_type,'entity_id',v_id,'entity_name',v_name,'scope','authorized_identity','disciplines','[]'::jsonb,'groups','[]'::jsonb,'tariffs','[]'::jsonb);
 end if;
 raise exception 'ASSIST_ORGANIZATION_REQUIRED' using errcode='42501';
end $$;
revoke all on function kombax_ai_ops.assistant_identity_context_fix16(uuid,text) from public,anon,authenticated;
create or replace function public.app_kombax_assist_identity_context_fix16(p_tenant_ref text)
returns jsonb language sql stable security definer set search_path='' as $$
 select kombax_ai_ops.assistant_identity_context_fix16(auth.uid(),p_tenant_ref);
$$;
revoke all on function public.app_kombax_assist_identity_context_fix16(text) from public,anon;
grant execute on function public.app_kombax_assist_identity_context_fix16(text) to authenticated;
CREATE OR REPLACE FUNCTION public.app_kombax_assist_turn_internal_v227(p_turn_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_turn kombax_ai_ops.assistance_turns%rowtype;v_ctx record;v_policy kombax_ai_ops.assistance_cost_policies%rowtype;v_messages jsonb;v_files jsonb;v_file_count integer;v_visual integer;v_bytes bigint;v_management jsonb:='{}'::jsonb;v_identity jsonb:='{}'::jsonb;
begin
  select * into v_turn from kombax_ai_ops.assistance_turns t where t.turn_id=p_turn_id and t.status='RESERVED'; if not found then raise exception 'turn_not_reserved' using errcode='P0002'; end if; select * into v_ctx from kombax_ai_ops.resolve_context(v_turn.user_ref,v_turn.tenant_ref); select * into strict v_policy from kombax_ai_ops.assistance_cost_policies p where p.plan=v_ctx.plan;
  select coalesce(jsonb_agg(jsonb_build_object('turn_id',m.turn_id,'role',lower(m.role),'content',left(m.content_text,4000)) order by m.created_at),'[]'::jsonb) into v_messages from (select * from kombax_customer_ops.assist_chat_messages m where m.ticket_id=v_turn.ticket_id order by m.created_at desc limit 10) m;
  if v_turn.category='MIGRATION' then select coalesce(jsonb_agg(jsonb_build_object('file_id',x.file_id,'original_name',x.original_name,'mime_type',x.mime_type,'size_bytes',x.size_bytes,'storage_path',x.storage_path) order by x.created_at),'[]'::jsonb),count(*),count(*) filter(where x.mime_type like 'image/%'),coalesce(sum(x.size_bytes),0) into v_files,v_file_count,v_visual,v_bytes from (select f.* from kombax_customer_ops.migration_files f left join kombax_customer_ops.migration_file_analysis a on a.file_id=f.file_id where f.ticket_id=v_turn.ticket_id and f.user_ref=v_turn.user_ref and a.file_id is null and f.status in('STAGED','FAILED') order by f.created_at limit v_policy.max_files_per_batch) x; else v_files:='[]'::jsonb;v_file_count:=0;v_visual:=0;v_bytes:=0; end if;
  if v_turn.category in ('MIGRATION','MANAGEMENT') then
    if v_ctx.tenant_ref is distinct from v_turn.tenant_ref and v_ctx.tenant_ref is distinct from ('club:'||v_turn.tenant_ref) then raise exception 'ASSIST_CONTEXT_CHANGED' using errcode='42501';end if;
    v_identity:=kombax_ai_ops.assistant_identity_context_fix16(v_turn.user_ref,v_ctx.tenant_ref);
  end if;
  if v_turn.category='MANAGEMENT' then v_management:=kombax_ai_ops.management_context(v_turn.user_ref,v_turn.tenant_ref); end if;
  if v_visual>v_policy.max_visual_files_per_batch then select coalesce(jsonb_agg(z.item order by z.ord),'[]'::jsonb) into v_files from (select value item,ord from jsonb_array_elements(v_files) with ordinality a(value,ord) where ord<=v_policy.max_visual_files_per_batch) z; v_file_count:=jsonb_array_length(v_files);v_visual:=v_file_count; end if;
  if v_bytes::numeric/1048576>v_policy.max_batch_mb then select coalesce(jsonb_agg(z.item order by z.ord),'[]'::jsonb) into v_files from (select value item,ord,sum(coalesce((value->>'size_bytes')::bigint,0)) over(order by ord) running from jsonb_array_elements(v_files) with ordinality a(value,ord)) z where z.running<=v_policy.max_batch_mb*1048576; v_file_count:=jsonb_array_length(v_files);v_visual:=(select count(*) from jsonb_array_elements(v_files) e where e->>'mime_type' like 'image/%'); end if;
  update kombax_ai_ops.assistance_turns set file_count=v_file_count,visual_file_count=v_visual where turn_id=p_turn_id; return jsonb_build_object('turn_id',v_turn.turn_id,'ticket_id',v_turn.ticket_id,'category',v_turn.category,'model_alias',v_policy.default_model,'max_output_tokens',v_policy.max_output_tokens,'image_detail',v_policy.image_detail,'messages',v_messages,'files',v_files,'management_context',v_management,'identity_context',v_identity);
end;$function$
;
create or replace function public.app_kombax_club_team_revoke_fix16(p_club_id uuid,p_perfil_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_previous jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501';end if;
 perform 1 from public.clubes where id=p_club_id and activo for update;
 if not found then raise exception 'CLUB_NOT_AVAILABLE';end if;
 if not public.app_kombax_club_owner_fix14(p_club_id) then raise exception 'CLUB_OWNER_REQUIRED' using errcode='42501';end if;
 if exists(select 1 from public.miembros_club where club_id=p_club_id and perfil_id=p_perfil_id and rol='direccion') then raise exception 'OWNER_ROLE_PROTECTED';end if;
 select jsonb_agg(jsonb_build_object('role',rol,'coordination',coordinacion)) into v_previous
 from public.miembros_club where club_id=p_club_id and perfil_id=p_perfil_id and activo and rol in('secretaria','economia','comunicacion','monitor');
 if v_previous is null then return jsonb_build_object('ok',true,'revoked',false);end if;
 update public.miembros_club set activo=false,coordinacion=false where club_id=p_club_id and perfil_id=p_perfil_id and rol in('secretaria','economia','comunicacion','monitor');
 update public.invitaciones_club set estado='revocada' where club_id=p_club_id and tipo_invitacion='equipo' and estado='pendiente' and (aceptado_por=p_perfil_id or lower(email)=(select lower(email) from auth.users where id=p_perfil_id));
 insert into public.kombax_club_team_role_audit_fix14(club_id,perfil_id,actor_id,previous_roles,new_role) values(p_club_id,p_perfil_id,auth.uid(),v_previous,'revoked');
 return jsonb_build_object('ok',true,'revoked',true,'club_id',p_club_id,'perfil_id',p_perfil_id);
end $$;
revoke all on function public.app_kombax_club_team_revoke_fix16(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_club_team_revoke_fix16(uuid,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
