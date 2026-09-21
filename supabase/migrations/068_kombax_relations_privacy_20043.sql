-- KOMBAX RC13 build 20043 · privacidad estricta de Relaciones.
-- Regla de producto:
--   * Relaciones no son una métrica pública de popularidad.
--   * Ningún perfil público devuelve lista ni contador de relaciones.
--   * La lista de relaciones solo puede consultarla una cuenta autorizada para actuar
--     como esa identidad Social (Miembro, Club o perfil directo propio autorizado).
--   * Se cierran los RPC históricos que podían exponer relaciones confirmadas.

begin;

create or replace function public.app_kombax_relaciones_v068(p_social_id uuid)
returns table(
  id uuid,origen_social_id uuid,origen_nombre text,destino_social_id uuid,destino_nombre text,
  tipo text,estado text,nota text,creado_en timestamptz,confirmado_en timestamptz,gestionable boolean
)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  if p_social_id is null or not public.app_kombax_social_puede_actuar_v051(p_social_id) then
    raise exception 'KOMBAX_RELATIONS_PRIVATE';
  end if;

  return query
  select r.id,r.origen_social_id,o.nombre_publico,r.destino_social_id,d.nombre_publico,
    r.tipo,r.estado,r.nota,r.creado_en,r.confirmado_en,
    r.estado='pending' and public.app_kombax_social_puede_actuar_v051(r.destino_social_id)
  from public.kombax_relaciones r
  join public.kombax_social_perfiles o on o.id=r.origen_social_id
  join public.kombax_social_perfiles d on d.id=r.destino_social_id
  where r.origen_social_id=p_social_id or r.destino_social_id=p_social_id
  order by case r.estado when 'confirmed' then 0 when 'pending' then 1 else 2 end,r.creado_en desc;
end $$;
revoke all on function public.app_kombax_relaciones_v068(uuid) from public,anon;
grant execute on function public.app_kombax_relaciones_v068(uuid) to authenticated;
comment on function public.app_kombax_relaciones_v068(uuid) is 'Lista privada de relaciones de una identidad que auth.uid() puede gestionar; nunca directorio público.';

-- El perfil público 068 conserva el contrato funcional 065 salvo la red de relaciones.
create or replace function public.app_kombax_perfil_publico_v068(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  v:=public.app_kombax_perfil_publico_v065(p_social_id);
  if v is null then return null;end if;
  -- Defensa por contrato: aunque el wrapper histórico 065 construya "relations",
  -- la superficie pública 068 la elimina por completo. No se devuelve ni lista ni count.
  return v - 'relations';
end $$;
revoke all on function public.app_kombax_perfil_publico_v068(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v068(uuid) to authenticated;
comment on function public.app_kombax_perfil_publico_v068(uuid) is 'Perfil público KOMBAX sin lista ni contador de Relaciones.';

-- Cierre de compatibilidad insegura: clientes antiguos no pueden saltarse 068 llamando
-- directamente a los RPC que exponían relaciones en la respuesta pública o permitían
-- consultar una identidad ajena.
revoke execute on function public.app_kombax_relaciones_v045(uuid) from authenticated;
revoke execute on function public.app_kombax_perfil_publico_v052(uuid) from authenticated;
revoke execute on function public.app_kombax_perfil_publico_v053(uuid) from authenticated;
revoke execute on function public.app_kombax_perfil_publico_v065(uuid) from authenticated;

notify pgrst,'reload schema';
commit;
