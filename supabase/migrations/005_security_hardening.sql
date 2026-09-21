-- ============================================================================
-- URBAN WARRIORS · 005 SECURITY HARDENING
-- Aplicar DESPUÉS de 004_payment_reminders_workflow.sql.
-- Restringe al monitor a sus grupos/alumnos y protege datos económicos,
-- consentimientos, material y vistas auxiliares.
-- ============================================================================

-- 1. Funciones de alcance del monitor y acceso a grupos.
create or replace function public.monitor_asignado_a_grupo(p_grupo_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.grupos g
    where g.id = p_grupo_id
      and g.activo
      and g.monitor_principal_id = auth.uid()
      and public.tiene_rol_club(g.club_id, 'monitor')
  );
$$;

create or replace function public.monitor_puede_ver_socio(p_socio_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.socio_disciplinas sd
    join public.grupos g
      on g.club_id = sd.club_id
     and g.id = sd.grupo_id
    where sd.socio_id = p_socio_id
      and sd.activa
      and g.activo
      and g.monitor_principal_id = auth.uid()
      and public.tiene_rol_club(sd.club_id, 'monitor')
  );
$$;

create or replace function public.puede_ver_grupo(p_grupo_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.grupos g
    where g.id = p_grupo_id
      and (
        public.tiene_rol_club(g.club_id, 'direccion', 'secretaria')
        or public.monitor_asignado_a_grupo(g.id)
        or exists (
          select 1
          from public.socio_disciplinas sd
          join public.socios s
            on s.club_id = sd.club_id
           and s.id = sd.socio_id
          where sd.club_id = g.club_id
            and sd.grupo_id = g.id
            and sd.activa
            and (
              s.perfil_id = auth.uid()
              or exists (
                select 1
                from public.tutores_socios ts
                where ts.club_id = s.club_id
                  and ts.socio_id = s.id
                  and ts.tutor_perfil_id = auth.uid()
              )
            )
        )
      )
  );
$$;

-- 2. El monitor solo ve alumnos asignados a uno de sus grupos.
create or replace function public.puede_ver_socio(p_socio_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.socios s
    where s.id = p_socio_id
      and (
        s.perfil_id = auth.uid()
        or public.tiene_rol_club(s.club_id, 'direccion', 'secretaria', 'economia')
        or exists (
          select 1
          from public.tutores_socios t
          where t.club_id = s.club_id
            and t.socio_id = s.id
            and t.tutor_perfil_id = auth.uid()
        )
        or public.monitor_puede_ver_socio(s.id)
      )
  );
$$;

revoke all on function public.monitor_asignado_a_grupo(uuid) from public, anon;
revoke all on function public.monitor_puede_ver_socio(uuid) from public, anon;
revoke all on function public.puede_ver_grupo(uuid) from public, anon;
grant execute on function public.monitor_asignado_a_grupo(uuid) to authenticated;
grant execute on function public.monitor_puede_ver_socio(uuid) to authenticated;
grant execute on function public.puede_ver_grupo(uuid) to authenticated;

-- 3. Catálogo de grados: el monitor consulta, pero no modifica el catálogo.
drop policy if exists grados_gestion on public.grados;
create policy grados_gestion on public.grados
for all
using (public.tiene_rol_club(club_id, 'direccion', 'secretaria'))
with check (public.tiene_rol_club(club_id, 'direccion', 'secretaria'));

-- 4. Graduaciones: un monitor solo registra las de sus alumnos.
drop policy if exists graduaciones_gestion on public.graduaciones;
create policy graduaciones_gestion on public.graduaciones
for insert
with check (
  public.tiene_rol_club(club_id, 'direccion', 'secretaria')
  or (
    public.tiene_rol_club(club_id, 'monitor')
    and public.monitor_puede_ver_socio(socio_id)
  )
);

-- 5. Sesiones: familias/alumnos ven las de sus grupos; el monitor gestiona las suyas.
drop policy if exists sesiones_lectura on public.sesiones_entrenamiento;
drop policy if exists sesiones_gestion on public.sesiones_entrenamiento;
create policy sesiones_lectura on public.sesiones_entrenamiento
for select
using (public.puede_ver_grupo(grupo_id));
create policy sesiones_gestion on public.sesiones_entrenamiento
for all
using (
  public.tiene_rol_club(club_id, 'direccion', 'secretaria')
  or public.monitor_asignado_a_grupo(grupo_id)
)
with check (
  public.tiene_rol_club(club_id, 'direccion', 'secretaria')
  or public.monitor_asignado_a_grupo(grupo_id)
);

-- 6. Asistencia y seguimiento: alcance por alumno/grupo.
drop policy if exists asistencia_lectura on public.asistencias;
drop policy if exists asistencia_gestion on public.asistencias;
create policy asistencia_lectura on public.asistencias
for select
using (public.puede_ver_socio(socio_id));
create policy asistencia_gestion on public.asistencias
for all
using (
  public.tiene_rol_club(club_id, 'direccion')
  or public.monitor_puede_ver_socio(socio_id)
)
with check (
  public.tiene_rol_club(club_id, 'direccion')
  or public.monitor_puede_ver_socio(socio_id)
);

drop policy if exists seguimiento_lectura on public.seguimiento;
drop policy if exists seguimiento_gestion on public.seguimiento;
create policy seguimiento_lectura on public.seguimiento
for select
using (
  public.tiene_rol_club(club_id, 'direccion', 'secretaria')
  or public.monitor_puede_ver_socio(socio_id)
  or (visibilidad = 'familia' and public.puede_aportar_pago_socio(socio_id))
);
create policy seguimiento_gestion on public.seguimiento
for all
using (
  public.tiene_rol_club(club_id, 'direccion')
  or public.monitor_puede_ver_socio(socio_id)
)
with check (
  public.tiene_rol_club(club_id, 'direccion')
  or public.monitor_puede_ver_socio(socio_id)
);

-- 7. Accesos a clase: el monitor solo consulta/gestiona sesiones asignadas.
drop policy if exists accesos_lectura on public.registros_acceso_clase;
drop policy if exists accesos_gestion_equipo on public.registros_acceso_clase;
create policy accesos_lectura on public.registros_acceso_clase
for select
using (
  public.puede_aportar_pago_socio(socio_id)
  or public.tiene_rol_club(club_id, 'direccion', 'secretaria')
  or exists (
    select 1
    from public.sesiones_entrenamiento se
    where se.club_id = registros_acceso_clase.club_id
      and se.id = registros_acceso_clase.sesion_id
      and public.monitor_asignado_a_grupo(se.grupo_id)
  )
);
create policy accesos_gestion_equipo on public.registros_acceso_clase
for all
using (
  public.tiene_rol_club(club_id, 'direccion', 'secretaria')
  or exists (
    select 1
    from public.sesiones_entrenamiento se
    where se.club_id = registros_acceso_clase.club_id
      and se.id = registros_acceso_clase.sesion_id
      and public.monitor_asignado_a_grupo(se.grupo_id)
  )
)
with check (
  public.tiene_rol_club(club_id, 'direccion', 'secretaria')
  or exists (
    select 1
    from public.sesiones_entrenamiento se
    where se.club_id = registros_acceso_clase.club_id
      and se.id = registros_acceso_clase.sesion_id
      and public.monitor_asignado_a_grupo(se.grupo_id)
  )
);

-- 8. Consentimientos y material: nunca quedan visibles para monitores por herencia.
drop policy if exists consentimientos_lectura on public.consentimientos;
create policy consentimientos_lectura on public.consentimientos
for select
using (
  public.puede_aportar_pago_socio(socio_id)
  or public.tiene_rol_club(club_id, 'direccion', 'secretaria')
);

drop policy if exists material_pedidos_lectura on public.material_pedidos;
create policy material_pedidos_lectura on public.material_pedidos
for select
using (
  public.puede_aportar_pago_socio(socio_id)
  or public.tiene_rol_club(club_id, 'direccion', 'secretaria', 'economia')
);

drop policy if exists material_pedidos_solicitar on public.material_pedidos;
create policy material_pedidos_solicitar on public.material_pedidos
for insert
with check (public.puede_aportar_pago_socio(socio_id));

drop policy if exists entregas_lectura on public.material_entregas;
create policy entregas_lectura on public.material_entregas
for select
using (
  public.puede_aportar_pago_socio(socio_id)
  or public.tiene_rol_club(club_id, 'direccion', 'secretaria', 'economia')
);

-- 9. Las vistas deben respetar las políticas RLS del usuario que las consulta.
do $$
begin
  if to_regclass('public.v_socio_completo') is not null then
    execute 'alter view public.v_socio_completo set (security_invoker = true)';
  end if;
  if to_regclass('public.v_ocupacion_grupo') is not null then
    execute 'alter view public.v_ocupacion_grupo set (security_invoker = true)';
  end if;
end $$;

-- 10. La preinscripción directa solo se permite a usuarios autenticados.
drop policy if exists preinscripcion_publica on public.preinscripciones;
create policy preinscripcion_publica on public.preinscripciones
for insert to authenticated
with check (
  solicitante_perfil_id = auth.uid()
  and exists (
    select 1 from public.clubes c
    where c.id = club_id and c.activo
  )
);
