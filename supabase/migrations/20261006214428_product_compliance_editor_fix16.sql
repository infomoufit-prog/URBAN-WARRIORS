create or replace function public.app_showcase_product_editor_fix16(p_product_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare e public.kombax_showcase_elementos;p kombax_compliance.product_profiles;
begin
if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
select * into e from public.kombax_showcase_elementos where id=p_product_id;
if e.id is null or not kombax_payments.can_manage_provider(auth.uid(),e.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
select * into p from kombax_compliance.product_profiles where product_id=e.id;
return jsonb_build_object('product_id',e.id,'product',case when p.product_id is null then null else to_jsonb(p) end,'commerce_ready',coalesce(kombax_compliance.product_compliance_ready_r630(e.id),false));
end $$;
revoke all on function public.app_showcase_product_editor_fix16(uuid) from public,anon;
grant execute on function public.app_showcase_product_editor_fix16(uuid) to authenticated;
