begin;

create schema if not exists kombax_inventory;
revoke all on schema kombax_inventory from public,anon,authenticated;

alter table public.material_catalogo
  add column if not exists precio_compra_medio numeric(12,2),
  add column if not exists stock_minimo integer,
  add column if not exists proveedor text;
alter table public.material_catalogo
  drop constraint if exists material_catalogo_precio_compra_medio_r89_check;
alter table public.material_catalogo
  add constraint material_catalogo_precio_compra_medio_r89_check check(precio_compra_medio is null or precio_compra_medio>=0);
alter table public.material_catalogo
  drop constraint if exists material_catalogo_stock_minimo_r89_check;
alter table public.material_catalogo
  add constraint material_catalogo_stock_minimo_r89_check check(stock_minimo is null or stock_minimo>=0);

alter table public.material_variantes
  add column if not exists precio_compra_medio numeric(12,2),
  add column if not exists precio_venta numeric(12,2),
  add column if not exists stock_minimo integer,
  add column if not exists proveedor text;
alter table public.material_variantes
  drop constraint if exists material_variantes_precio_compra_medio_r89_check;
alter table public.material_variantes
  add constraint material_variantes_precio_compra_medio_r89_check check(precio_compra_medio is null or precio_compra_medio>=0);
alter table public.material_variantes
  drop constraint if exists material_variantes_precio_venta_r89_check;
alter table public.material_variantes
  add constraint material_variantes_precio_venta_r89_check check(precio_venta is null or precio_venta>=0);
alter table public.material_variantes
  drop constraint if exists material_variantes_stock_minimo_r89_check;
alter table public.material_variantes
  add constraint material_variantes_stock_minimo_r89_check check(stock_minimo is null or stock_minimo>=0);

alter table public.material_pedidos
  add column if not exists coste_unitario_snapshot numeric(12,2),
  add column if not exists margen_unitario_snapshot numeric(12,2),
  add column if not exists margen_total_snapshot numeric(12,2);

create table if not exists kombax_inventory.club_stock_movements_r89(
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  material_id uuid not null references public.material_catalogo(id) on delete restrict,
  variante_id uuid references public.material_variantes(id) on delete restrict,
  pedido_id uuid references public.material_pedidos(id) on delete set null,
  movement_type text not null check(movement_type in('purchase','sale','manual_adjustment','internal_use','loss','return','pricing')),
  quantity_delta integer not null default 0,
  stock_before integer,
  stock_after integer,
  unit_cost numeric(12,2),
  unit_sale numeric(12,2),
  gross_margin numeric(14,2),
  supplier text,
  note text,
  actor_user_id uuid references auth.users(id) on delete set null,
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);
alter table kombax_inventory.club_stock_movements_r89 enable row level security;
create index if not exists idx_club_stock_movements_r89_club_created on kombax_inventory.club_stock_movements_r89(club_id,created_at desc);
create index if not exists idx_club_stock_movements_r89_material_created on kombax_inventory.club_stock_movements_r89(material_id,created_at desc);
create index if not exists idx_club_stock_movements_r89_variant on kombax_inventory.club_stock_movements_r89(variante_id) where variante_id is not null;
create index if not exists idx_club_stock_movements_r89_order on kombax_inventory.club_stock_movements_r89(pedido_id) where pedido_id is not null;

alter table public.kombax_showcase_elementos
  add column if not exists precio_compra_medio numeric(12,2),
  add column if not exists proveedor_compra text;
alter table public.kombax_showcase_elementos
  drop constraint if exists showcase_precio_compra_medio_r89_check;
alter table public.kombax_showcase_elementos
  add constraint showcase_precio_compra_medio_r89_check check(precio_compra_medio is null or precio_compra_medio>=0);

alter table kombax_payments.showcase_stock_movements_r65
  add column if not exists unit_cost_minor integer,
  add column if not exists unit_sale_minor integer,
  add column if not exists gross_margin_minor integer;
alter table kombax_payments.showcase_stock_movements_r65
  drop constraint if exists showcase_stock_movement_cost_r89_check;
alter table kombax_payments.showcase_stock_movements_r65
  add constraint showcase_stock_movement_cost_r89_check check(unit_cost_minor is null or unit_cost_minor>=0);
alter table kombax_payments.showcase_stock_movements_r65
  drop constraint if exists showcase_stock_movement_sale_r89_check;
alter table kombax_payments.showcase_stock_movements_r65
  add constraint showcase_stock_movement_sale_r89_check check(unit_sale_minor is null or unit_sale_minor>=0);

alter table public.comunicaciones
  add column if not exists subject_type text,
  add column if not exists subject_id uuid;
create index if not exists idx_comunicaciones_subject_r89 on public.comunicaciones(club_id,subject_type,subject_id,creado_en desc)
  where subject_type is not null and subject_id is not null;

create or replace function kombax_inventory.enrich_showcase_stock_movement_r89()
returns trigger
language plpgsql
security invoker
set search_path=''
as $$
declare v_cost integer;v_sale integer;
begin
  if new.unit_cost_minor is null then
    select case when e.precio_compra_medio is null then null else round(e.precio_compra_medio*100)::integer end
    into v_cost from public.kombax_showcase_elementos e where e.id=new.product_id;
    new.unit_cost_minor:=v_cost;
  end if;
  if new.movement_type='sale' and new.order_id is not null and new.unit_sale_minor is null then
    select i.unit_amount_minor into v_sale
    from kombax_payments.showcase_order_items i
    where i.order_id=new.order_id and i.product_id=new.product_id
    order by i.id limit 1;
    new.unit_sale_minor:=v_sale;
  end if;
  if new.movement_type='sale' and new.unit_cost_minor is not null and new.unit_sale_minor is not null then
    new.gross_margin_minor:=(new.unit_sale_minor-new.unit_cost_minor)*abs(new.quantity_delta);
  elsif new.gross_margin_minor is null and new.unit_cost_minor is not null and new.unit_sale_minor is not null then
    new.gross_margin_minor:=(new.unit_sale_minor-new.unit_cost_minor)*abs(new.quantity_delta);
  end if;
  return new;
end $$;
drop trigger if exists trg_enrich_showcase_stock_movement_r89 on kombax_payments.showcase_stock_movements_r65;
create trigger trg_enrich_showcase_stock_movement_r89
before insert or update of unit_cost_minor,unit_sale_minor,quantity_delta,movement_type
on kombax_payments.showcase_stock_movements_r65
for each row execute function kombax_inventory.enrich_showcase_stock_movement_r89();

create or replace function public.app_kombax_material_inventory_r89(p_club_id uuid,p_limit integer default 200)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());v_limit integer:=least(300,greatest(10,coalesce(p_limit,200)));
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then raise exception 'MATERIAL_INVENTORY_FORBIDDEN'; end if;
  return jsonb_build_object(
    'items',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',m.id,'nombre',m.nombre,'categoria',m.categoria,'referencia',m.referencia,'stock',m.stock,'stock_minimo',m.stock_minimo,
        'precio_compra_medio',m.precio_compra_medio,'precio_venta',m.precio,'proveedor',m.proveedor,
        'margen_unitario',case when m.precio_compra_medio is null then null else m.precio-m.precio_compra_medio end,
        'valor_stock_coste',case when m.precio_compra_medio is null then null else coalesce(m.stock,0)*m.precio_compra_medio end,
        'valor_stock_venta',coalesce(m.stock,0)*coalesce(m.precio,0),
        'variantes',coalesce((select jsonb_agg(jsonb_build_object(
          'id',v.id,'talla',v.talla,'color',v.color,'referencia',v.referencia,'stock',v.stock,'stock_minimo',v.stock_minimo,
          'precio_compra_medio',v.precio_compra_medio,'precio_venta',coalesce(v.precio_venta,m.precio),'proveedor',v.proveedor,
          'margen_unitario',case when coalesce(v.precio_compra_medio,m.precio_compra_medio) is null then null else coalesce(v.precio_venta,m.precio)-coalesce(v.precio_compra_medio,m.precio_compra_medio) end
        ) order by v.talla,v.color,v.id) from public.material_variantes v where v.material_id=m.id and v.club_id=m.club_id and v.activa),'[]'::jsonb)
      ) order by m.orden,m.nombre)
      from (select * from public.material_catalogo where club_id=p_club_id and ciclo_estado='activo' order by orden,nombre limit v_limit) m
    ),'[]'::jsonb),
    'summary',(
      select jsonb_build_object(
        'models',count(*),
        'units',coalesce(sum(case when exists(select 1 from public.material_variantes v where v.material_id=m.id and v.club_id=m.club_id and v.activa)
          then (select coalesce(sum(v.stock),0) from public.material_variantes v where v.material_id=m.id and v.club_id=m.club_id and v.activa)
          else coalesce(m.stock,0) end),0),
        'inventory_cost',coalesce(sum(case when exists(select 1 from public.material_variantes v where v.material_id=m.id and v.club_id=m.club_id and v.activa)
          then (select coalesce(sum(v.stock*coalesce(v.precio_compra_medio,m.precio_compra_medio,0)),0) from public.material_variantes v where v.material_id=m.id and v.club_id=m.club_id and v.activa)
          else coalesce(m.stock,0)*coalesce(m.precio_compra_medio,0) end),0),
        'potential_sale',coalesce(sum(case when exists(select 1 from public.material_variantes v where v.material_id=m.id and v.club_id=m.club_id and v.activa)
          then (select coalesce(sum(v.stock*coalesce(v.precio_venta,m.precio,0)),0) from public.material_variantes v where v.material_id=m.id and v.club_id=m.club_id and v.activa)
          else coalesce(m.stock,0)*coalesce(m.precio,0) end),0)
      )
      from public.material_catalogo m where m.club_id=p_club_id and m.ciclo_estado='activo'
    )
  );
end $$;

create or replace function public.app_kombax_material_stock_movements_r89(
  p_club_id uuid,p_material_id uuid default null,p_limit integer default 10,p_offset integer default 0
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_limit integer:=least(50,greatest(1,coalesce(p_limit,10)));v_offset integer:=greatest(0,coalesce(p_offset,0));v_rows jsonb;v_count integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then raise exception 'MATERIAL_INVENTORY_FORBIDDEN'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb),count(*)
  into v_rows,v_count
  from (
    select m.id,m.material_id,c.nombre as material_name,m.variante_id,
      concat_ws(' · ',nullif(v.talla,''),nullif(v.color,'')) as variant_name,
      m.pedido_id,m.movement_type,m.quantity_delta,m.stock_before,m.stock_after,m.unit_cost,m.unit_sale,m.gross_margin,m.supplier,m.note,m.created_at
    from kombax_inventory.club_stock_movements_r89 m
    join public.material_catalogo c on c.id=m.material_id
    left join public.material_variantes v on v.id=m.variante_id
    where m.club_id=p_club_id and (p_material_id is null or m.material_id=p_material_id)
    order by m.created_at desc,m.id desc
    offset v_offset limit v_limit+1
  ) x;
  return jsonb_build_object(
    'items',case when v_count>v_limit then (select coalesce(jsonb_agg(value),'[]'::jsonb) from jsonb_array_elements(v_rows) with ordinality a(value,n) where n<=v_limit) else v_rows end,
    'has_more',v_count>v_limit,'next_offset',v_offset+least(v_count,v_limit)
  );
end $$;

create or replace function public.app_kombax_material_inventory_mutate_r89(
  p_operation text,p_payload jsonb,p_request_id uuid
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());v_op text:=lower(trim(coalesce(p_operation,'')));v_club uuid;v_material_id uuid;v_variant_id uuid;
  v_material public.material_catalogo;v_variant public.material_variantes;v_before integer;v_after integer;v_delta integer:=0;
  v_qty integer;v_cost numeric(12,2);v_sale numeric(12,2);v_old_cost numeric(12,2);v_new_cost numeric(12,2);v_supplier text;v_note text;
  v_key text;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  v_club:=nullif(p_payload->>'club_id','')::uuid;v_material_id:=nullif(p_payload->>'material_id','')::uuid;v_variant_id:=nullif(p_payload->>'variant_id','')::uuid;
  if v_club is null or v_material_id is null then raise exception 'MATERIAL_INVENTORY_IDS_REQUIRED'; end if;
  if not public.tiene_rol_club(v_club,'direccion','secretaria','economia') then raise exception 'MATERIAL_INVENTORY_FORBIDDEN'; end if;
  select * into strict v_material from public.material_catalogo where id=v_material_id and club_id=v_club for update;
  if v_variant_id is not null then select * into strict v_variant from public.material_variantes where id=v_variant_id and material_id=v_material_id and club_id=v_club for update; end if;
  v_supplier:=left(nullif(trim(p_payload->>'supplier'),''),200);v_note:=left(nullif(trim(p_payload->>'note'),''),500);
  v_key:=v_op||':'||v_uid::text||':'||p_request_id::text;
  if exists(select 1 from kombax_inventory.club_stock_movements_r89 where idempotency_key=v_key) then return jsonb_build_object('ok',true,'idempotent',true); end if;

  if v_op='pricing' then
    v_cost:=nullif(p_payload->>'unit_cost','')::numeric;v_sale:=nullif(p_payload->>'sale_price','')::numeric;
    if (v_cost is not null and v_cost<0) or (v_sale is not null and v_sale<0) then raise exception 'MATERIAL_PRICE_INVALID'; end if;
    if v_variant_id is null then
      update public.material_catalogo set
        precio_compra_medio=case when p_payload ? 'unit_cost' then v_cost else precio_compra_medio end,
        precio=case when p_payload ? 'sale_price' then coalesce(v_sale,0) else precio end,
        stock_minimo=case when p_payload ? 'minimum_stock' then nullif(p_payload->>'minimum_stock','')::integer else stock_minimo end,
        proveedor=case when p_payload ? 'supplier' then v_supplier else proveedor end
      where id=v_material_id;
      v_before:=coalesce(v_material.stock,0);v_cost:=coalesce(v_cost,v_material.precio_compra_medio);v_sale:=coalesce(v_sale,v_material.precio);
    else
      update public.material_variantes set
        precio_compra_medio=case when p_payload ? 'unit_cost' then v_cost else precio_compra_medio end,
        precio_venta=case when p_payload ? 'sale_price' then v_sale else precio_venta end,
        stock_minimo=case when p_payload ? 'minimum_stock' then nullif(p_payload->>'minimum_stock','')::integer else stock_minimo end,
        proveedor=case when p_payload ? 'supplier' then v_supplier else proveedor end
      where id=v_variant_id;
      v_before:=coalesce(v_variant.stock,0);v_cost:=coalesce(v_cost,v_variant.precio_compra_medio,v_material.precio_compra_medio);v_sale:=coalesce(v_sale,v_variant.precio_venta,v_material.precio);
    end if;
    insert into kombax_inventory.club_stock_movements_r89(club_id,material_id,variante_id,movement_type,quantity_delta,stock_before,stock_after,unit_cost,unit_sale,gross_margin,supplier,note,actor_user_id,idempotency_key)
    values(v_club,v_material_id,v_variant_id,'pricing',0,v_before,v_before,v_cost,v_sale,null,v_supplier,v_note,v_uid,v_key);
    return jsonb_build_object('ok',true,'operation',v_op,'stock',v_before);
  end if;

  if v_op='purchase' then
    v_qty:=greatest(1,coalesce(nullif(p_payload->>'quantity','')::integer,0));v_cost:=nullif(p_payload->>'unit_cost','')::numeric;
    if v_cost is null or v_cost<0 then raise exception 'MATERIAL_PURCHASE_COST_REQUIRED'; end if;
    if v_variant_id is null then
      v_before:=coalesce(v_material.stock,0);v_after:=v_before+v_qty;v_old_cost:=coalesce(v_material.precio_compra_medio,0);
      v_new_cost:=case when v_after>0 then round(((v_before*v_old_cost)+(v_qty*v_cost))/v_after,2) else v_cost end;
      update public.material_catalogo set stock=v_after,precio_compra_medio=v_new_cost,proveedor=coalesce(v_supplier,proveedor) where id=v_material_id;
      v_sale:=v_material.precio;
    else
      v_before:=coalesce(v_variant.stock,0);v_after:=v_before+v_qty;v_old_cost:=coalesce(v_variant.precio_compra_medio,v_material.precio_compra_medio,0);
      v_new_cost:=case when v_after>0 then round(((v_before*v_old_cost)+(v_qty*v_cost))/v_after,2) else v_cost end;
      update public.material_variantes set stock=v_after,precio_compra_medio=v_new_cost,proveedor=coalesce(v_supplier,proveedor) where id=v_variant_id;
      v_sale:=coalesce(v_variant.precio_venta,v_material.precio);
    end if;
    v_delta:=v_qty;
  elsif v_op in('manual_adjustment','internal_use','loss','return') then
    if v_op='manual_adjustment' then
      v_after:=greatest(0,coalesce(nullif(p_payload->>'new_stock','')::integer,-1));
      v_before:=case when v_variant_id is null then coalesce(v_material.stock,0) else coalesce(v_variant.stock,0) end;v_delta:=v_after-v_before;
    else
      v_qty:=greatest(1,coalesce(nullif(p_payload->>'quantity','')::integer,0));
      v_before:=case when v_variant_id is null then coalesce(v_material.stock,0) else coalesce(v_variant.stock,0) end;
      v_delta:=case when v_op in('internal_use','loss') then -v_qty else v_qty end;v_after:=v_before+v_delta;
      if v_after<0 then raise exception 'MATERIAL_STOCK_INSUFFICIENT'; end if;
    end if;
    if v_variant_id is null then update public.material_catalogo set stock=v_after where id=v_material_id;v_cost:=v_material.precio_compra_medio;v_sale:=v_material.precio;
    else update public.material_variantes set stock=v_after where id=v_variant_id;v_cost:=coalesce(v_variant.precio_compra_medio,v_material.precio_compra_medio);v_sale:=coalesce(v_variant.precio_venta,v_material.precio); end if;
  else raise exception 'MATERIAL_INVENTORY_OPERATION_INVALID'; end if;

  insert into kombax_inventory.club_stock_movements_r89(club_id,material_id,variante_id,movement_type,quantity_delta,stock_before,stock_after,unit_cost,unit_sale,gross_margin,supplier,note,actor_user_id,idempotency_key)
  values(v_club,v_material_id,v_variant_id,v_op,v_delta,v_before,v_after,coalesce(v_new_cost,v_cost),v_sale,
    case when v_op='sale' and v_cost is not null and v_sale is not null then (v_sale-v_cost)*abs(v_delta) else null end,
    v_supplier,v_note,v_uid,v_key);
  return jsonb_build_object('ok',true,'operation',v_op,'stock_before',v_before,'stock_after',v_after,'quantity_delta',v_delta,'unit_cost',coalesce(v_new_cost,v_cost));
end $$;

-- Existing material sale flow is upgraded to snapshot the effective cost and margin at validation time.
create or replace function public.app_solicitar_material_v025(
  p_club_id uuid,p_socio_id uuid,p_material_id uuid,p_variante_id uuid,p_cantidad integer default 1,p_observaciones text default null,p_validar_ahora boolean default false
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_socio public.socios;v_material public.material_catalogo;v_variante public.material_variantes;v_id uuid;v_staff boolean;v_result jsonb;v_price numeric;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  select * into v_socio from public.socios where club_id=p_club_id and id=p_socio_id;
  if v_socio.id is null then raise exception 'Alumno no encontrado'; end if;
  v_staff:=public.tiene_rol_club(p_club_id,'direccion','secretaria','economia');
  if not v_staff and not public.puede_aportar_pago_socio(p_socio_id) then raise exception 'No tienes acceso al alumno'; end if;
  if p_validar_ahora and not v_staff then raise exception 'El alumno no puede validar su propia retirada'; end if;
  if coalesce(p_cantidad,0)<=0 then raise exception 'La cantidad debe ser mayor que cero'; end if;
  select * into v_material from public.material_catalogo where club_id=p_club_id and id=p_material_id and activo and ciclo_estado='activo';
  if v_material.id is null then raise exception 'Material no disponible'; end if;
  v_price:=v_material.precio;
  if p_variante_id is not null then
    select * into v_variante from public.material_variantes where club_id=p_club_id and id=p_variante_id and material_id=p_material_id and activa;
    if v_variante.id is null then raise exception 'Variante no disponible'; end if;
    v_price:=coalesce(v_variante.precio_venta,v_material.precio);
  end if;
  insert into public.material_pedidos(club_id,socio_id,material_id,variante_id,cantidad,precio_unitario,importe_total,estado,observaciones,creado_por)
  values(p_club_id,p_socio_id,p_material_id,p_variante_id,p_cantidad,v_price,v_price*p_cantidad,'pendiente_validacion',nullif(trim(coalesce(p_observaciones,'')),''),v_uid)
  returning id into v_id;
  if p_validar_ahora then v_result:=public.app_validar_retirada_material_v025(v_id);
  else
    insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    select p_club_id,rol,'material-validar-'||v_id||'-'||rol::text,'material','Material pendiente de validar',
      trim(concat_ws(' ',v_socio.nombre,v_socio.apellidos))||' ha registrado '||p_cantidad||' × '||v_material.nombre||'.',
      'materials',jsonb_build_object('pedido_id',v_id,'estado','pendiente_validacion'),v_uid
    from unnest(array['direccion','secretaria','economia']::public.rol_club[]) rol;
    v_result:=jsonb_build_object('pedido_id',v_id,'estado','pendiente_validacion');
  end if;
  return v_result;
end $$;

create or replace function public.app_validar_retirada_material_v025(p_pedido_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid();v_pedido public.material_pedidos;v_material public.material_catalogo;v_variante public.material_variantes;
  v_cuota uuid;v_entrega uuid;v_perfil uuid;v_alumno text;v_concepto text;v_cost numeric;v_sale numeric;v_before integer;v_after integer;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  select * into v_pedido from public.material_pedidos where id=p_pedido_id for update;
  if v_pedido.id is null then raise exception 'Pedido no encontrado'; end if;
  if not public.tiene_rol_club(v_pedido.club_id,'direccion','secretaria','economia') then raise exception 'Solo el equipo autorizado puede validar una retirada'; end if;
  if v_pedido.estado in ('validado','entregado') and v_pedido.cuota_id is not null then return jsonb_build_object('pedido_id',v_pedido.id,'cuota_id',v_pedido.cuota_id,'estado','validado','repetida',true); end if;
  if v_pedido.estado not in ('reservado','pendiente_validacion','preparado') then raise exception 'El pedido no está pendiente de validación'; end if;
  select * into v_material from public.material_catalogo where club_id=v_pedido.club_id and id=v_pedido.material_id for update;
  if v_material.id is null then raise exception 'Material no encontrado'; end if;
  v_sale:=coalesce(v_pedido.precio_unitario,v_material.precio);
  if v_pedido.variante_id is not null then
    select * into v_variante from public.material_variantes where club_id=v_pedido.club_id and id=v_pedido.variante_id and material_id=v_pedido.material_id for update;
    if v_variante.id is null or not v_variante.activa then raise exception 'Variante no disponible'; end if;
    if v_variante.stock<v_pedido.cantidad then raise exception 'Stock insuficiente para validar la retirada'; end if;
    v_before:=v_variante.stock;v_after:=v_before-v_pedido.cantidad;v_cost:=coalesce(v_variante.precio_compra_medio,v_material.precio_compra_medio);
    update public.material_variantes set stock=v_after where id=v_variante.id;
  else
    if v_material.stock<v_pedido.cantidad then raise exception 'Stock insuficiente para validar la retirada'; end if;
    v_before:=v_material.stock;v_after:=v_before-v_pedido.cantidad;v_cost:=v_material.precio_compra_medio;
    update public.material_catalogo set stock=v_after where id=v_material.id;
  end if;
  update public.material_pedidos set coste_unitario_snapshot=v_cost,margen_unitario_snapshot=case when v_cost is null then null else v_sale-v_cost end,
    margen_total_snapshot=case when v_cost is null then null else (v_sale-v_cost)*cantidad end where id=v_pedido.id;
  insert into kombax_inventory.club_stock_movements_r89(club_id,material_id,variante_id,pedido_id,movement_type,quantity_delta,stock_before,stock_after,unit_cost,unit_sale,gross_margin,actor_user_id,idempotency_key,note)
  values(v_pedido.club_id,v_pedido.material_id,v_pedido.variante_id,v_pedido.id,'sale',-v_pedido.cantidad,v_before,v_after,v_cost,v_sale,
    case when v_cost is null then null else (v_sale-v_cost)*v_pedido.cantidad end,v_uid,'sale:'||v_pedido.id::text,'Retirada validada') on conflict(idempotency_key) do nothing;

  insert into public.material_entregas(club_id,socio_id,variante_id,material_id,cantidad,fecha,estado,registrado_por,pedido_id,importe_unitario,importe_total,validado_por,validado_en)
  values(v_pedido.club_id,v_pedido.socio_id,v_pedido.variante_id,v_pedido.material_id,v_pedido.cantidad,current_date,'entregado',v_uid,v_pedido.id,v_sale,v_pedido.importe_total,v_uid,now()) returning id into v_entrega;
  v_concepto:='Material: '||v_material.nombre;
  insert into public.cuotas(club_id,socio_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,origen,origen_id)
  values(v_pedido.club_id,v_pedido.socio_id,date_trunc('month',current_date)::date,v_concepto||' ['||left(v_pedido.id::text,8)||']',v_concepto,v_pedido.importe_total,current_date,'pendiente','material',v_pedido.id) returning id into v_cuota;
  update public.material_pedidos set estado='validado',validado_por=v_uid,validado_en=now(),cuota_id=v_cuota,actualizado_en=now() where id=v_pedido.id;
  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(concat_ws(' ',s.nombre,s.apellidos)) into v_perfil,v_alumno
  from public.socios s left join lateral(select ts.tutor_perfil_id from public.tutores_socios ts where ts.club_id=s.club_id and ts.socio_id=s.id and ts.contacto_principal order by ts.id limit 1)t on true
  where s.club_id=v_pedido.club_id and s.id=v_pedido.socio_id;
  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(v_pedido.club_id,v_perfil,'material-cargo-'||v_pedido.id,'aviso_cobro','Material pendiente',
      'Material pendiente: '||v_material.nombre||' — '||to_char(v_pedido.importe_total,'FM999999990.00')||' €.',
      'fees',jsonb_build_object('pedido_id',v_pedido.id,'cuota_id',v_cuota,'origen','material'),v_uid)
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return jsonb_build_object('pedido_id',v_pedido.id,'entrega_id',v_entrega,'cuota_id',v_cuota,'estado','validado','unit_cost',v_cost,'unit_sale',v_sale,'gross_margin',case when v_cost is null then null else (v_sale-v_cost)*v_pedido.cantidad end);
end $$;

create or replace function public.app_kombax_showcase_inventory_cost_r89(p_provider_id uuid,p_limit integer default 200)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_limit integer:=least(300,greatest(10,coalesce(p_limit,200)));
begin
 if v_uid is null or not kombax_payments.can_manage_provider(v_uid,p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
 return jsonb_build_object(
  'items',coalesce((select jsonb_agg(jsonb_build_object(
    'id',e.id,'nombre',e.nombre,'sku',e.sku,'stock',e.stock,'stock_minimo',e.stock_alert_threshold,'precio_compra_medio',e.precio_compra_medio,
    'precio_venta',e.precio_venta,'proveedor',e.proveedor_compra,'margen_unitario',case when e.precio_compra_medio is null or e.precio_venta is null then null else e.precio_venta-e.precio_compra_medio end,
    'valor_stock_coste',case when e.precio_compra_medio is null then null else coalesce(e.stock,0)*e.precio_compra_medio end,'valor_stock_venta',coalesce(e.stock,0)*coalesce(e.precio_venta,0)
  ) order by e.actualizado_en desc) from (select * from public.kombax_showcase_elementos where marca_id=p_provider_id and estado<>'retirado' order by actualizado_en desc limit v_limit)e),'[]'::jsonb),
  'summary',(select jsonb_build_object('models',count(*),'units',coalesce(sum(coalesce(e.stock,0)),0),
    'inventory_cost_minor',coalesce(sum(coalesce(e.stock,0)*coalesce(round(e.precio_compra_medio*100)::bigint,0)),0),
    'potential_sale_minor',coalesce(sum(coalesce(e.stock,0)*coalesce(round(e.precio_venta*100)::bigint,0)),0))
    from public.kombax_showcase_elementos e where e.marca_id=p_provider_id and e.estado<>'retirado')
 );
end $$;

create or replace function public.app_kombax_showcase_inventory_mutate_r89(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_op text:=lower(trim(coalesce(p_operation,'')));v_product_id uuid:=nullif(p_payload->>'product_id','')::uuid;
  v_item public.kombax_showcase_elementos;v_qty integer;v_before integer;v_after integer;v_delta integer;v_cost numeric;v_old_cost numeric;v_new_cost numeric;v_sale numeric;v_supplier text;v_note text;v_key text;
begin
 if v_uid is null or p_request_id is null or v_product_id is null then raise exception 'AUTH_REQUEST_PRODUCT_REQUIRED'; end if;
 select * into strict v_item from public.kombax_showcase_elementos where id=v_product_id for update;
 if not kombax_payments.can_manage_provider(v_uid,v_item.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
 v_key:='r89:'||v_op||':'||v_uid::text||':'||p_request_id::text;v_supplier:=left(nullif(trim(p_payload->>'supplier'),''),200);v_note:=left(nullif(trim(p_payload->>'note'),''),500);
 if exists(select 1 from kombax_payments.showcase_stock_movements_r65 where idempotency_key=v_key) then return jsonb_build_object('ok',true,'idempotent',true); end if;
 if v_op='pricing' then
   v_cost:=nullif(p_payload->>'unit_cost','')::numeric;v_sale:=nullif(p_payload->>'sale_price','')::numeric;
   if (v_cost is not null and v_cost<0) or (v_sale is not null and v_sale<0) then raise exception 'SHOWCASE_PRICE_INVALID'; end if;
   update public.kombax_showcase_elementos set precio_compra_medio=case when p_payload ? 'unit_cost' then v_cost else precio_compra_medio end,
     precio_venta=case when p_payload ? 'sale_price' then v_sale else precio_venta end,
     stock_alert_threshold=case when p_payload ? 'minimum_stock' then nullif(p_payload->>'minimum_stock','')::integer else stock_alert_threshold end,
     proveedor_compra=case when p_payload ? 'supplier' then v_supplier else proveedor_compra end,actualizado_en=now(),actualizado_por=v_uid where id=v_product_id;
   insert into kombax_payments.showcase_stock_movements_r65(provider_id,product_id,movement_type,quantity_delta,stock_before,stock_after,actor_user_id,note,idempotency_key,unit_cost_minor,unit_sale_minor,gross_margin_minor)
   values(v_item.marca_id,v_product_id,'manual_adjustment',0,coalesce(v_item.stock,0),coalesce(v_item.stock,0),v_uid,coalesce(v_note,'Actualización de costes/precios'),v_key,
     case when v_cost is null then null else round(v_cost*100)::integer end,case when v_sale is null then null else round(v_sale*100)::integer end,null);
   return jsonb_build_object('ok',true,'operation',v_op);
 elsif v_op='purchase' then
   v_qty:=greatest(1,coalesce(nullif(p_payload->>'quantity','')::integer,0));v_cost:=nullif(p_payload->>'unit_cost','')::numeric;if v_cost is null or v_cost<0 then raise exception 'SHOWCASE_PURCHASE_COST_REQUIRED'; end if;
   v_before:=coalesce(v_item.stock,0);v_after:=v_before+v_qty;v_old_cost:=coalesce(v_item.precio_compra_medio,0);v_new_cost:=round(((v_before*v_old_cost)+(v_qty*v_cost))/greatest(v_after,1),2);
   update public.kombax_showcase_elementos set stock=v_after,precio_compra_medio=v_new_cost,proveedor_compra=coalesce(v_supplier,proveedor_compra),actualizado_en=now(),actualizado_por=v_uid where id=v_product_id;
   v_delta:=v_qty;v_sale:=v_item.precio_venta;
 elsif v_op in('manual_adjustment','internal_use','loss','return') then
   v_before:=coalesce(v_item.stock,0);
   if v_op='manual_adjustment' then v_after:=greatest(0,coalesce(nullif(p_payload->>'new_stock','')::integer,-1));v_delta:=v_after-v_before;
   else v_qty:=greatest(1,coalesce(nullif(p_payload->>'quantity','')::integer,0));v_delta:=case when v_op in('internal_use','loss') then -v_qty else v_qty end;v_after:=v_before+v_delta;if v_after<0 then raise exception 'SHOWCASE_STOCK_INSUFFICIENT';end if;end if;
   update public.kombax_showcase_elementos set stock=v_after,actualizado_en=now(),actualizado_por=v_uid where id=v_product_id;v_cost:=v_item.precio_compra_medio;v_sale:=v_item.precio_venta;
 else raise exception 'SHOWCASE_INVENTORY_OPERATION_INVALID'; end if;
 insert into kombax_payments.showcase_stock_movements_r65(provider_id,product_id,movement_type,quantity_delta,stock_before,stock_after,actor_user_id,note,idempotency_key,unit_cost_minor,unit_sale_minor,gross_margin_minor)
 values(v_item.marca_id,v_product_id,case when v_op='purchase' then 'purchase' else v_op end,v_delta,v_before,v_after,v_uid,v_note,v_key,
   case when coalesce(v_new_cost,v_cost) is null then null else round(coalesce(v_new_cost,v_cost)*100)::integer end,
   case when v_sale is null then null else round(v_sale*100)::integer end,null);
 return jsonb_build_object('ok',true,'operation',v_op,'stock_before',v_before,'stock_after',v_after,'quantity_delta',v_delta,'unit_cost',coalesce(v_new_cost,v_cost));
end $$;

create or replace function public.app_kombax_inventory_finance_r89(p_subject_type text,p_subject_id uuid,p_limit integer default 10,p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_limit integer:=least(50,greatest(1,coalesce(p_limit,10)));v_offset integer:=greatest(0,coalesce(p_offset,0));v_items jsonb:='[]'::jsonb;v_summary jsonb:='{}'::jsonb;v_moves jsonb:='[]'::jsonb;v_count integer:=0;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_subject_type not in('club','showcase_provider') or not kombax_payments.can_access_subject_r80(v_uid,p_subject_type,p_subject_id,false) then raise exception 'INVENTORY_FINANCE_FORBIDDEN'; end if;
 if p_subject_type='club' then
   select coalesce(jsonb_agg(to_jsonb(x) order by x.nombre),'[]'::jsonb) into v_items from (
     select m.id,m.nombre,m.stock,m.precio_compra_medio,m.precio as precio_venta,case when m.precio_compra_medio is null then null else m.precio-m.precio_compra_medio end margen_unitario,
       coalesce(m.stock,0)*coalesce(m.precio_compra_medio,0) valor_coste,coalesce(m.stock,0)*coalesce(m.precio,0) valor_venta
     from public.material_catalogo m where m.club_id=p_subject_id and m.ciclo_estado='activo' order by m.nombre limit 100)x;
   select jsonb_build_object(
     'units',coalesce(sum(coalesce(m.stock,0)),0),
     'inventory_cost_minor',coalesce(sum(coalesce(m.stock,0)*coalesce(round(m.precio_compra_medio*100)::bigint,0)),0),
     'potential_sale_minor',coalesce(sum(coalesce(m.stock,0)*coalesce(round(m.precio*100)::bigint,0)),0),
     'purchases_minor',coalesce((select sum(abs(quantity_delta)*round(unit_cost*100)::bigint) from kombax_inventory.club_stock_movements_r89 where club_id=p_subject_id and movement_type='purchase' and unit_cost is not null),0),
     'sales_minor',coalesce((select sum(abs(quantity_delta)*round(unit_sale*100)::bigint) from kombax_inventory.club_stock_movements_r89 where club_id=p_subject_id and movement_type='sale' and unit_sale is not null),0),
     'realized_margin_minor',coalesce((select sum(round(gross_margin*100)::bigint) from kombax_inventory.club_stock_movements_r89 where club_id=p_subject_id and movement_type='sale' and gross_margin is not null),0),
     'loss_cost_minor',coalesce((select sum(abs(quantity_delta)*round(unit_cost*100)::bigint) from kombax_inventory.club_stock_movements_r89 where club_id=p_subject_id and movement_type='loss' and unit_cost is not null),0)
   ) into v_summary from public.material_catalogo m where m.club_id=p_subject_id and m.ciclo_estado='activo';
   select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb),count(*) into v_moves,v_count from (
     select m.id,m.movement_type,m.quantity_delta,m.unit_cost,m.unit_sale,m.gross_margin,m.created_at,c.nombre as item_name
     from kombax_inventory.club_stock_movements_r89 m join public.material_catalogo c on c.id=m.material_id
     where m.club_id=p_subject_id order by m.created_at desc,m.id desc offset v_offset limit v_limit+1)x;
 else
   select coalesce(jsonb_agg(to_jsonb(x) order by x.nombre),'[]'::jsonb) into v_items from (
     select e.id,e.nombre,e.stock,e.precio_compra_medio,e.precio_venta,case when e.precio_compra_medio is null or e.precio_venta is null then null else e.precio_venta-e.precio_compra_medio end margen_unitario,
       coalesce(e.stock,0)*coalesce(e.precio_compra_medio,0) valor_coste,coalesce(e.stock,0)*coalesce(e.precio_venta,0) valor_venta
     from public.kombax_showcase_elementos e where e.marca_id=p_subject_id and e.estado<>'retirado' order by e.nombre limit 100)x;
   select jsonb_build_object(
     'units',coalesce(sum(coalesce(e.stock,0)),0),
     'inventory_cost_minor',coalesce(sum(coalesce(e.stock,0)*coalesce(round(e.precio_compra_medio*100)::bigint,0)),0),
     'potential_sale_minor',coalesce(sum(coalesce(e.stock,0)*coalesce(round(e.precio_venta*100)::bigint,0)),0),
     'purchases_minor',coalesce((select sum(abs(quantity_delta)*coalesce(unit_cost_minor,0)) from kombax_payments.showcase_stock_movements_r65 where provider_id=p_subject_id and movement_type='purchase'),0),
     'sales_minor',coalesce((select sum(abs(quantity_delta)*coalesce(unit_sale_minor,0)) from kombax_payments.showcase_stock_movements_r65 where provider_id=p_subject_id and movement_type='sale'),0),
     'realized_margin_minor',coalesce((select sum(coalesce(gross_margin_minor,0)) from kombax_payments.showcase_stock_movements_r65 where provider_id=p_subject_id and movement_type='sale'),0),
     'loss_cost_minor',coalesce((select sum(abs(quantity_delta)*coalesce(unit_cost_minor,0)) from kombax_payments.showcase_stock_movements_r65 where provider_id=p_subject_id and movement_type='loss'),0)
   ) into v_summary from public.kombax_showcase_elementos e where e.marca_id=p_subject_id and e.estado<>'retirado';
   select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb),count(*) into v_moves,v_count from (
     select m.id,m.movement_type,m.quantity_delta,m.unit_cost_minor,m.unit_sale_minor,m.gross_margin_minor,m.created_at,e.nombre as item_name
     from kombax_payments.showcase_stock_movements_r65 m join public.kombax_showcase_elementos e on e.id=m.product_id
     where m.provider_id=p_subject_id order by m.created_at desc,m.id desc offset v_offset limit v_limit+1)x;
 end if;
 return jsonb_build_object('summary',v_summary,'items',v_items,
   'movements',case when v_count>v_limit then (select coalesce(jsonb_agg(value),'[]'::jsonb) from jsonb_array_elements(v_moves) with ordinality a(value,n) where n<=v_limit) else v_moves end,
   'has_more',v_count>v_limit,'next_offset',v_offset+least(v_count,v_limit));
end $$;

create or replace function public.app_evento_comunicaciones_r89(p_evento_id uuid,p_limit integer default 10,p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_event public.eventos_competicion;v_limit integer:=least(50,greatest(1,coalesce(p_limit,10)));v_offset integer:=greatest(0,coalesce(p_offset,0));v_rows jsonb;v_count integer;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into strict v_event from public.eventos_competicion where id=p_evento_id;
 if not public.app_puede_gestionar_eventos_v033(v_event.club_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb),count(*) into v_rows,v_count from (
   select c.id,c.titulo,c.cuerpo,c.tipo,c.audiencia,c.estado,c.publicada_en,c.programada_para,c.creado_en as created_at,c.evento_fecha,c.ubicacion
   from public.comunicaciones c where c.club_id=v_event.club_id and c.subject_type='club_event' and c.subject_id=p_evento_id and c.ciclo_estado<>'papelera'
   order by c.creado_en desc,c.id desc offset v_offset limit v_limit+1)x;
 return jsonb_build_object('items',case when v_count>v_limit then (select coalesce(jsonb_agg(value),'[]'::jsonb) from jsonb_array_elements(v_rows) with ordinality a(value,n) where n<=v_limit) else v_rows end,
   'has_more',v_count>v_limit,'next_offset',v_offset+least(v_count,v_limit));
end $$;

create or replace function public.app_evento_comunicacion_vincular_r89(p_evento_id uuid,p_comunicacion_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_event public.eventos_competicion;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into strict v_event from public.eventos_competicion where id=p_evento_id;
 if not public.app_puede_gestionar_eventos_v033(v_event.club_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
 update public.comunicaciones set subject_type='club_event',subject_id=p_evento_id where id=p_comunicacion_id and club_id=v_event.club_id;
 if not found then raise exception 'COMMUNICATION_NOT_FOUND'; end if;
 return jsonb_build_object('ok',true,'event_id',p_evento_id,'communication_id',p_comunicacion_id);
end $$;

create or replace function public.app_ciclo_listar_page_r89(
 p_club_id uuid,p_tipo text default null,p_estado text default null,p_desde date default null,p_hasta date default null,p_limit integer default 10,p_offset integer default 0
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_limit integer:=least(50,greatest(1,coalesce(p_limit,10)));v_offset integer:=greatest(0,coalesce(p_offset,0));v_rows jsonb;v_count integer;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.app_puede_gestionar_ciclo_v038(p_club_id) then raise exception 'LIFECYCLE_FORBIDDEN'; end if;
 with recursos(recurso_tipo,id,club_id,ciclo_estado,titulo,resumen,fecha,restaurar_hasta) as (
   select 'publicacion'::text,id,club_id,ciclo_estado,left(coalesce(autor_nombre,'Publicación'),160),left(coalesce(texto,''),260),creado_en,restaurar_hasta from public.publicaciones_comunidad
   union all select 'comunicacion',id,club_id,ciclo_estado,left(titulo,160),left(cuerpo,260),creado_en,restaurar_hasta from public.comunicaciones
   union all select 'evento',id,club_id,ciclo_estado,left(nombre,160),left(coalesce(descripcion,''),260),coalesce(fecha::timestamptz,creado_en),restaurar_hasta from public.eventos_competicion
   union all select 'notificacion',id,club_id,ciclo_estado,left(titulo,160),left(cuerpo,260),creado_en,restaurar_hasta from public.notificaciones
   union all select 'material',id,club_id,ciclo_estado,left(nombre,160),left(coalesce(descripcion,''),260),null::timestamptz,restaurar_hasta from public.material_catalogo
   union all select 'documento',id,club_id,ciclo_estado,left(nombre,160),tipo,creado_en,restaurar_hasta from public.documentos_socios
   union all select 'seguimiento',id,club_id,ciclo_estado,left(tipo,160),left(nota,260),coalesce(fecha::timestamptz,creado_en),restaurar_hasta from public.seguimiento
   union all select 'asistencia',id,club_id,ciclo_estado,'Asistencia',left(coalesce(observacion,estado::text),260),registrado_en,restaurar_hasta from public.asistencias
   union all select 'sesion',id,club_id,ciclo_estado,'Sesión '||fecha::text,left(coalesce(monitor_nombre,estado),260),coalesce(fecha::timestamptz,creado_en),restaurar_hasta from public.sesiones_entrenamiento
 ), filtered as (
   select r.recurso_tipo,r.id as recurso_id,r.ciclo_estado,r.titulo,r.resumen,r.fecha,r.restaurar_hasta from recursos r where r.club_id=p_club_id
     and (nullif(p_tipo,'') is null or r.recurso_tipo=p_tipo) and (nullif(p_estado,'') is null or r.ciclo_estado=p_estado)
     and (p_desde is null or r.fecha::date>=p_desde) and (p_hasta is null or r.fecha::date<=p_hasta)
   order by r.fecha desc nulls last,r.id desc offset v_offset limit v_limit+1
 )
 select coalesce(jsonb_agg(to_jsonb(filtered) order by fecha desc nulls last,recurso_id desc),'[]'::jsonb),count(*) into v_rows,v_count from filtered;
 return jsonb_build_object('items',case when v_count>v_limit then (select coalesce(jsonb_agg(value),'[]'::jsonb) from jsonb_array_elements(v_rows) with ordinality a(value,n) where n<=v_limit) else v_rows end,
   'has_more',v_count>v_limit,'next_offset',v_offset+least(v_count,v_limit));
end $$;

create or replace function public.app_ciclo_eliminar_preview_r89(p_club_id uuid,p_recurso_tipo text,p_recurso_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_base jsonb;v_connections integer:=0;v_messages integer:=0;v_participants integer:=0;v_fights integer:=0;v_reason text;
begin
 v_base:=public.app_ciclo_eliminar_preview_v133(p_club_id,p_recurso_tipo,p_recurso_id);
 if p_recurso_tipo='evento' then
   select count(*) into v_connections from public.kombax_event_connections_v220 where internal_event_id=p_recurso_id;
   select count(*) into v_messages from public.comunicaciones where club_id=p_club_id and subject_type='club_event' and subject_id=p_recurso_id;
   v_participants:=coalesce((v_base#>>'{dependencies,participantes}')::integer,0);v_fights:=coalesce((v_base#>>'{dependencies,combates}')::integer,0);
   v_base:=jsonb_set(v_base,'{dependencies,conexiones_events}',to_jsonb(v_connections),true);
   v_base:=jsonb_set(v_base,'{dependencies,comunicaciones_evento}',to_jsonb(v_messages),true);
   if v_participants>0 or v_fights>0 or v_connections>0 or v_messages>0 then
     v_reason:='El evento conserva historial operativo (participantes, combates, comunicaciones o conexión con KOMBAX Events). Archívalo para retirarlo de la operativa sin perder trazabilidad.';
     v_base:=jsonb_set(v_base,'{allowed}','false'::jsonb,true);v_base:=jsonb_set(v_base,'{reason}',to_jsonb(v_reason),true);
   end if;
 end if;
 return v_base;
end $$;

create or replace function public.app_ciclo_eliminar_definitivo_r89(p_club_id uuid,p_recurso_tipo text,p_recurso_id uuid,p_confirmacion text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_plan jsonb;
begin
 v_plan:=public.app_ciclo_eliminar_preview_r89(p_club_id,p_recurso_tipo,p_recurso_id);
 if coalesce((v_plan->>'allowed')::boolean,false) is not true then raise exception 'LIFECYCLE_DELETE_NOT_ALLOWED:%',coalesce(v_plan->>'reason',''); end if;
 return public.app_ciclo_eliminar_definitivo_v133(p_club_id,p_recurso_tipo,p_recurso_id,p_confirmacion);
end $$;

revoke all on function public.app_kombax_material_inventory_r89(uuid,integer) from public,anon;
grant execute on function public.app_kombax_material_inventory_r89(uuid,integer) to authenticated;
revoke all on function public.app_kombax_material_stock_movements_r89(uuid,uuid,integer,integer) from public,anon;
grant execute on function public.app_kombax_material_stock_movements_r89(uuid,uuid,integer,integer) to authenticated;
revoke all on function public.app_kombax_material_inventory_mutate_r89(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_material_inventory_mutate_r89(text,jsonb,uuid) to authenticated;
revoke all on function public.app_kombax_showcase_inventory_cost_r89(uuid,integer) from public,anon;
grant execute on function public.app_kombax_showcase_inventory_cost_r89(uuid,integer) to authenticated;
revoke all on function public.app_kombax_showcase_inventory_mutate_r89(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_showcase_inventory_mutate_r89(text,jsonb,uuid) to authenticated;
revoke all on function public.app_kombax_inventory_finance_r89(text,uuid,integer,integer) from public,anon;
grant execute on function public.app_kombax_inventory_finance_r89(text,uuid,integer,integer) to authenticated;
revoke all on function public.app_evento_comunicaciones_r89(uuid,integer,integer) from public,anon;
grant execute on function public.app_evento_comunicaciones_r89(uuid,integer,integer) to authenticated;
revoke all on function public.app_evento_comunicacion_vincular_r89(uuid,uuid) from public,anon;
grant execute on function public.app_evento_comunicacion_vincular_r89(uuid,uuid) to authenticated;
revoke all on function public.app_ciclo_listar_page_r89(uuid,text,text,date,date,integer,integer) from public,anon;
grant execute on function public.app_ciclo_listar_page_r89(uuid,text,text,date,date,integer,integer) to authenticated;
revoke all on function public.app_ciclo_eliminar_preview_r89(uuid,text,uuid) from public,anon;
grant execute on function public.app_ciclo_eliminar_preview_r89(uuid,text,uuid) to authenticated;
revoke all on function public.app_ciclo_eliminar_definitivo_r89(uuid,text,uuid,text) from public,anon;
grant execute on function public.app_ciclo_eliminar_definitivo_r89(uuid,text,uuid,text) to authenticated;

notify pgrst,'reload schema';
commit;
