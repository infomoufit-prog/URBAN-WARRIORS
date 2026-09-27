-- Pilot security: do not expose stock state for unpublished Showcase listings.
-- Preserve the existing RPC signature and allow the provider to inspect its own drafts.
create or replace function public.app_showcase_listing_details_r628(p_ids uuid[])
returns table(id uuid, listing_kind text, product_type text, stock_status text)
language sql stable security definer set search_path = ''
as $function$
  select e.id, e.listing_kind, e.product_type,
    case
      when e.listing_kind = 'professional_service' then 'not_applicable'
      when e.stock is null then 'not_tracked'
      when e.stock = 0 then 'out_of_stock'
      when e.stock <= e.stock_alert_threshold then 'low_stock'
      else 'in_stock'
    end
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

revoke all on function public.app_showcase_listing_details_r628(uuid[]) from public;
grant execute on function public.app_showcase_listing_details_r628(uuid[]) to anon, authenticated;
