begin;

create index if not exists idx_payment_attempts_event_ticket_order_r625
  on kombax_payments.payment_attempts(event_ticket_order_id)
  where event_ticket_order_id is not null;

create index if not exists idx_event_ticket_history_actor_r625
  on kombax_payments.event_ticket_order_history(actor_user_id)
  where actor_user_id is not null;

create or replace function public.app_kombax_evento_entradas_estado_v173(p_evento_id uuid)
returns text language plpgsql stable security definer set search_path='' as $$
declare e public.kombax_eventos_publicos;v_visible boolean:=false;v_reserved integer:=0;
begin
  select * into e from public.kombax_eventos_publicos where id=p_evento_id;
  if not found then return null; end if;
  v_visible:=public.app_kombax_event_can_view_v236(p_evento_id)
    or (auth.uid() is not null and public.app_kombax_evento_puede_gestionar_v160(p_evento_id));
  if not coalesce(v_visible,false) then return null; end if;
  if e.estado in ('cancelado','finalizado') then return 'cerradas'; end if;
  if not e.ticketing_enabled or e.ticketing_mode='none' then return 'no_disponible'; end if;
  if e.ticketing_mode='external' and e.tickets_url is null then return 'no_disponible'; end if;
  if e.ticketing_mode='kombax' and (e.ticket_price_minor is null or e.ticket_capacity is null) then return 'no_disponible'; end if;
  if e.tickets_abren_en is not null and now()<e.tickets_abren_en then return 'proximamente'; end if;
  if e.tickets_cierran_en is not null and now()>e.tickets_cierran_en then return 'cerradas'; end if;
  if e.ticketing_mode='kombax' then
    select coalesce(sum(o.quantity),0)::integer into v_reserved
    from kombax_payments.event_ticket_orders o
    where o.event_id=e.id and (o.status='paid' or (o.status='pending_payment' and o.expires_at>now()));
    if e.ticket_capacity<=v_reserved then return 'agotadas'; end if;
  end if;
  return 'venta';
end $$;

revoke all on function public.app_kombax_evento_entradas_estado_v173(uuid) from public;
grant execute on function public.app_kombax_evento_entradas_estado_v173(uuid) to anon,authenticated;

notify pgrst,'reload schema';
commit;
