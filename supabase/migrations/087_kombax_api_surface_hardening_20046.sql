-- KOMBAX 20.046 / 087
-- Conservative API-surface hardening.
-- Goals:
--   * public registration reads only an explicit minimal RPC contract;
--   * anon loses direct access to private business tables while 20.045 keeps its
--     five registration SELECTs during the transition;
--   * obsolete/trigger SECURITY DEFINER functions are no longer callable as client RPCs;
--   * global login moves to v072 before v043 is retired;
--   * multiclub work-scope RLS removes a tautological club comparison.

begin;

create or replace function public.app_kombax_registro_catalogo_publico_v087(p_club_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_club public.clubes%rowtype;
begin
  select c.* into v_club
  from public.clubes c
  where lower(c.slug)=lower(btrim(coalesce(p_club_slug,'')))
    and c.activo
  limit 1;

  if v_club.id is null then
    return jsonb_build_object('available',false);
  end if;

  return jsonb_build_object(
    'available',true,
    'club',jsonb_build_object('id',v_club.id,'nombre',v_club.nombre),
    'd',coalesce((
      select jsonb_agg(jsonb_build_object('id',d.id,'nombre',d.nombre) order by d.orden,d.nombre)
      from public.disciplinas d
      where d.club_id=v_club.id and d.activa
    ),'[]'::jsonb),
    'g',coalesce((
      select jsonb_agg(jsonb_build_object('id',g.id,'nombre',g.nombre) order by g.nombre)
      from public.grupos g
      where g.club_id=v_club.id and g.activo
    ),'[]'::jsonb),
    't',coalesce((
      select jsonb_agg(jsonb_build_object('id',t.id,'nombre',t.nombre,'importe',t.importe) order by t.nombre)
      from public.tarifas t
      where t.club_id=v_club.id and t.activa
    ),'[]'::jsonb),
    'legal',coalesce((
      select jsonb_agg(jsonb_build_object('id',l.id,'tipo',l.tipo,'version',l.version,'cuerpo',l.cuerpo) order by l.tipo)
      from public.textos_legales l
      where l.club_id=v_club.id and l.vigente
    ),'[]'::jsonb)
  );
end;
$$;

revoke all on function public.app_kombax_registro_catalogo_publico_v087(text) from public;
grant execute on function public.app_kombax_registro_catalogo_publico_v087(text) to anon, authenticated, service_role;

-- Retire old authenticated identity-list endpoints only after frontend moved to v072.
revoke execute on function public.app_kombax_mis_perfiles_v043() from anon, authenticated;
revoke execute on function public.app_kombax_mis_solicitudes_v043() from anon, authenticated;
grant execute on function public.app_kombax_mis_perfiles_v072() to authenticated;
grant execute on function public.app_kombax_mis_solicitudes_v072() to authenticated;

-- Obsolete diagnostics are not part of the runtime contract (v166 is current).
revoke execute on function public.app_diagnostico_v150(uuid) from public, anon, authenticated;
revoke execute on function public.app_diagnostico_integridad_v152(uuid) from public, anon, authenticated;

-- Trigger functions must execute as triggers, never as exposed client RPC endpoints.
revoke execute on function public.actualizar_grado_actual() from public, anon, authenticated;
revoke execute on function public.cleanup_reserva_sesion_notificaciones() from public, anon, authenticated;
revoke execute on function public.crear_perfil_usuario() from public, anon, authenticated;
revoke execute on function public.notificar_pago_validado() from public, anon, authenticated;
revoke execute on function public.registrar_auditoria() from public, anon, authenticated;
revoke execute on function public.registrar_cambio_tarifa() from public, anon, authenticated;

-- Role helpers remain available to authenticated RLS, but are not public RPCs.
revoke execute on function public.es_miembro_club(uuid) from public, anon;
revoke execute on function public.puede_gestionar_socio(uuid) from public, anon;
revoke execute on function public.puede_ver_socio(uuid) from public, anon;
revoke execute on function public.tiene_rol_club(uuid, variadic public.rol_club[]) from public, anon;
grant execute on function public.es_miembro_club(uuid) to authenticated, service_role;
grant execute on function public.puede_gestionar_socio(uuid) to authenticated, service_role;
grant execute on function public.puede_ver_socio(uuid) to authenticated, service_role;
grant execute on function public.tiene_rol_club(uuid, variadic public.rol_club[]) to authenticated, service_role;

-- Operational finance helper requires a signed-in role; anon has no legitimate caller.
revoke execute on function public.generar_alertas_cuotas(uuid,integer) from public, anon;
grant execute on function public.generar_alertas_cuotas(uuid,integer) to authenticated, service_role;

-- Policies used by the five transitional registration tables are split so anon
-- only evaluates pure public-registration predicates, never authenticated helpers.
drop policy if exists clubes_gestion on public.clubes;
create policy clubes_gestion on public.clubes
  for update to authenticated
  using (public.tiene_rol_club(id,'direccion'))
  with check (public.tiene_rol_club(id,'direccion'));

drop policy if exists clubes_publicos on public.clubes;
create policy clubes_publicos on public.clubes
  for select to authenticated
  using (activo or public.es_miembro_club(id));

drop policy if exists disciplinas_gestion on public.disciplinas;
create policy disciplinas_gestion on public.disciplinas
  for all to authenticated
  using (public.tiene_rol_club(club_id,'direccion','secretaria'))
  with check (public.tiene_rol_club(club_id,'direccion','secretaria'));

drop policy if exists disciplinas_lectura on public.disciplinas;
create policy disciplinas_lectura on public.disciplinas
  for select to authenticated
  using (public.es_miembro_club(club_id));

drop policy if exists grupos_gestion on public.grupos;
create policy grupos_gestion on public.grupos
  for all to authenticated
  using (public.tiene_rol_club(club_id,'direccion','secretaria'))
  with check (public.tiene_rol_club(club_id,'direccion','secretaria'));

drop policy if exists grupos_lectura on public.grupos;
create policy grupos_lectura on public.grupos
  for select to authenticated
  using (((not public.app_kombax_es_monitor_restringido_v057(club_id)) and public.es_miembro_club(club_id)) or public.puede_ver_grupo(id));

drop policy if exists tarifas_gestion on public.tarifas;
create policy tarifas_gestion on public.tarifas
  for all to authenticated
  using (public.tiene_rol_club(club_id,'direccion','economia'))
  with check (public.tiene_rol_club(club_id,'direccion','economia'));

drop policy if exists tarifas_lectura on public.tarifas;
create policy tarifas_lectura on public.tarifas
  for select to authenticated
  using (public.es_miembro_club(club_id));

drop policy if exists legales_gestion on public.textos_legales;
create policy legales_gestion on public.textos_legales
  for all to authenticated
  using (public.tiene_rol_club(club_id,'direccion','secretaria'))
  with check (public.tiene_rol_club(club_id,'direccion','secretaria'));

drop policy if exists legales_lectura on public.textos_legales;
create policy legales_lectura on public.textos_legales
  for select to authenticated
  using (public.es_miembro_club(club_id));

-- Correct the multiclub tautology ae.club_id = ae.club_id.
drop policy if exists ambitos_lectura_v057 on public.club_ambitos_trabajo;
create policy ambitos_lectura_v057 on public.club_ambitos_trabajo
  for select to authenticated
  using (
    public.app_kombax_puede_gestionar_ambitos_v057(club_id)
    or exists (
      select 1
      from public.club_ambito_equipo ae
      where ae.ambito_id=club_ambitos_trabajo.id
        and ae.club_id=club_ambitos_trabajo.club_id
        and ae.perfil_id=auth.uid()
        and ae.activo
    )
  );

-- Correct the access-log tautology s.club_id = s.club_id and restrict self check-in to signed-in users.
drop policy if exists accesos_registro_usuario on public.registros_acceso_clase;
create policy accesos_registro_usuario on public.registros_acceso_clase
  for insert to authenticated
  with check (
    public.puede_ver_socio(socio_id)
    and exists (
      select 1
      from public.sesiones_entrenamiento s
      where s.id=registros_acceso_clase.sesion_id
        and s.club_id=registros_acceso_clase.club_id
        and s.fecha=current_date
        and s.estado<>'cancelada'
    )
  );

-- Remove direct anon access from every business table except the five tables
-- kept SELECT-compatible for build 20.045 clients during the transition.
do $$
declare r record;
begin
  for r in
    select n.nspname,c.relname
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relkind in ('r','p','v','m','f')
      and c.relname not in ('clubes','disciplinas','grupos','tarifas','textos_legales')
  loop
    execute format('revoke all privileges on table %I.%I from anon',r.nspname,r.relname);
  end loop;
end $$;

-- On transitional public-registration tables, preserve SELECT only.
revoke insert, update, delete, truncate, references, trigger on public.clubes from anon;
revoke insert, update, delete, truncate, references, trigger on public.disciplinas from anon;
revoke insert, update, delete, truncate, references, trigger on public.grupos from anon;
revoke insert, update, delete, truncate, references, trigger on public.tarifas from anon;
revoke insert, update, delete, truncate, references, trigger on public.textos_legales from anon;

commit;
