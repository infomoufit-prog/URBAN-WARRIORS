-- Usage help reads published guides for free. Model calls require an actual
-- commercial entitlement; the historical default allowance is not proof of one.
create or replace function public.app_kombax_usage_help_access_r272(
  p_tenant_ref text default null, p_ticket_id text default null
) returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_ref text:=btrim(coalesce(p_tenant_ref,''));
  v_ticket_ref text; v_id uuid; v_subject text; v_type text; v_paid boolean:=false;
begin
  if v_uid is null then return jsonb_build_object('ai_allowed',false); end if;
  if nullif(btrim(p_ticket_id),'') is not null then
    select t.tenant_ref into v_ticket_ref from kombax_customer_ops.tickets t
      where t.ticket_id=p_ticket_id and t.user_ref=v_uid and t.category='MANAGEMENT';
    if not found or (v_ref<>'' and v_ref is distinct from v_ticket_ref) then
      return jsonb_build_object('ai_allowed',false);
    end if;
    v_ref:=v_ticket_ref;
  end if;
  if v_ref='' or not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ref) then
    return jsonb_build_object('ai_allowed',false);
  end if;
  begin v_id:=split_part(v_ref,':',2)::uuid;
    exception when invalid_text_representation then return jsonb_build_object('ai_allowed',false);
  end;
  if v_ref like 'club:%' then
    v_subject:='club'; v_type:='club';
    if not exists(select 1 from public.clubes c where c.id=v_id and c.activo) then
      return jsonb_build_object('ai_allowed',false);
    end if;
  elsif v_ref like 'profile:%' then
    v_subject:='perfil_directo';
    select lower(d.tipo) into v_type from public.perfiles_kombax_directos d
      where d.id=v_id and d.estado not in ('suspendido','cerrado');
    if not found or v_type not in ('marca','federacion') then
      return jsonb_build_object('ai_allowed',false);
    end if;
  else return jsonb_build_object('ai_allowed',false);
  end if;
  -- Unverified demo trials retain their curated Assist questions, not arbitrary usage AI.
  if kombax_commercial.trial_safe_r97(v_ref) then
    return jsonb_build_object('ai_allowed',false);
  end if;
  select exists(select 1 from public.kombax_suscripciones s
      where s.sujeto_tipo=v_subject and s.sujeto_id=v_id
        and s.estado in ('activa','prueba')
        and s.modalidad::text in ('club','premium','enterprise','federacion_institucional','marca_profesional','brand_basic','brand_growth','brand_enterprise','club_basico','club_premium')
        and (s.inicia_en is null or s.inicia_en<=now()) and (s.termina_en is null or s.termina_en>now()))
    or exists(select 1 from kombax_commercial.pilot_entities_r97 p
      where p.tenant_ref=v_ref and kombax_commercial.program_phase_r97()<>'PREPARATION')
    or exists(select 1 from kombax_commercial.plan_benefits_r97 b
      where b.subject_type=case when v_type='club' then 'club' else 'direct_profile' end
        and b.subject_id=v_id and b.starts_at<=now() and b.ends_at>now()
        and b.plan_code in ('club','premium','enterprise','federation','federacion_institucional','marca_profesional','brand_basic','brand_growth','brand_enterprise'))
    into v_paid;
  return jsonb_build_object('ai_allowed',v_paid);
end;
$$;
revoke all on function public.app_kombax_usage_help_access_r272(text,text) from public,anon;
grant execute on function public.app_kombax_usage_help_access_r272(text,text) to authenticated;
comment on function public.app_kombax_usage_help_access_r272(text,text) is 'R272: own organization only; paid/trial/pilot entitlement gate for usage help. Does not grant plans, credits, or data access.';
