-- R103: customer-safe, entity-specific balance; no API economy is exposed.
begin;
create or replace function public.app_kombax_ai_credits_r97(p_tenant_ref text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_ctx record;v_data jsonb;v_total numeric;v_used numeric;
 v_period timestamptz;v_next timestamptz;v_plan_amount integer;v_wallet kombax_ai_ops.ai_wallets_r97%rowtype;
 v_assist numeric;v_migrations numeric;v_trial boolean;
begin
 if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
 select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
 if v_ctx.tenant_ref not like 'club:%' and v_ctx.tenant_ref not like 'profile:%' then
  raise exception 'organization_required' using errcode='42501'; end if;
 select exists(select 1 from kombax_commercial.trial_entities_r97 t
   where v_ctx.tenant_ref='club:'||t.club_id::text and t.verified_at is null
     and t.converted_at is null and t.ends_at>now()) into v_trial;
 if not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ctx.tenant_ref)
   and not (v_trial and v_ctx.tenant_ref like 'club:%'
     and public.app_puede_gestionar_perfil_club_v035(split_part(v_ctx.tenant_ref,':',2)::uuid)) then
  raise exception 'organization_access_required' using errcode='42501'; end if;
 v_data:=kombax_ai_ops.ai_ensure_wallet_r97(v_ctx.tenant_ref,v_ctx.plan,now());
 select * into v_wallet from kombax_ai_ops.ai_wallets_r97 where tenant_ref=v_ctx.tenant_ref;
 v_period:=date_trunc('month',now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid';
 v_next:=((v_period at time zone 'Europe/Madrid')+interval '1 month') at time zone 'Europe/Madrid';
 v_plan_amount:=case when v_trial then 150 when coalesce((v_data->>'pilot')::boolean,false)
   then case when v_ctx.plan in ('FEDERATION','KOMBAX_PRO') then 4000 else 2000 end
   else kombax_ai_ops.ai_monthly_amount_r97(v_ctx.plan) end;
 select coalesce(sum(total),0) into v_total from kombax_ai_ops.ai_credit_grants_r97
 where tenant_ref=v_ctx.tenant_ref and (grant_type='purchased' and (expires_at is null or expires_at>now())
   or grant_type='pilot' and coalesce((v_data->>'pilot')::boolean,false)
   or grant_type='trial' and v_trial
   or created_at>=v_period and created_at<v_next);
 select coalesce(sum(r.charged),0),
   coalesce(sum(r.charged) filter(where t.category='MIGRATION'),0),
   coalesce(sum(r.charged) filter(where t.category<>'MIGRATION'),0)
 into v_used,v_migrations,v_assist
 from kombax_ai_ops.ai_credit_reservations_r97 r
 join kombax_ai_ops.assistance_turns t on t.turn_id=r.turn_id
 where r.tenant_ref=v_ctx.tenant_ref and r.status='SETTLED'
   and r.settled_at>=v_period and r.settled_at<v_next;
 return jsonb_build_object('available',round(v_wallet.available)::integer,
   'reserved',round(v_wallet.reserved)::integer,'granted_total',greatest(v_plan_amount,round(v_total)::integer),
   'plan_total',v_plan_amount,'used_total',round(v_used)::integer,
   'assist_used',round(v_assist)::integer,'migrations_used',round(v_migrations)::integer,
   'plan',v_ctx.plan,'tenant_ref',v_ctx.tenant_ref,'pilot',coalesce((v_data->>'pilot')::boolean,false),
   'trial',v_trial,'renewal_at',v_data->>'renewal_at',
   'shared_between',jsonb_build_array('Assist','Migrations'));
end $$;
revoke all on function public.app_kombax_ai_credits_r97(text) from public,anon,service_role;
grant execute on function public.app_kombax_ai_credits_r97(text) to authenticated;
commit;
