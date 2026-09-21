-- KOMBAX 20.101 R53 · Mi red universal para perfiles públicos activos.
-- Mantiene vínculos profesionales existentes y añade una conexión KOMBAX general, privada y bidireccional.
begin;

alter table public.kombax_relaciones drop constraint if exists kombax_relaciones_tipo_check;
alter table public.kombax_relaciones
  add constraint kombax_relaciones_tipo_check
  check(tipo in (
    'conexion_kombax','competidor_club','club_federacion','competidor_profesional',
    'marca_club','marca_competidor','profesional_evento','profesional_club'
  ));

create unique index if not exists uq_kombax_conexion_abierta_v247
  on public.kombax_relaciones(
    least(origen_social_id,destino_social_id),
    greatest(origen_social_id,destino_social_id)
  )
  where tipo='conexion_kombax' and estado in ('pending','confirmed');

create or replace function public.app_kombax_relacion_tipo_valido_v045(p_from uuid,p_to uuid,p_type text)
returns boolean language plpgsql stable security definer set search_path=public as $$
declare a text:=public.app_kombax_social_tipo_v051(p_from);b text:=public.app_kombax_social_tipo_v051(p_to);t text:=lower(coalesce(p_type,''));
begin
  if a is null or b is null or p_from=p_to then return false;end if;
  return case t
    when 'conexion_kombax' then true
    when 'competidor_club' then (a='competidor' and b='club') or (a='club' and b='competidor')
    when 'club_federacion' then (a='club' and b='federacion') or (a='federacion' and b='club')
    when 'competidor_profesional' then (a='competidor' and b='profesional') or (a='profesional' and b='competidor')
    when 'marca_club' then (a='marca' and b='club') or (a='club' and b='marca')
    when 'marca_competidor' then (a='marca' and b='competidor') or (a='competidor' and b='marca')
    when 'profesional_club' then (a='profesional' and b='club') or (a='club' and b='profesional')
    when 'profesional_evento' then a='profesional' or b='profesional'
    else false end;
end $$;
revoke all on function public.app_kombax_relacion_tipo_valido_v045(uuid,uuid,text) from public,anon;
grant execute on function public.app_kombax_relacion_tipo_valido_v045(uuid,uuid,text) to authenticated;

create or replace function public.app_kombax_relation_request_v247(
  p_origen_social_id uuid,
  p_destino_social_id uuid,
  p_nota text default null,
  p_request_id uuid default gen_random_uuid()
)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_existing public.kombax_relaciones;v_rel public.kombax_relaciones;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_origen_social_id is null or p_destino_social_id is null or p_origen_social_id=p_destino_social_id then raise exception 'KOMBAX_RELATION_PROFILES_INVALID';end if;
  if not public.app_kombax_social_puede_actuar_v051(p_origen_social_id) then raise exception 'KOMBAX_RELATION_SOURCE_NOT_OWNED';end if;
  if not exists(select 1 from public.kombax_social_perfiles where id=p_destino_social_id and visible and estado='activo') then raise exception 'KOMBAX_RELATION_TARGET_NOT_AVAILABLE';end if;

  select * into v_existing
  from public.kombax_relaciones r
  where r.tipo='conexion_kombax' and r.estado in ('pending','confirmed')
    and ((r.origen_social_id=p_origen_social_id and r.destino_social_id=p_destino_social_id)
      or (r.origen_social_id=p_destino_social_id and r.destino_social_id=p_origen_social_id))
  order by case r.estado when 'confirmed' then 0 else 1 end,r.creado_en desc
  limit 1;
  if v_existing.id is not null then
    return jsonb_build_object('ok',true,'existing',true,'data',to_jsonb(v_existing));
  end if;

  insert into public.kombax_relaciones(origen_social_id,destino_social_id,tipo,solicitado_por,nota)
    values(p_origen_social_id,p_destino_social_id,'conexion_kombax',v_uid,left(nullif(btrim(p_nota),''),500))
    returning * into v_rel;
  return jsonb_build_object('ok',true,'existing',false,'request_id',p_request_id,'data',to_jsonb(v_rel));
end $$;
revoke all on function public.app_kombax_relation_request_v247(uuid,uuid,text,uuid) from public,anon;
grant execute on function public.app_kombax_relation_request_v247(uuid,uuid,text,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
