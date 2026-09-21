-- KOMBAX RC13 build 20085 · Finanzas Premium · visual analytics + drill-down data
-- Depends on 144 and remains read-only/additive. No payment, charge or receipt history is modified.

begin;

do $$
begin
  if to_regprocedure('public.app_finance_v2_dashboard_v144(uuid,integer,integer,uuid,uuid,uuid,text,text,uuid,text,text,integer,integer)') is null then
    raise exception 'FINANCE_VISUAL_150_REQUIRES_144';
  end if;
end
$$;

create or replace function public.app_finance_v2_dashboard_v150(
  p_club_id uuid,
  p_anio integer default null,
  p_mes integer default null,
  p_socio_id uuid default null,
  p_grupo_id uuid default null,
  p_disciplina_id uuid default null,
  p_categoria text default null,
  p_estado text default null,
  p_regla_id uuid default null,
  p_metodo text default null,
  p_antiguedad text default null,
  p_limit integer default 250,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_base jsonb;
  v_categories jsonb:='[]'::jsonb;
  v_groups jsonb:='[]'::jsonb;
  v_disciplines jsonb:='[]'::jsonb;
  v_forecast numeric(14,2):=0;
  v_overdue numeric(14,2):=0;
  v_pending numeric(14,2):=0;
  v_morosidad numeric(8,2):=0;
  v_today date:=current_date;
begin
  if auth.uid() is null or not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then
    raise exception 'FINANCE_V2_DASHBOARD_FORBIDDEN';
  end if;

  v_base:=public.app_finance_v2_dashboard_v144(
    p_club_id,p_anio,p_mes,p_socio_id,p_grupo_id,p_disciplina_id,p_categoria,p_estado,
    p_regla_id,p_metodo,p_antiguedad,p_limit,p_offset
  );

  with base as (
    select
      q.club_id,q.id as cuota_id,q.socio_id,q.periodo,q.importe,q.vencimiento,q.estado,q.regla_cobro_id,
      coalesce(q.categoria_financiera,
        case when q.origen='material' then 'material' when q.origen='cuota' then 'cuota' else 'otro' end) as categoria,
      coalesce(pa.pagado_validado,0)::numeric(12,2) as pagado_validado,
      greatest(q.importe-coalesce(pa.pagado_validado,0),0)::numeric(12,2) as saldo,
      pa.ultimo_metodo_pago,
      case
        when q.estado in ('anulada','exenta','pagada') or greatest(q.importe-coalesce(pa.pagado_validado,0),0)<=0 then 'cerrado'
        when q.vencimiento>=v_today then 'sin_vencer'
        when v_today-q.vencimiento between 1 and 15 then '1_15'
        when v_today-q.vencimiento between 16 and 30 then '16_30'
        when v_today-q.vencimiento between 31 and 60 then '31_60'
        else '60_plus' end as antiguedad
    from public.cuotas q
    left join lateral (
      select
        coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0) as pagado_validado,
        (array_agg(p.metodo order by p.fecha desc,p.creado_en desc) filter(where p.estado_validacion='validado'))[1] as ultimo_metodo_pago
      from public.pagos p where p.club_id=q.club_id and p.cuota_id=q.id
    ) pa on true
    where q.club_id=p_club_id
      and (p_anio is null or extract(year from q.periodo)::int=p_anio)
      and (p_mes is null or extract(month from q.periodo)::int=p_mes)
      and (p_socio_id is null or q.socio_id=p_socio_id)
      and (p_categoria is null or coalesce(q.categoria_financiera,case when q.origen='material' then 'material' when q.origen='cuota' then 'cuota' else 'otro' end)=p_categoria)
      and (p_estado is null
        or q.estado::text=p_estado
        or (p_estado='pendiente_abierto' and q.estado::text not in ('pagada','anulada','exenta') and greatest(q.importe-coalesce(pa.pagado_validado,0),0)>0)
        or (p_estado='vencido_abierto' and q.estado::text not in ('pagada','anulada','exenta') and q.vencimiento<v_today and greatest(q.importe-coalesce(pa.pagado_validado,0),0)>0)
        or (p_estado='cobrado' and coalesce(pa.pagado_validado,0)>0))
      and (p_regla_id is null or q.regla_cobro_id=p_regla_id)
      and (p_metodo is null or pa.ultimo_metodo_pago=p_metodo)
      and (p_grupo_id is null or exists(
        select 1 from public.socio_disciplinas sd
        where sd.club_id=q.club_id and sd.socio_id=q.socio_id and sd.grupo_id=p_grupo_id and sd.activa))
      and (p_disciplina_id is null or exists(
        select 1 from public.socio_disciplinas sd
        where sd.club_id=q.club_id and sd.socio_id=q.socio_id and sd.disciplina_id=p_disciplina_id and sd.activa))
  ), filtered as (
    select * from base where p_antiguedad is null or antiguedad=p_antiguedad
  ), valid as (
    select * from filtered where estado::text not in ('anulada','exenta')
  ), cat as (
    select categoria,
      coalesce(sum(importe),0)::numeric(14,2) generado,
      coalesce(sum(least(importe,pagado_validado)),0)::numeric(14,2) cobrado,
      coalesce(sum(saldo),0)::numeric(14,2) pendiente,
      count(*)::int cargos,
      count(distinct socio_id)::int alumnos
    from valid group by categoria
  ), memberships_group as (
    select distinct sd.club_id,sd.socio_id,sd.grupo_id
    from public.socio_disciplinas sd where sd.club_id=p_club_id and sd.activa and sd.grupo_id is not null
  ), grp as (
    select g.id,g.nombre,
      coalesce(sum(v.importe),0)::numeric(14,2) generado,
      coalesce(sum(least(v.importe,v.pagado_validado)),0)::numeric(14,2) cobrado,
      coalesce(sum(v.saldo),0)::numeric(14,2) pendiente,
      count(*)::int cargos,count(distinct v.socio_id)::int alumnos
    from valid v join memberships_group mg on mg.club_id=v.club_id and mg.socio_id=v.socio_id
    join public.grupos g on g.club_id=mg.club_id and g.id=mg.grupo_id
    group by g.id,g.nombre
  ), memberships_disc as (
    select distinct sd.club_id,sd.socio_id,sd.disciplina_id
    from public.socio_disciplinas sd where sd.club_id=p_club_id and sd.activa and sd.disciplina_id is not null
  ), dis as (
    select d.id,d.nombre,
      coalesce(sum(v.importe),0)::numeric(14,2) generado,
      coalesce(sum(least(v.importe,v.pagado_validado)),0)::numeric(14,2) cobrado,
      coalesce(sum(v.saldo),0)::numeric(14,2) pendiente,
      count(*)::int cargos,count(distinct v.socio_id)::int alumnos
    from valid v join memberships_disc md on md.club_id=v.club_id and md.socio_id=v.socio_id
    join public.disciplinas d on d.club_id=md.club_id and d.id=md.disciplina_id
    group by d.id,d.nombre
  )
  select
    coalesce((select jsonb_agg(jsonb_build_object(
      'categoria',c.categoria,'generado',c.generado,'cobrado',c.cobrado,'pendiente',c.pendiente,
      'cargos',c.cargos,'alumnos',c.alumnos
    ) order by c.generado desc,c.categoria) from cat c),'[]'::jsonb),
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',g.id,'nombre',g.nombre,'generado',g.generado,'cobrado',g.cobrado,'pendiente',g.pendiente,
      'cargos',g.cargos,'alumnos',g.alumnos
    ) order by g.generado desc,g.nombre) from (select * from grp order by generado desc,nombre limit 12) g),'[]'::jsonb),
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',d.id,'nombre',d.nombre,'generado',d.generado,'cobrado',d.cobrado,'pendiente',d.pendiente,
      'cargos',d.cargos,'alumnos',d.alumnos
    ) order by d.generado desc,d.nombre) from (select * from dis order by generado desc,nombre limit 12) d),'[]'::jsonb),
    coalesce((select sum(saldo) from valid where saldo>0 and vencimiento between v_today and v_today+30),0)::numeric(14,2),
    coalesce((select sum(saldo) from valid where saldo>0 and vencimiento<v_today),0)::numeric(14,2),
    coalesce((select sum(saldo) from valid where saldo>0),0)::numeric(14,2)
  into v_categories,v_groups,v_disciplines,v_forecast,v_overdue,v_pending;

  v_morosidad:=case when v_pending>0 then round((v_overdue/v_pending)*100,2) else 0 end;

  return v_base || jsonb_build_object(
    'analytics_version',150,
    'forecast_30d',v_forecast,
    'morosidad_pct',v_morosidad,
    'categories',v_categories,
    'groups',v_groups,
    'disciplines',v_disciplines,
    'attribution_note','Grupo y disciplina usan la afiliación activa actual; un alumno con varias afiliaciones puede aparecer en más de una barra.'
  );
end
$$;

revoke all on function public.app_finance_v2_dashboard_v150(uuid,integer,integer,uuid,uuid,uuid,text,text,uuid,text,text,integer,integer) from public,anon;
grant execute on function public.app_finance_v2_dashboard_v150(uuid,integer,integer,uuid,uuid,uuid,text,text,uuid,text,text,integer,integer) to authenticated;

commit;
