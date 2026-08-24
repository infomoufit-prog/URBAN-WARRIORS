-- KOMBAX RC13 build 20079 · Finanzas Premium 2.0 · GATE 5
-- Reutiliza notificaciones/push existentes. No crea un segundo dispatcher.
-- Añade eventos accionables, deep-link metadata y auditoría financiera v2.

begin;

-- ---------------------------------------------------------------------------
-- 1. Enriquecimiento uniforme de notificaciones financieras existentes.
-- No expone importes en lockscreen: el dispatcher ya neutraliza FINANCE_TYPES.
-- ---------------------------------------------------------------------------
create or replace function public.trg_finance_notification_enrich_v147()
returns trigger
language plpgsql security definer set search_path=public,auth
as $$
declare v_target text;v_entity text;
begin
  if new.tipo in ('cuota','aviso_cobro','pago','validacion_pago','recibo') or coalesce((new.datos->>'finance_v2')::boolean,false) then
    new.ruta:=coalesce(nullif(new.ruta,''),'fees');
    if nullif(new.datos->>'pago_id','') is not null then
      v_target:='payment';v_entity:=new.datos->>'pago_id';
    elsif nullif(new.datos->>'recibo_id','') is not null then
      v_target:='receipt';v_entity:=new.datos->>'recibo_id';
    elsif nullif(new.datos->>'cuota_id','') is not null then
      v_target:='charge';v_entity:=new.datos->>'cuota_id';
    elsif nullif(new.datos->>'regla_id','') is not null then
      v_target:='automation';v_entity:=new.datos->>'regla_id';
    else
      v_target:=coalesce(nullif(new.datos->>'finance_target',''),'overview');
    end if;
    new.datos:=coalesce(new.datos,'{}'::jsonb)||jsonb_build_object(
      'finance_target',v_target,'entity_id',v_entity,'deep_link','finance:'||v_target
    );
  end if;
  return new;
end $$;
revoke all on function public.trg_finance_notification_enrich_v147() from public,anon,authenticated;

drop trigger if exists trg_finance_notification_enrich_v147 on public.notificaciones;
create trigger trg_finance_notification_enrich_v147
before insert or update of datos,ruta,tipo on public.notificaciones
for each row execute function public.trg_finance_notification_enrich_v147();

-- ---------------------------------------------------------------------------
-- 2. Pago comunicado: queda pendiente y avisa a tesorería/dirección.
-- La contabilidad NO cambia por este trigger; solo publica un evento.
-- ---------------------------------------------------------------------------
create or replace function public.trg_finance_pago_pendiente_v147()
returns trigger
language plpgsql security definer set search_path=public,auth
as $$
declare v_name text;
begin
  if new.estado_validacion<>'pendiente' then return new; end if;
  select trim(concat_ws(' ',s.nombre,s.apellidos)) into v_name
  from public.socios s where s.club_id=new.club_id and s.id=new.socio_id;
  insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  select new.club_id,rol,'finance-pago-validar-'||new.id::text||'-'||rol::text,'validacion_pago',
    'Pago pendiente de revisión','Hay un pago pendiente de revisión.','fees',
    jsonb_build_object('pago_id',new.id,'cuota_id',new.cuota_id,'socio_id',new.socio_id,'alumno',v_name,'requiere_accion',true),new.comunicado_por
  from unnest(array['direccion','economia']::public.rol_club[]) rol
  on conflict(club_id,rol_destino,clave) where clave is not null and rol_destino is not null do nothing;
  return new;
end $$;
revoke all on function public.trg_finance_pago_pendiente_v147() from public,anon,authenticated;

drop trigger if exists trg_finance_pago_pendiente_v147 on public.pagos;
create trigger trg_finance_pago_pendiente_v147
after insert on public.pagos
for each row execute function public.trg_finance_pago_pendiente_v147();

-- Sustituye únicamente la implementación del trigger histórico, conservando
-- el mismo nombre/enganche. Añade rechazo, clave idempotente y contexto exacto.
create or replace function public.notificar_pago_validado()
returns trigger
language plpgsql security definer set search_path=public,auth
as $$
declare v_perfil uuid;v_nombre text;v_title text;v_body text;
begin
  if new.estado_validacion not in ('validado','rechazado') or old.estado_validacion is not distinct from new.estado_validacion then
    return new;
  end if;
  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(concat_ws(' ',s.nombre,s.apellidos)) into v_perfil,v_nombre
  from public.socios s
  left join lateral(
    select ts.tutor_perfil_id from public.tutores_socios ts
    where ts.club_id=s.club_id and ts.socio_id=s.id
    order by ts.contacto_principal desc,ts.id limit 1
  ) t on true
  where s.club_id=new.club_id and s.id=new.socio_id;
  if v_perfil is null then return new; end if;
  v_title:=case when new.estado_validacion='validado' then 'Pago validado' else 'Pago rechazado' end;
  v_body:=case when new.estado_validacion='validado'
    then 'Tu pago ha sido validado.'
    else 'Tu pago necesita una revisión. Consulta el detalle en KOMBAX.' end;
  insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  values(new.club_id,v_perfil,'finance-pago-'||new.id::text||'-'||new.estado_validacion,'pago',v_title,v_body,'fees',
    jsonb_build_object('pago_id',new.id,'cuota_id',new.cuota_id,'socio_id',new.socio_id,'decision',new.estado_validacion,'requiere_accion',false),new.validado_por)
  on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  return new;
end $$;
revoke all on function public.notificar_pago_validado() from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- 3. Auditoría financiera específica. Complementa, no sustituye, auditoría
-- transversal existente. Nunca modifica el movimiento auditado.
-- ---------------------------------------------------------------------------
create or replace function public.trg_finance_pago_audit_v147()
returns trigger
language plpgsql security definer set search_path=public,auth
as $$
declare v_action text;
begin
  if tg_op='INSERT' then
    v_action:=case when new.estado_validacion='validado' then 'pago.registrar_admin' else 'pago.comunicar' end;
    perform public.app_finance_v2_audit_v143(new.club_id,v_action,'pago',new.id,null,to_jsonb(new),jsonb_build_object('trigger','v147'));
  elsif old.estado_validacion is distinct from new.estado_validacion then
    v_action:=case new.estado_validacion when 'validado' then 'pago.validar' when 'rechazado' then 'pago.rechazar' else 'pago.estado' end;
    perform public.app_finance_v2_audit_v143(new.club_id,v_action,'pago',new.id,to_jsonb(old),to_jsonb(new),jsonb_build_object('trigger','v147'));
  end if;
  return new;
end $$;
revoke all on function public.trg_finance_pago_audit_v147() from public,anon,authenticated;

drop trigger if exists trg_finance_pago_audit_v147 on public.pagos;
create trigger trg_finance_pago_audit_v147
after insert or update of estado_validacion on public.pagos
for each row execute function public.trg_finance_pago_audit_v147();

create or replace function public.trg_finance_receipt_audit_v147()
returns trigger
language plpgsql security definer set search_path=public,auth
as $$
begin
  if tg_op='INSERT' then
    perform public.app_finance_v2_audit_v143(new.club_id,'recibo.emitir','recibo',new.id,null,to_jsonb(new),jsonb_build_object('cuota_id',new.cuota_id));
  elsif old.anulado_en is distinct from new.anulado_en and new.anulado_en is not null then
    perform public.app_finance_v2_audit_v143(new.club_id,'recibo.anular','recibo',new.id,to_jsonb(old),to_jsonb(new),jsonb_build_object('cuota_id',new.cuota_id));
  end if;
  return new;
end $$;
revoke all on function public.trg_finance_receipt_audit_v147() from public,anon,authenticated;

drop trigger if exists trg_finance_receipt_audit_v147 on public.recibos_cuota;
create trigger trg_finance_receipt_audit_v147
after insert or update of anulado_en on public.recibos_cuota
for each row execute function public.trg_finance_receipt_audit_v147();

create or replace function public.app_finance_v2_notifications_audit_v147()
returns table(control text,ok boolean,detalle text)
language sql security definer set search_path=public,auth
as $$
  select 'infraestructura única',to_regclass('public.notificaciones') is not null,'se reutiliza notificaciones'
  union all select 'pago pendiente accionable',exists(select 1 from pg_trigger where tgname='trg_finance_pago_pendiente_v147' and not tgisinternal),'tesorería recibe evento'
  union all select 'pago validado/rechazado',exists(select 1 from pg_trigger where tgname='trg_notificar_pago_validado' and not tgisinternal),'trigger histórico preservado'
  union all select 'deep link metadata',exists(select 1 from pg_trigger where tgname='trg_finance_notification_enrich_v147' and not tgisinternal),'ruta + entidad'
  union all select 'auditoría pagos',exists(select 1 from pg_trigger where tgname='trg_finance_pago_audit_v147' and not tgisinternal),'trazabilidad financiera';
$$;
revoke all on function public.app_finance_v2_notifications_audit_v147() from public,anon,authenticated;
grant execute on function public.app_finance_v2_notifications_audit_v147() to service_role,postgres;

notify pgrst,'reload schema';
commit;
