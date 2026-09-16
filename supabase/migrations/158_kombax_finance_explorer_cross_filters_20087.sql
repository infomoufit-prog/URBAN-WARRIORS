-- KOMBAX RC13 build 20087 · Explorer respects dashboard cross-filters.
drop function if exists public.app_finance_v2_explorer_v155(uuid,text,text,text,text,integer,integer);

create or replace function public.app_finance_v2_explorer_v155(
  p_club_id uuid,p_kind text,p_query text default null,p_status text default null,p_scope text default 'active',
  p_limit integer default 20,p_offset integer default 0,p_filters jsonb default '{}'::jsonb
) returns jsonb language plpgsql stable security definer set search_path=''
as $function$
declare
  v_kind text:=lower(trim(coalesce(p_kind,'')));v_scope text:=lower(trim(coalesce(p_scope,'active')));v_q text:=nullif(trim(coalesce(p_query,'')),'');v_status text:=nullif(trim(coalesce(p_status,'')),'');v_limit int:=least(50,greatest(5,coalesce(p_limit,20)));v_offset int:=greatest(0,coalesce(p_offset,0));v_rows jsonb:='[]'::jsonb;v_total int:=0;
  f jsonb:=coalesce(p_filters,'{}'::jsonb);f_year int;f_month int;f_socio uuid;f_group uuid;f_disc uuid;f_cat text;f_state text;f_method text;f_aging text;v_today date:=current_date;
begin
  if auth.uid() is null or not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then raise exception 'FINANCE_EXPLORER_FORBIDDEN'; end if;
  if v_kind not in ('cuotas','pagos','recibos','informes') then raise exception 'FINANCE_EXPLORER_KIND_INVALID'; end if;
  if v_scope not in ('active','archived','trash','all') then raise exception 'FINANCE_EXPLORER_SCOPE_INVALID'; end if;
  begin f_year:=nullif(f->>'year','')::int;f_month:=nullif(f->>'month','')::int;f_socio:=nullif(f->>'socio','')::uuid;f_group:=nullif(f->>'grupo','')::uuid;f_disc:=nullif(f->>'disciplina','')::uuid;exception when others then raise exception 'FINANCE_EXPLORER_FILTER_INVALID';end;
  f_cat:=nullif(f->>'categoria','');f_state:=nullif(f->>'estado','');f_method:=nullif(f->>'metodo','');f_aging:=nullif(f->>'aging','');

  if v_kind='pagos' then
    with base as (
      select p.*,s.nombre socio_nombre,s.apellidos socio_apellidos,q.concepto cuota_concepto,q.importe cuota_importe,q.estado cuota_estado,coalesce(x.valid_sum,0)::numeric(12,2) valid_sum,greatest(q.importe-coalesce(x.valid_sum,0),0)::numeric(12,2) saldo_restante,coalesce(l.estado,'active') lifecycle_estado,
        case when p.estado_validacion<>'pendiente' then false when coalesce(x.valid_sum,0)>=q.importe then false when p.importe>greatest(q.importe-coalesce(x.valid_sum,0),0) then false else true end can_validate,
        case when p.estado_validacion<>'pendiente' then null when coalesce(x.valid_sum,0)>=q.importe then 'La cuota ya está completamente pagada.' when p.importe>greatest(q.importe-coalesce(x.valid_sum,0),0) then 'El pago supera el saldo pendiente de la cuota.' else null end validation_block_reason,
        case when q.estado in ('anulada','exenta','pagada') or greatest(q.importe-coalesce(x.valid_sum,0),0)<=0 then 'cerrado' when q.vencimiento>=v_today then 'sin_vencer' when v_today-q.vencimiento between 1 and 15 then '1_15' when v_today-q.vencimiento between 16 and 30 then '16_30' when v_today-q.vencimiento between 31 and 60 then '31_60' else '60_plus' end aging_calc
      from public.pagos p join public.cuotas q on q.club_id=p.club_id and q.id=p.cuota_id join public.socios s on s.club_id=p.club_id and s.id=p.socio_id
      left join lateral(select coalesce(sum(p2.importe) filter(where p2.estado_validacion='validado'),0) valid_sum from public.pagos p2 where p2.club_id=p.club_id and p2.cuota_id=p.cuota_id) x on true
      left join public.finance_document_lifecycle_v155 l on l.club_id=p.club_id and l.entity_type='pago' and l.entity_id=p.id
      where p.club_id=p_club_id and ((v_scope='all' and coalesce(l.estado,'active')<>'trash') or (v_scope<>'all' and coalesce(l.estado,'active')=v_scope))
        and (v_status is null or p.estado_validacion::text=v_status)
        and (v_q is null or concat_ws(' ',s.nombre,s.apellidos,p.metodo,p.referencia,q.concepto) ilike '%'||v_q||'%')
        and (f_year is null or extract(year from q.periodo)::int=f_year) and (f_month is null or extract(month from q.periodo)::int=f_month) and (f_socio is null or q.socio_id=f_socio)
        and (f_cat is null or coalesce(q.categoria_financiera,case when q.origen='material' then 'material' when q.origen='cuota' then 'cuota' else 'otro' end)=f_cat)
        and (f_method is null or p.metodo::text=f_method)
        and (f_state is null or q.estado::text=f_state or (f_state='pendiente_abierto' and q.estado::text not in ('pagada','anulada','exenta') and greatest(q.importe-coalesce(x.valid_sum,0),0)>0) or (f_state='vencido_abierto' and q.estado::text not in ('pagada','anulada','exenta') and q.vencimiento<v_today and greatest(q.importe-coalesce(x.valid_sum,0),0)>0) or (f_state='cobrado' and coalesce(x.valid_sum,0)>0))
        and (f_group is null or exists(select 1 from public.socio_disciplinas sd where sd.club_id=q.club_id and sd.socio_id=q.socio_id and sd.grupo_id=f_group and sd.activa))
        and (f_disc is null or exists(select 1 from public.socio_disciplinas sd where sd.club_id=q.club_id and sd.socio_id=q.socio_id and sd.disciplina_id=f_disc and sd.activa))
    ), filtered as (select * from base where f_aging is null or aging_calc=f_aging)
    select count(*),coalesce((select jsonb_agg(to_jsonb(z) order by z.creado_en desc,z.id desc) from (select * from filtered order by creado_en desc,id desc limit v_limit offset v_offset) z),'[]'::jsonb) into v_total,v_rows from filtered;
  elsif v_kind='recibos' then
    with base as (
      select r.*,coalesce(l.estado,'active') lifecycle_estado,q.estado cuota_estado,q.vencimiento,
        case when q.estado in ('anulada','exenta','pagada') then 'cerrado' when q.vencimiento>=v_today then 'sin_vencer' when v_today-q.vencimiento between 1 and 15 then '1_15' when v_today-q.vencimiento between 16 and 30 then '16_30' when v_today-q.vencimiento between 31 and 60 then '31_60' else '60_plus' end aging_calc
      from public.recibos_cuota r join public.cuotas q on q.club_id=r.club_id and q.id=r.cuota_id
      left join public.finance_document_lifecycle_v155 l on l.club_id=r.club_id and l.entity_type='recibo' and l.entity_id=r.id
      where r.club_id=p_club_id and ((v_scope='all' and coalesce(l.estado,'active')<>'trash') or (v_scope<>'all' and coalesce(l.estado,'active')=v_scope))
        and (v_status is null or (v_status='anulado' and r.anulado_en is not null) or (v_status='activo' and r.anulado_en is null))
        and (v_q is null or concat_ws(' ',r.numero,r.socio_nombre,r.concepto,r.periodo::text,r.metodo) ilike '%'||v_q||'%')
        and (f_year is null or extract(year from q.periodo)::int=f_year) and (f_month is null or extract(month from q.periodo)::int=f_month) and (f_socio is null or q.socio_id=f_socio)
        and (f_cat is null or coalesce(q.categoria_financiera,case when q.origen='material' then 'material' when q.origen='cuota' then 'cuota' else 'otro' end)=f_cat)
        and (f_method is null or r.metodo=f_method)
        and (f_group is null or exists(select 1 from public.socio_disciplinas sd where sd.club_id=q.club_id and sd.socio_id=q.socio_id and sd.grupo_id=f_group and sd.activa))
        and (f_disc is null or exists(select 1 from public.socio_disciplinas sd where sd.club_id=q.club_id and sd.socio_id=q.socio_id and sd.disciplina_id=f_disc and sd.activa))
    ), filtered as (select * from base where f_aging is null or aging_calc=f_aging)
    select count(*),coalesce((select jsonb_agg(to_jsonb(z) order by z.emitido_en desc,z.id desc) from (select * from filtered order by emitido_en desc,id desc limit v_limit offset v_offset) z),'[]'::jsonb) into v_total,v_rows from filtered;
  elsif v_kind='informes' then
    with base as (
      select i.*,coalesce(l.estado,'active') lifecycle_estado from public.informes_financieros i left join public.finance_document_lifecycle_v155 l on l.club_id=i.club_id and l.entity_type='informe' and l.entity_id=i.id
      where i.club_id=p_club_id and ((v_scope='all' and coalesce(l.estado,'active')<>'trash') or (v_scope<>'all' and coalesce(l.estado,'active')=v_scope)) and (v_status is null or (v_status='pdf_ready' and i.archivo_path is not null) or (v_status='pdf_pending' and i.archivo_path is null) or i.tipo=v_status) and (v_q is null or concat_ws(' ',i.identificador,i.titulo,i.tipo) ilike '%'||v_q||'%')
    ) select count(*),coalesce((select jsonb_agg(to_jsonb(z) order by z.generado_en desc,z.id desc) from (select * from base order by generado_en desc,id desc limit v_limit offset v_offset) z),'[]'::jsonb) into v_total,v_rows from base;
  else
    with base as (
      select q.*,s.nombre socio_nombre,s.apellidos socio_apellidos,coalesce(x.valid_sum,0)::numeric(12,2) pagado_validado,greatest(q.importe-coalesce(x.valid_sum,0),0)::numeric(12,2) saldo,coalesce(l.estado,'active') lifecycle_estado
      from public.cuotas q join public.socios s on s.club_id=q.club_id and s.id=q.socio_id left join lateral(select coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0) valid_sum from public.pagos p where p.club_id=q.club_id and p.cuota_id=q.id) x on true left join public.finance_document_lifecycle_v155 l on l.club_id=q.club_id and l.entity_type='cuota' and l.entity_id=q.id
      where q.club_id=p_club_id and ((v_scope='all' and coalesce(l.estado,'active')<>'trash') or (v_scope<>'all' and coalesce(l.estado,'active')=v_scope)) and (v_status is null or q.estado::text=v_status) and (v_q is null or concat_ws(' ',s.nombre,s.apellidos,q.concepto,q.concepto_publico,q.periodo::text) ilike '%'||v_q||'%')
    ) select count(*),coalesce((select jsonb_agg(to_jsonb(z) order by z.creado_en desc,z.id desc) from (select * from base order by creado_en desc,id desc limit v_limit offset v_offset) z),'[]'::jsonb) into v_total,v_rows from base;
  end if;
  return jsonb_build_object('kind',v_kind,'scope',v_scope,'query',coalesce(v_q,''),'status',coalesce(v_status,''),'limit',v_limit,'offset',v_offset,'total',v_total,'rows',v_rows,'has_more',v_offset+v_limit<v_total,'filters',f);
end $function$;
revoke all on function public.app_finance_v2_explorer_v155(uuid,text,text,text,text,integer,integer,jsonb) from public,anon;
grant execute on function public.app_finance_v2_explorer_v155(uuid,text,text,text,text,integer,integer,jsonb) to authenticated;
