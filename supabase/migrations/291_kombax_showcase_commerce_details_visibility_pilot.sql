-- Pilot security: authenticated users must not read another provider's draft stock.
create or replace function public.app_showcase_commerce_details_v259(p_ids uuid[])
returns table(
  id uuid, commerce_enabled boolean, precio_venta numeric, stock integer,
  variantes jsonb, fulfillment text, shipping_policy text, returns_policy text,
  seller_payments_active boolean
)
language sql stable security definer set search_path = ''
as $function$
  select e.id, e.commerce_enabled, e.precio_venta, e.stock, e.variantes,
    e.fulfillment, e.shipping_policy, e.returns_policy,
    kombax_marketplace.seller_ready_r627(e.marca_id)
  from public.kombax_showcase_elementos e
  join public.kombax_showcase_marcas m on m.id = e.marca_id
  where e.id = any(coalesce(p_ids, '{}'::uuid[]))
    and (
      (e.estado = 'publicado' and m.estado = 'publicada')
      or (
        auth.uid() is not null
        and public.app_kombax_showcase_puede_gestionar_v045(e.marca_id)
      )
    );
$function$;

revoke all on function public.app_showcase_commerce_details_v259(uuid[]) from public, anon;
grant execute on function public.app_showcase_commerce_details_v259(uuid[]) to authenticated;
