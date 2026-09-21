-- KOMBAX RC13 build 20069
-- Corrective migration: account state is held by Auth, not public.perfiles.

create or replace function public.app_kombax_platform_entities_v114(p_query text default '',p_limit integer default 100)
returns table(id uuid,entidad_tipo text,nombre text,estado text,referencia text,actualizado_en timestamptz)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_q text:=lower(btrim(coalesce(p_query,'')));
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  return query
  select x.id,x.entidad_tipo,x.nombre,x.estado,x.referencia,x.actualizado_en from (
    select c.id as id,'club'::text as entidad_tipo,c.nombre as nombre,c.activo::text as estado,c.slug as referencia,c.actualizado_en as actualizado_en from public.clubes c
    union all
    select d.id,d.tipo,d.nombre_publico,d.estado,d.slug,d.actualizado_en from public.perfiles_kombax_directos d
    union all
    select p.id,'cuenta',coalesce(nullif(btrim(concat_ws(' ',p.nombre,p.apellidos)),''),u.email,'Cuenta KOMBAX'),
      case when u.banned_until is not null and u.banned_until>now() then 'suspendida' else 'activa' end,
      coalesce(u.email,p.id::text),p.actualizado_en
    from public.perfiles p join auth.users u on u.id=p.id
  ) x
  where v_q='' or lower(coalesce(x.nombre,'')||' '||coalesce(x.referencia,'')||' '||x.entidad_tipo) like '%'||v_q||'%'
  order by x.actualizado_en desc
  limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_platform_entities_v114(text,integer) from public,anon;
grant execute on function public.app_kombax_platform_entities_v114(text,integer) to authenticated;
