create or replace function public.app_showcase_product_rules_fix16()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
return coalesce((select jsonb_agg(jsonb_build_object('category_code',r.category_code,'label',r.label,'policy_status',r.policy_status,'manufacturer_required',r.manufacturer_required,'eu_responsible_person_when_non_eu',r.eu_responsible_person_when_non_eu,'ce_requirement',r.ce_requirement,'warnings_required',r.warnings_required,'documentation_required',r.documentation_required) order by r.label) from kombax_compliance.product_category_rules r),'[]'::jsonb);
end $$;
revoke all on function public.app_showcase_product_rules_fix16() from public,anon;
grant execute on function public.app_showcase_product_rules_fix16() to authenticated;
