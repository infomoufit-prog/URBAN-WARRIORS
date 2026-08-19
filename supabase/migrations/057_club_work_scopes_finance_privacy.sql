-- KOMBAX RC13 build 20030
-- 057 · Ámbitos de trabajo, carteras de monitor y privacidad financiera por alcance.
-- No modifica 051-056. Extiende el hardening de 005 para soportar varios monitores por ámbito.

begin;

create table if not exists public.club_ambitos_trabajo (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  nombre text not null,
  tipo text not null default 'monitor' check (tipo in ('monitor','equipo','sede','personalizado')),
  descripcion text,
  activo boolean not null default true,
  creado_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  actualizado_por uuid references public.perfiles(id),
  actualizado_en timestamptz not null default now(),
  unique(club_id,nombre),
  unique(club_id,id)
);

create table if not exists public.club_ambito_equipo (
  ambito_id uuid not null,
  club_id uuid not null references public.clubes(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  responsable boolean not null default false,
  finance_level text not null default 'none' check (finance_level in ('none','status','portfolio','collect','receipts')),
  ver_contacto boolean not null default false,
  gestionar_asistencia boolean not null default true,
  gestionar_seguimiento boolean not null default true,
  activo boolean not null default true,
  creado_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  primary key(ambito_id,perfil_id),
  foreign key(club_id,ambito_id) references public.club_ambitos_trabajo(club_id,id) on delete cascade
);

create table if not exists public.club_ambito_socios (
  ambito_id uuid not null,
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null,
  principal boolean not null default false,
  origen text not null default 'manual' check (origen in ('manual','grupo','importado')),
  activo boolean not null default true,
  creado_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  primary key(ambito_id,socio_id),
  foreign key(club_id,ambito_id) references public.club_ambitos_trabajo(club_id,id) on delete cascade,
  foreign key(club_id,socio_id) references public.socios(club_id,id) on delete cascade
);

create table if not exists public.club_ambito_grupos (
  ambito_id uuid not null,
  club_id uuid not null references public.clubes(id) on delete cascade,
  grupo_id uuid not null,
  activo boolean not null default true,
  creado_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  primary key(ambito_id,grupo_id),
  foreign key(club_id,ambito_id) references public.club_ambitos_trabajo(club_id,id) on delete cascade,
  foreign key(club_id,grupo_id) references public.grupos(club_id,id) on delete cascade
);

create index if not exists idx_ambito_equipo_perfil on public.club_ambito_equipo(club_id,perfil_id) where activo;
create index if not exists idx_ambito_socios_socio on public.club_ambito_socios(club_id,socio_id) where activo;
create index if not exists idx_ambito_grupos_grupo on public.club_ambito_grupos(club_id,grupo_id) where activo;
create unique index if not exists uq_ambito_socio_principal_v057 on public.club_ambito_socios(club_id,socio_id) where activo and principal;

alter table public.club_ambitos_trabajo enable row level security;
alter table public.club_ambito_equipo enable row level security;
alter table public.club_ambito_socios enable row level security;
alter table public.club_ambito_grupos enable row level security;

create or replace function public.app_kombax_puede_gestionar_ambitos_v057(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.miembros_club m
    where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo
      and (m.rol='direccion' or coalesce(m.coordinacion,false))
  );
$$;

create or replace function public.app_kombax_es_monitor_restringido_v057(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select
    exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and m.rol='monitor')
    and not exists(
      select 1 from public.miembros_club m
      where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo
        and (m.rol in ('direccion','secretaria','economia','comunicacion') or coalesce(m.coordinacion,false))
    );
$$;

create or replace function public.monitor_asignado_a_grupo_v057(p_grupo_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.grupos g
    where g.id=p_grupo_id and g.activo
      and public.tiene_rol_club(g.club_id,'monitor')
      and (
        g.monitor_principal_id=auth.uid()
        or exists(
          select 1
          from public.club_ambito_grupos ag
          join public.club_ambitos_trabajo a on a.id=ag.ambito_id and a.club_id=ag.club_id and a.activo
          join public.club_ambito_equipo ae on ae.ambito_id=a.id and ae.club_id=a.club_id and ae.activo
          where ag.club_id=g.club_id and ag.grupo_id=g.id and ag.activo and ae.perfil_id=auth.uid()
        )
      )
  );
$$;

create or replace function public.monitor_puede_ver_socio_v057(p_socio_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.socios s
    where s.id=p_socio_id
      and public.tiene_rol_club(s.club_id,'monitor')
      and (
        exists(
          select 1 from public.club_ambito_socios ax
          join public.club_ambitos_trabajo a on a.id=ax.ambito_id and a.club_id=ax.club_id and a.activo
          join public.club_ambito_equipo ae on ae.ambito_id=a.id and ae.club_id=a.club_id and ae.activo
          where ax.club_id=s.club_id and ax.socio_id=s.id and ax.activo and ae.perfil_id=auth.uid()
        )
        or exists(
          select 1
          from public.socio_disciplinas sd
          join public.grupos g on g.club_id=sd.club_id and g.id=sd.grupo_id and g.activo
          where sd.club_id=s.club_id and sd.socio_id=s.id and sd.activa
            and (
              g.monitor_principal_id=auth.uid()
              or exists(
                select 1
                from public.club_ambito_grupos ag
                join public.club_ambitos_trabajo a on a.id=ag.ambito_id and a.club_id=ag.club_id and a.activo
                join public.club_ambito_equipo ae on ae.ambito_id=a.id and ae.club_id=a.club_id and ae.activo
                where ag.club_id=g.club_id and ag.grupo_id=g.id and ag.activo and ae.perfil_id=auth.uid()
              )
            )
        )
      )
  );
$$;

-- Permisos operativos granulares. La visibilidad de un alumno no implica poder
-- modificar asistencia/seguimiento; el Gestor puede retirar cada capacidad.
create or replace function public.app_kombax_monitor_puede_asistencia_v057(p_grupo_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.grupos g
    where g.id=p_grupo_id and g.activo and public.tiene_rol_club(g.club_id,'monitor')
      and (
        g.monitor_principal_id=auth.uid()
        or exists(
          select 1 from public.club_ambito_grupos ag
          join public.club_ambitos_trabajo a on a.id=ag.ambito_id and a.club_id=ag.club_id and a.activo
          join public.club_ambito_equipo ae on ae.ambito_id=a.id and ae.club_id=a.club_id and ae.activo
          where ag.club_id=g.club_id and ag.grupo_id=g.id and ag.activo
            and ae.perfil_id=auth.uid() and ae.gestionar_asistencia
        )
      )
  );
$$;

create or replace function public.app_kombax_monitor_puede_asistencia_socio_v057(p_socio_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.socio_disciplinas sd
    where sd.socio_id=p_socio_id and sd.activa
      and public.app_kombax_monitor_puede_asistencia_v057(sd.grupo_id)
  )
  or exists(
    select 1 from public.socios s
    join public.club_ambito_socios ax on ax.club_id=s.club_id and ax.socio_id=s.id and ax.activo
    join public.club_ambitos_trabajo a on a.id=ax.ambito_id and a.club_id=ax.club_id and a.activo
    join public.club_ambito_equipo ae on ae.ambito_id=a.id and ae.club_id=a.club_id and ae.activo
    where s.id=p_socio_id and ae.perfil_id=auth.uid() and ae.gestionar_asistencia
      and public.tiene_rol_club(s.club_id,'monitor')
  );
$$;

create or replace function public.app_kombax_monitor_puede_asistencia_registro_v057(p_sesion_id uuid,p_socio_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.sesiones_entrenamiento se
    where se.id=p_sesion_id
      and public.app_kombax_monitor_puede_asistencia_v057(se.grupo_id)
      and exists(
        select 1 from public.socio_disciplinas sd
        where sd.club_id=se.club_id and sd.socio_id=p_socio_id and sd.grupo_id=se.grupo_id and sd.activa
      )
  );
$$;

create or replace function public.app_kombax_monitor_puede_seguimiento_v057(p_socio_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.socios s
    where s.id=p_socio_id and public.tiene_rol_club(s.club_id,'monitor') and (
      exists(
        select 1 from public.club_ambito_socios ax
        join public.club_ambitos_trabajo a on a.id=ax.ambito_id and a.club_id=ax.club_id and a.activo
        join public.club_ambito_equipo ae on ae.ambito_id=a.id and ae.club_id=a.club_id and ae.activo
        where ax.club_id=s.club_id and ax.socio_id=s.id and ax.activo
          and ae.perfil_id=auth.uid() and ae.gestionar_seguimiento
      )
      or exists(
        select 1 from public.socio_disciplinas sd
        join public.grupos g on g.club_id=sd.club_id and g.id=sd.grupo_id and g.activo
        where sd.club_id=s.club_id and sd.socio_id=s.id and sd.activa and (
          g.monitor_principal_id=auth.uid()
          or exists(
            select 1 from public.club_ambito_grupos ag
            join public.club_ambitos_trabajo a on a.id=ag.ambito_id and a.club_id=ag.club_id and a.activo
            join public.club_ambito_equipo ae on ae.ambito_id=a.id and ae.club_id=a.club_id and ae.activo
            where ag.club_id=g.club_id and ag.grupo_id=g.id and ag.activo
              and ae.perfil_id=auth.uid() and ae.gestionar_seguimiento
          )
        )
      )
    )
  );
$$;

-- Compatibilidad: los RPC/policies históricos siguen llamando a estos nombres.
create or replace function public.monitor_asignado_a_grupo(p_grupo_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.monitor_asignado_a_grupo_v057(p_grupo_id);
$$;

create or replace function public.monitor_puede_ver_socio(p_socio_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.monitor_puede_ver_socio_v057(p_socio_id);
$$;

-- Desde 057 este helper vuelve a significar acceso administrativo/familiar.
-- El monitor usa exclusivamente monitor_puede_ver_socio_v057() en superficies
-- operativas explícitas, evitando herencias accidentales hacia datos sensibles.
create or replace function public.puede_ver_socio(p_socio_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.socios s
    where s.id=p_socio_id and (
      s.perfil_id=auth.uid()
      or public.tiene_rol_club(s.club_id,'direccion','secretaria','economia')
      or exists(select 1 from public.tutores_socios t where t.club_id=s.club_id and t.socio_id=s.id and t.tutor_perfil_id=auth.uid())
    )
  );
$$;

create or replace function public.puede_ver_grupo(p_grupo_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.grupos g
    where g.id=p_grupo_id and (
      public.tiene_rol_club(g.club_id,'direccion','secretaria')
      or public.monitor_asignado_a_grupo_v057(g.id)
      or exists(
        select 1 from public.socio_disciplinas sd
        join public.socios s on s.club_id=sd.club_id and s.id=sd.socio_id
        where sd.club_id=g.club_id and sd.grupo_id=g.id and sd.activa
          and (s.perfil_id=auth.uid() or exists(select 1 from public.tutores_socios ts where ts.club_id=s.club_id and ts.socio_id=s.id and ts.tutor_perfil_id=auth.uid()))
      )
    )
  );
$$;

-- Un monitor no recibe nunca la fila administrativa completa de socios.
drop policy if exists socios_lectura on public.socios;
create policy socios_lectura on public.socios for select using (
  perfil_id=auth.uid()
  or public.tiene_rol_club(club_id,'direccion','secretaria','economia')
  or exists(select 1 from public.tutores_socios t where t.club_id=socios.club_id and t.socio_id=socios.id and t.tutor_perfil_id=auth.uid())
);

-- Los monitores solo pueden enumerar sus grupos; el resto de roles conserva la lectura previa.
drop policy if exists grupos_lectura on public.grupos;
create policy grupos_lectura on public.grupos for select using (
  (not public.app_kombax_es_monitor_restringido_v057(club_id) and public.es_miembro_club(club_id))
  or public.puede_ver_grupo(id)
);

drop policy if exists horarios_lectura on public.horarios_grupo;
create policy horarios_lectura on public.horarios_grupo for select using (
  (not public.app_kombax_es_monitor_restringido_v057(club_id) and public.es_miembro_club(club_id))
  or public.puede_ver_grupo(grupo_id)
);

-- Datos deportivos/operativos: el monitor sí ve únicamente sus alumnos.
drop policy if exists socio_disc_lectura on public.socio_disciplinas;
create policy socio_disc_lectura on public.socio_disciplinas for select using (
  public.puede_ver_socio(socio_id) or public.monitor_puede_ver_socio_v057(socio_id)
);

drop policy if exists graduaciones_lectura on public.graduaciones;
create policy graduaciones_lectura on public.graduaciones for select using (
  public.puede_ver_socio(socio_id) or public.monitor_puede_ver_socio_v057(socio_id)
);

drop policy if exists asistencia_lectura on public.asistencias;
create policy asistencia_lectura on public.asistencias for select using (
  public.puede_ver_socio(socio_id) or public.monitor_puede_ver_socio_v057(socio_id)
);
drop policy if exists asistencia_gestion on public.asistencias;
create policy asistencia_gestion on public.asistencias for all using (
  public.tiene_rol_club(club_id,'direccion') or public.app_kombax_monitor_puede_asistencia_registro_v057(sesion_id,socio_id)
) with check (
  public.tiene_rol_club(club_id,'direccion') or public.app_kombax_monitor_puede_asistencia_registro_v057(sesion_id,socio_id)
);

drop policy if exists seguimiento_lectura on public.seguimiento;
create policy seguimiento_lectura on public.seguimiento for select using (
  public.tiene_rol_club(club_id,'direccion','secretaria')
  or public.monitor_puede_ver_socio_v057(socio_id)
  or (visibilidad='familia' and public.puede_aportar_pago_socio(socio_id))
);
drop policy if exists seguimiento_gestion on public.seguimiento;
create policy seguimiento_gestion on public.seguimiento for all using (
  public.tiene_rol_club(club_id,'direccion') or public.app_kombax_monitor_puede_seguimiento_v057(socio_id)
) with check (
  public.tiene_rol_club(club_id,'direccion') or public.app_kombax_monitor_puede_seguimiento_v057(socio_id)
);


drop policy if exists graduaciones_gestion on public.graduaciones;
create policy graduaciones_gestion on public.graduaciones for insert with check (
  public.tiene_rol_club(club_id,'direccion','secretaria')
  or public.app_kombax_monitor_puede_seguimiento_v057(socio_id)
);

drop policy if exists accesos_lectura on public.registros_acceso_clase;
create policy accesos_lectura on public.registros_acceso_clase for select using (
  public.puede_aportar_pago_socio(socio_id)
  or public.tiene_rol_club(club_id,'direccion','secretaria')
  or exists(select 1 from public.sesiones_entrenamiento se where se.club_id=registros_acceso_clase.club_id and se.id=registros_acceso_clase.sesion_id and public.monitor_asignado_a_grupo_v057(se.grupo_id))
);
drop policy if exists accesos_gestion_equipo on public.registros_acceso_clase;
create policy accesos_gestion_equipo on public.registros_acceso_clase for all using (
  public.tiene_rol_club(club_id,'direccion','secretaria')
  or public.app_kombax_monitor_puede_asistencia_registro_v057(sesion_id,socio_id)
) with check (
  public.tiene_rol_club(club_id,'direccion','secretaria')
  or public.app_kombax_monitor_puede_asistencia_registro_v057(sesion_id,socio_id)
);

-- Reservas y series dejan de ser visibles globalmente a cualquier monitor.
drop policy if exists reservas_sesion_lectura on public.reservas_sesion;
create policy reservas_sesion_lectura on public.reservas_sesion for select to authenticated using (
  public.puede_ver_socio(socio_id)
  or public.tiene_rol_club(club_id,'direccion','secretaria')
  or public.monitor_puede_ver_socio_v057(socio_id)
);

drop policy if exists series_sesiones_lectura_rc10 on public.series_sesiones;
create policy series_sesiones_lectura_rc10 on public.series_sesiones for select to authenticated using (
  (not public.app_kombax_es_monitor_restringido_v057(club_id) and public.es_miembro_club(club_id))
  or public.monitor_asignado_a_grupo_v057(grupo_id)
);

-- Documentos y recibos continúan siendo privados aunque el monitor tenga acceso operativo al alumno.
drop policy if exists documentos_socios_lectura on public.documentos_socios;
create policy documentos_socios_lectura on public.documentos_socios for select to authenticated using (
  public.tiene_rol_club(club_id,'direccion','secretaria')
  or (visible_familia and public.puede_aportar_pago_socio(socio_id))
);
drop policy if exists documentos_socios_insertar on public.documentos_socios;
create policy documentos_socios_insertar on public.documentos_socios for insert to authenticated with check (
  public.tiene_rol_club(club_id,'direccion','secretaria') or public.puede_aportar_pago_socio(socio_id)
);

drop policy if exists recibos_cuota_lectura on public.recibos_cuota;
create policy recibos_cuota_lectura on public.recibos_cuota for select using (
  public.puede_aportar_pago_socio(socio_id)
  or public.tiene_rol_club(club_id,'direccion','economia','secretaria')
);


-- Storage documental: el acceso operativo del monitor nunca abre expedientes.
drop policy if exists member_documents_read on storage.objects;
create policy member_documents_read on storage.objects for select to authenticated using (
  bucket_id='member-documents'
  and array_length(storage.foldername(name),1)>=2
  and (
    public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion','secretaria')
    or public.puede_aportar_pago_socio(((storage.foldername(name))[2])::uuid)
  )
);
drop policy if exists member_documents_insert on storage.objects;
create policy member_documents_insert on storage.objects for insert to authenticated with check (
  bucket_id='member-documents'
  and array_length(storage.foldername(name),1)>=2
  and (
    public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion','secretaria')
    or public.puede_aportar_pago_socio(((storage.foldername(name))[2])::uuid)
  )
);

-- RLS de configuración de ámbitos.
drop policy if exists ambitos_lectura_v057 on public.club_ambitos_trabajo;
create policy ambitos_lectura_v057 on public.club_ambitos_trabajo for select to authenticated using (
  public.app_kombax_puede_gestionar_ambitos_v057(club_id)
  or exists(select 1 from public.club_ambito_equipo ae where ae.ambito_id=id and ae.club_id=club_id and ae.perfil_id=auth.uid() and ae.activo)
);
drop policy if exists ambitos_gestion_v057 on public.club_ambitos_trabajo;
create policy ambitos_gestion_v057 on public.club_ambitos_trabajo for all to authenticated using (public.app_kombax_puede_gestionar_ambitos_v057(club_id)) with check (public.app_kombax_puede_gestionar_ambitos_v057(club_id));

drop policy if exists ambito_equipo_lectura_v057 on public.club_ambito_equipo;
create policy ambito_equipo_lectura_v057 on public.club_ambito_equipo for select to authenticated using (perfil_id=auth.uid() or public.app_kombax_puede_gestionar_ambitos_v057(club_id));
drop policy if exists ambito_equipo_gestion_v057 on public.club_ambito_equipo;
create policy ambito_equipo_gestion_v057 on public.club_ambito_equipo for all to authenticated using (public.app_kombax_puede_gestionar_ambitos_v057(club_id)) with check (public.app_kombax_puede_gestionar_ambitos_v057(club_id));

drop policy if exists ambito_socios_lectura_v057 on public.club_ambito_socios;
create policy ambito_socios_lectura_v057 on public.club_ambito_socios for select to authenticated using (
  public.app_kombax_puede_gestionar_ambitos_v057(club_id)
  or exists(select 1 from public.club_ambito_equipo ae where ae.ambito_id=club_ambito_socios.ambito_id and ae.club_id=club_ambito_socios.club_id and ae.perfil_id=auth.uid() and ae.activo)
);
drop policy if exists ambito_socios_gestion_v057 on public.club_ambito_socios;
create policy ambito_socios_gestion_v057 on public.club_ambito_socios for all to authenticated using (public.app_kombax_puede_gestionar_ambitos_v057(club_id)) with check (public.app_kombax_puede_gestionar_ambitos_v057(club_id));

drop policy if exists ambito_grupos_lectura_v057 on public.club_ambito_grupos;
create policy ambito_grupos_lectura_v057 on public.club_ambito_grupos for select to authenticated using (
  public.app_kombax_puede_gestionar_ambitos_v057(club_id)
  or exists(select 1 from public.club_ambito_equipo ae where ae.ambito_id=club_ambito_grupos.ambito_id and ae.club_id=club_ambito_grupos.club_id and ae.perfil_id=auth.uid() and ae.activo)
);
drop policy if exists ambito_grupos_gestion_v057 on public.club_ambito_grupos;
create policy ambito_grupos_gestion_v057 on public.club_ambito_grupos for all to authenticated using (public.app_kombax_puede_gestionar_ambitos_v057(club_id)) with check (public.app_kombax_puede_gestionar_ambitos_v057(club_id));

-- Nivel financiero por alumno, calculado solo sobre los ámbitos que dan acceso a ese alumno.
create or replace function public.app_kombax_finance_level_socio_v057(p_socio_id uuid)
returns text language sql stable security definer set search_path=public,auth as $$
  with assigned as (
    select ae.finance_level
    from public.club_ambito_equipo ae
    join public.club_ambitos_trabajo a on a.id=ae.ambito_id and a.club_id=ae.club_id and a.activo
    join public.socios s on s.club_id=ae.club_id and s.id=p_socio_id
    where ae.perfil_id=auth.uid() and ae.activo and public.tiene_rol_club(ae.club_id,'monitor')
      and (
        exists(select 1 from public.club_ambito_socios ax where ax.ambito_id=a.id and ax.club_id=a.club_id and ax.socio_id=s.id and ax.activo)
        or exists(
          select 1 from public.club_ambito_grupos ag
          join public.socio_disciplinas sd on sd.club_id=ag.club_id and sd.grupo_id=ag.grupo_id and sd.socio_id=s.id and sd.activa
          where ag.ambito_id=a.id and ag.club_id=a.club_id and ag.activo
        )
      )
  ), ranked as (
    select finance_level, case finance_level when 'receipts' then 4 when 'collect' then 3 when 'portfolio' then 2 when 'status' then 1 else 0 end rank from assigned
  )
  select coalesce((select finance_level from ranked order by rank desc limit 1),'none');
$$;

create or replace function public.app_kombax_mi_ambito_v057(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid(); v_result jsonb; v_level text;
begin
  if v_uid is null or not public.es_miembro_club(p_club_id) then raise exception 'Sin contexto de club'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',a.id,'nombre',a.nombre,'tipo',a.tipo,'responsable',ae.responsable,'finance_level',ae.finance_level,
    'ver_contacto',ae.ver_contacto,'gestionar_asistencia',ae.gestionar_asistencia,'gestionar_seguimiento',ae.gestionar_seguimiento,
    'alumnos',(
      select count(distinct x.socio_id) from (
        select ax.socio_id from public.club_ambito_socios ax where ax.ambito_id=a.id and ax.club_id=a.club_id and ax.activo
        union
        select sd.socio_id from public.club_ambito_grupos ag join public.socio_disciplinas sd on sd.club_id=ag.club_id and sd.grupo_id=ag.grupo_id and sd.activa where ag.ambito_id=a.id and ag.club_id=a.club_id and ag.activo
      ) x
    ),
    'grupos',(select count(*) from public.club_ambito_grupos ag where ag.ambito_id=a.id and ag.club_id=a.club_id and ag.activo)
  ) order by a.nombre),'[]'::jsonb) into v_result
  from public.club_ambitos_trabajo a join public.club_ambito_equipo ae on ae.ambito_id=a.id and ae.club_id=a.club_id
  where a.club_id=p_club_id and a.activo and ae.perfil_id=v_uid and ae.activo;
  select case max(case ae.finance_level when 'receipts' then 4 when 'collect' then 3 when 'portfolio' then 2 when 'status' then 1 else 0 end)
    when 4 then 'receipts' when 3 then 'collect' when 2 then 'portfolio' when 1 then 'status' else 'none' end into v_level
  from public.club_ambito_equipo ae join public.club_ambitos_trabajo a on a.id=ae.ambito_id and a.club_id=ae.club_id and a.activo
  where ae.club_id=p_club_id and ae.perfil_id=v_uid and ae.activo;
  return jsonb_build_object('club_id',p_club_id,'ambitos',coalesce(v_result,'[]'::jsonb),'finance_level',coalesce(v_level,'none'),
    'legacy_groups',coalesce((select count(*) from public.grupos g where g.club_id=p_club_id and g.activo and g.monitor_principal_id=v_uid),0));
end; $$;

create or replace function public.app_kombax_mis_alumnos_v057(p_club_id uuid)
returns table(
  id uuid,nombre text,apellidos text,estado text,edad integer,email text,telefono text,disciplinas text,grupos text
) language sql stable security definer set search_path=public,auth as $$
  select s.id,s.nombre,s.apellidos,s.estado,
    case when s.fecha_nacimiento is null then null else extract(year from age(s.fecha_nacimiento))::integer end,
    case when exists(
      select 1 from public.club_ambito_equipo ae join public.club_ambitos_trabajo a on a.id=ae.ambito_id and a.club_id=ae.club_id and a.activo
      where ae.club_id=s.club_id and ae.perfil_id=auth.uid() and ae.activo and ae.ver_contacto
        and (exists(select 1 from public.club_ambito_socios ax where ax.ambito_id=a.id and ax.socio_id=s.id and ax.activo)
          or exists(select 1 from public.club_ambito_grupos ag join public.socio_disciplinas sd on sd.club_id=ag.club_id and sd.grupo_id=ag.grupo_id and sd.socio_id=s.id and sd.activa where ag.ambito_id=a.id and ag.activo))
    ) then s.email else null end,
    case when exists(
      select 1 from public.club_ambito_equipo ae join public.club_ambitos_trabajo a on a.id=ae.ambito_id and a.club_id=ae.club_id and a.activo
      where ae.club_id=s.club_id and ae.perfil_id=auth.uid() and ae.activo and ae.ver_contacto
        and (exists(select 1 from public.club_ambito_socios ax where ax.ambito_id=a.id and ax.socio_id=s.id and ax.activo)
          or exists(select 1 from public.club_ambito_grupos ag join public.socio_disciplinas sd on sd.club_id=ag.club_id and sd.grupo_id=ag.grupo_id and sd.socio_id=s.id and sd.activa where ag.ambito_id=a.id and ag.activo))
    ) then s.telefono else null end,
    coalesce((select string_agg(distinct d.nombre,', ' order by d.nombre) from public.socio_disciplinas sd join public.disciplinas d on d.club_id=sd.club_id and d.id=sd.disciplina_id where sd.club_id=s.club_id and sd.socio_id=s.id and sd.activa),'') as disciplinas,
    coalesce((select string_agg(distinct g.nombre,', ' order by g.nombre) from public.socio_disciplinas sd join public.grupos g on g.club_id=sd.club_id and g.id=sd.grupo_id where sd.club_id=s.club_id and sd.socio_id=s.id and sd.activa),'') as grupos
  from public.socios s
  where s.club_id=p_club_id and public.monitor_puede_ver_socio_v057(s.id)
  order by s.apellidos,s.nombre;
$$;

create or replace function public.app_kombax_mi_cartera_v057(p_club_id uuid)
returns table(
  socio_id uuid,socio_nombre text,cuota_id uuid,periodo date,concepto text,estado text,vencimiento date,
  importe numeric,saldo numeric,pagado_validado numeric,recibo_id uuid,recibo_numero text,
  finance_level text,can_collect boolean,can_view_receipts boolean
) language sql stable security definer set search_path=public,auth as $$
  select s.id,trim(s.nombre||' '||s.apellidos),q.id,q.periodo,q.concepto,q.estado::text,q.vencimiento,
    case when lvl.level in ('portfolio','collect','receipts') then q.importe else null end,
    case when lvl.level in ('portfolio','collect','receipts') then greatest(q.importe-coalesce(pa.pagado,0),0) else null end,
    case when lvl.level in ('portfolio','collect','receipts') then coalesce(pa.pagado,0) else null end,
    case when lvl.level='receipts' then rc.id else null end,
    case when lvl.level='receipts' then rc.numero else null end,
    lvl.level,(lvl.level in ('collect','receipts')),(lvl.level='receipts')
  from public.socios s
  join lateral (select public.app_kombax_finance_level_socio_v057(s.id) level) lvl on true
  left join public.cuotas q on q.club_id=s.club_id and q.socio_id=s.id
  left join lateral (select coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0)::numeric pagado from public.pagos p where p.club_id=q.club_id and p.cuota_id=q.id) pa on true
  left join public.recibos_cuota rc on rc.club_id=q.club_id and rc.cuota_id=q.id
  where s.club_id=p_club_id and public.monitor_puede_ver_socio_v057(s.id) and lvl.level<>'none'
  order by s.apellidos,s.nombre,q.periodo desc nulls last;
$$;

create or replace function public.app_kombax_monitor_cobro_v057(
  p_cuota_id uuid,p_importe numeric,p_fecha date,p_metodo text,p_referencia text default null,p_observaciones text default null
) returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_cuota public.cuotas; v_pago public.pagos; v_previo numeric; v_restante numeric; v_pagado numeric; v_pagada boolean; v_perfil uuid; v_nombre text;
begin
  select * into v_cuota from public.cuotas where id=p_cuota_id for update;
  if v_cuota.id is null then raise exception 'Cuota no encontrada'; end if;
  if public.app_kombax_finance_level_socio_v057(v_cuota.socio_id) not in ('collect','receipts') then raise exception 'Tu ámbito no permite registrar cobros'; end if;
  if not public.monitor_puede_ver_socio_v057(v_cuota.socio_id) then raise exception 'Alumno fuera de tu ámbito'; end if;
  if coalesce(p_importe,0)<=0 then raise exception 'El importe debe ser mayor que cero'; end if;
  if p_metodo not in ('transferencia','bizum','efectivo','tarjeta','otro') then raise exception 'Método de pago no válido'; end if;
  if v_cuota.estado::text in ('pagada','anulada','exenta') then raise exception 'La cuota no admite cobros'; end if;
  select coalesce(sum(importe),0) into v_previo from public.pagos where cuota_id=v_cuota.id and estado_validacion='validado';
  v_restante:=greatest(v_cuota.importe-v_previo,0);
  if p_importe>v_restante+0.005 then raise exception 'El importe supera el saldo pendiente'; end if;
  insert into public.pagos(club_id,cuota_id,socio_id,importe,fecha,metodo,referencia,estado_validacion,validado_por,validado_en,observaciones,comunicado_por,comunicado_en)
  values(v_cuota.club_id,v_cuota.id,v_cuota.socio_id,p_importe,coalesce(p_fecha,current_date),p_metodo,nullif(trim(coalesce(p_referencia,'')),''),'validado',auth.uid(),now(),nullif(trim(coalesce(p_observaciones,'')),''),auth.uid(),now()) returning * into v_pago;
  select coalesce(sum(importe),0) into v_pagado from public.pagos where cuota_id=v_cuota.id and estado_validacion='validado';
  v_pagada:=v_pagado>=v_cuota.importe-0.005;
  update public.cuotas set estado=case when v_pagada then 'pagada'::public.estado_cuota else 'parcialmente_pagada'::public.estado_cuota end,
    avisos_pausados=v_pagada,motivo_pausa_avisos=case when v_pagada then 'Cobro registrado por monitor autorizado' else null end,
    avisos_pausados_hasta=null,avisos_pausados_por=case when v_pagada then auth.uid() else null end,avisos_pausados_en=case when v_pagada then now() else null end,actualizado_en=now()
  where id=v_cuota.id;
  insert into public.auditoria(club_id,usuario_id,accion,entidad,registro_id,datos_nuevos)
  values(v_cuota.club_id,auth.uid(),'MONITOR_COBRO','cuotas',v_cuota.id::text,jsonb_build_object('pago_id',v_pago.id,'importe',p_importe,'socio_id',v_cuota.socio_id));
  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(s.nombre||' '||s.apellidos) into v_perfil,v_nombre
  from public.socios s left join lateral(select tutor_perfil_id from public.tutores_socios where club_id=s.club_id and socio_id=s.id and contacto_principal order by id limit 1)t on true
  where s.id=v_cuota.socio_id and s.club_id=v_cuota.club_id;
  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(v_cuota.club_id,v_perfil,'pago-'||v_pago.id||'-validado','cuota','Pago registrado',v_nombre||': el cobro ha sido registrado correctamente.','fees',jsonb_build_object('cuota_id',v_cuota.id,'pago_id',v_pago.id),auth.uid())
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return to_jsonb(v_pago);
end; $$;

create or replace function public.app_kombax_ambitos_v057(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_puede_gestionar_ambitos_v057(p_club_id) then raise exception 'Sin permisos para gestionar ámbitos'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'id',a.id,'nombre',a.nombre,'tipo',a.tipo,'descripcion',a.descripcion,'activo',a.activo,
    'equipo',coalesce((select jsonb_agg(jsonb_build_object('perfil_id',ae.perfil_id,'nombre',trim(coalesce(p.nombre,'')||' '||coalesce(p.apellidos,'')),'responsable',ae.responsable,'finance_level',ae.finance_level,'ver_contacto',ae.ver_contacto,'gestionar_asistencia',ae.gestionar_asistencia,'gestionar_seguimiento',ae.gestionar_seguimiento)) from public.club_ambito_equipo ae left join public.perfiles p on p.id=ae.perfil_id where ae.ambito_id=a.id and ae.activo),'[]'::jsonb),
    'socios',coalesce((select jsonb_agg(jsonb_build_object('socio_id',ax.socio_id,'nombre',trim(s.nombre||' '||s.apellidos),'principal',ax.principal)) from public.club_ambito_socios ax join public.socios s on s.id=ax.socio_id and s.club_id=ax.club_id where ax.ambito_id=a.id and ax.activo),'[]'::jsonb),
    'grupos',coalesce((select jsonb_agg(jsonb_build_object('grupo_id',ag.grupo_id,'nombre',g.nombre)) from public.club_ambito_grupos ag join public.grupos g on g.id=ag.grupo_id and g.club_id=ag.club_id where ag.ambito_id=a.id and ag.activo),'[]'::jsonb)
  ) order by a.activo desc,a.nombre) from public.club_ambitos_trabajo a where a.club_id=p_club_id),'[]'::jsonb);
end; $$;

create or replace function public.app_kombax_ambito_mutate_v057(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_club uuid:=(p_payload->>'club_id')::uuid; v_ambito uuid; v_perfil uuid; v_socio uuid; v_grupo uuid; v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Sesión no válida'; end if;
  if p_request_id is null then raise exception 'request_id obligatorio'; end if;
  if v_club is null or not public.app_kombax_puede_gestionar_ambitos_v057(v_club) then raise exception 'Sin permisos para gestionar ámbitos'; end if;
  case p_operation
    when 'ambito.save' then
      v_ambito:=nullif(p_payload->>'id','')::uuid;
      if nullif(trim(coalesce(p_payload->>'nombre','')),'') is null then raise exception 'Nombre obligatorio'; end if;
      if v_ambito is null then
        insert into public.club_ambitos_trabajo(club_id,nombre,tipo,descripcion,activo,creado_por,actualizado_por)
        values(v_club,trim(p_payload->>'nombre'),coalesce(nullif(p_payload->>'tipo',''),'monitor'),nullif(trim(coalesce(p_payload->>'descripcion','')),''),coalesce((p_payload->>'activo')::boolean,true),auth.uid(),auth.uid()) returning id into v_ambito;
      else
        update public.club_ambitos_trabajo set nombre=trim(p_payload->>'nombre'),tipo=coalesce(nullif(p_payload->>'tipo',''),tipo),descripcion=nullif(trim(coalesce(p_payload->>'descripcion','')),''),activo=coalesce((p_payload->>'activo')::boolean,activo),actualizado_por=auth.uid(),actualizado_en=now() where id=v_ambito and club_id=v_club;
        if not found then raise exception 'Ámbito no encontrado'; end if;
      end if;
      v_result:=jsonb_build_object('id',v_ambito);
    when 'ambito.team.set' then
      v_ambito:=(p_payload->>'ambito_id')::uuid; v_perfil:=(p_payload->>'perfil_id')::uuid;
      if not exists(select 1 from public.club_ambitos_trabajo where id=v_ambito and club_id=v_club) then raise exception 'Ámbito no válido'; end if;
      if not exists(select 1 from public.miembros_club where club_id=v_club and perfil_id=v_perfil and activo and (rol in ('direccion','secretaria','economia','comunicacion','monitor') or coalesce(coordinacion,false))) then raise exception 'El usuario no pertenece al equipo operativo activo'; end if;
      insert into public.club_ambito_equipo(ambito_id,club_id,perfil_id,responsable,finance_level,ver_contacto,gestionar_asistencia,gestionar_seguimiento,activo,creado_por)
      values(v_ambito,v_club,v_perfil,coalesce((p_payload->>'responsable')::boolean,false),coalesce(nullif(p_payload->>'finance_level',''),'none'),coalesce((p_payload->>'ver_contacto')::boolean,false),coalesce((p_payload->>'gestionar_asistencia')::boolean,true),coalesce((p_payload->>'gestionar_seguimiento')::boolean,true),true,auth.uid())
      on conflict(ambito_id,perfil_id) do update set responsable=excluded.responsable,finance_level=excluded.finance_level,ver_contacto=excluded.ver_contacto,gestionar_asistencia=excluded.gestionar_asistencia,gestionar_seguimiento=excluded.gestionar_seguimiento,activo=true,actualizado_en=now();
      v_result:=jsonb_build_object('ambito_id',v_ambito,'perfil_id',v_perfil);
    when 'ambito.team.remove' then
      v_ambito:=(p_payload->>'ambito_id')::uuid; v_perfil:=(p_payload->>'perfil_id')::uuid;
      update public.club_ambito_equipo set activo=false,actualizado_en=now() where ambito_id=v_ambito and club_id=v_club and perfil_id=v_perfil;
      v_result:=jsonb_build_object('removed',found);
    when 'ambito.student.set' then
      v_ambito:=(p_payload->>'ambito_id')::uuid; v_socio:=(p_payload->>'socio_id')::uuid;
      if not exists(select 1 from public.socios where id=v_socio and club_id=v_club) then raise exception 'Alumno no válido'; end if;
      if coalesce((p_payload->>'principal')::boolean,false) then
        update public.club_ambito_socios set principal=false
        where club_id=v_club and socio_id=v_socio and ambito_id<>v_ambito and activo and principal;
      end if;
      insert into public.club_ambito_socios(ambito_id,club_id,socio_id,principal,origen,activo,creado_por)
      values(v_ambito,v_club,v_socio,coalesce((p_payload->>'principal')::boolean,false),'manual',true,auth.uid())
      on conflict(ambito_id,socio_id) do update set principal=excluded.principal,activo=true;
      v_result:=jsonb_build_object('ambito_id',v_ambito,'socio_id',v_socio);
    when 'ambito.student.remove' then
      v_ambito:=(p_payload->>'ambito_id')::uuid; v_socio:=(p_payload->>'socio_id')::uuid;
      update public.club_ambito_socios set activo=false where ambito_id=v_ambito and club_id=v_club and socio_id=v_socio;
      v_result:=jsonb_build_object('removed',found);
    when 'ambito.group.set' then
      v_ambito:=(p_payload->>'ambito_id')::uuid; v_grupo:=(p_payload->>'grupo_id')::uuid;
      if not exists(select 1 from public.grupos where id=v_grupo and club_id=v_club) then raise exception 'Grupo no válido'; end if;
      insert into public.club_ambito_grupos(ambito_id,club_id,grupo_id,activo,creado_por) values(v_ambito,v_club,v_grupo,true,auth.uid())
      on conflict(ambito_id,grupo_id) do update set activo=true;
      v_result:=jsonb_build_object('ambito_id',v_ambito,'grupo_id',v_grupo);
    when 'ambito.group.remove' then
      v_ambito:=(p_payload->>'ambito_id')::uuid; v_grupo:=(p_payload->>'grupo_id')::uuid;
      update public.club_ambito_grupos set activo=false where ambito_id=v_ambito and club_id=v_club and grupo_id=v_grupo;
      v_result:=jsonb_build_object('removed',found);
    else raise exception 'Operación de ámbito no soportada';
  end case;
  insert into public.auditoria(club_id,usuario_id,accion,entidad,registro_id,datos_nuevos)
  values(v_club,auth.uid(),upper(replace(p_operation,'.','_')),'club_ambitos_trabajo',coalesce(v_ambito::text,''),coalesce(p_payload,'{}'::jsonb)-'club_id');
  return jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
end; $$;

-- Las mutaciones operativas históricas respetan ahora los flags del ámbito.
create or replace function public.app_guardar_asistencia(p_sesion_id uuid,p_socio_id uuid,p_estado public.estado_asistencia,p_observacion text)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_sesion public.sesiones_entrenamiento; v_id uuid;
begin
  select * into v_sesion from public.sesiones_entrenamiento where id=p_sesion_id;
  if v_sesion.id is null then raise exception 'Sesión no encontrada'; end if;
  if not exists(select 1 from public.socio_disciplinas where club_id=v_sesion.club_id and socio_id=p_socio_id and grupo_id=v_sesion.grupo_id and activa) then raise exception 'El alumno no pertenece al grupo de la sesión'; end if;
  if not (public.tiene_rol_club(v_sesion.club_id,'direccion','secretaria') or public.app_kombax_monitor_puede_asistencia_v057(v_sesion.grupo_id)) then raise exception 'No tienes permiso para gestionar asistencia en este grupo'; end if;
  insert into public.asistencias(club_id,sesion_id,socio_id,estado,observacion,registrado_por)
  values(v_sesion.club_id,v_sesion.id,p_socio_id,p_estado,nullif(trim(coalesce(p_observacion,'')),''),auth.uid())
  on conflict(club_id,sesion_id,socio_id) do update set estado=excluded.estado,observacion=excluded.observacion,registrado_por=auth.uid(),registrado_en=now()
  returning id into v_id;
  return v_id;
end; $$;

create or replace function public.app_guardar_seguimiento(p_club_id uuid,p_socio_id uuid,p_tipo text,p_nota text,p_visibilidad public.visibilidad_seguimiento,p_fecha date default current_date)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid;
begin
  if not exists(select 1 from public.socios where id=p_socio_id and club_id=p_club_id) then raise exception 'Alumno no encontrado'; end if;
  if not (public.tiene_rol_club(p_club_id,'direccion','secretaria') or public.app_kombax_monitor_puede_seguimiento_v057(p_socio_id)) then raise exception 'No tienes permiso para registrar seguimiento'; end if;
  if nullif(trim(coalesce(p_tipo,'')),'') is null or nullif(trim(coalesce(p_nota,'')),'') is null then raise exception 'Tipo y nota son obligatorios'; end if;
  insert into public.seguimiento(club_id,socio_id,tipo,nota,visibilidad,registrado_por,fecha)
  values(p_club_id,p_socio_id,trim(p_tipo),trim(p_nota),coalesce(p_visibilidad,'equipo'::public.visibilidad_seguimiento),auth.uid(),coalesce(p_fecha,current_date))
  returning id into v_id;
  return v_id;
end; $$;

-- La generación recurrente ya no es una operación global para cualquier monitor.
-- Dirección/Secretaría procesa todo el club; un monitor, únicamente sus grupos.
create or replace function public.app_generar_sesiones_recurrentes(p_club_id uuid,p_horizonte_dias integer default 84)
returns integer language plpgsql security definer set search_path=public,auth as $$
declare v_count integer:=0; v_s public.series_sesiones; v_d date; v_elevated boolean; v_service boolean:=coalesce(current_setting('request.jwt.claim.role',true),'')='service_role';
begin
  if not v_service and (auth.uid() is null or not public.es_miembro_club(p_club_id)) then raise exception 'Sin contexto de club'; end if;
  v_elevated:=v_service or public.tiene_rol_club(p_club_id,'direccion','secretaria');
  if not v_elevated and not public.tiene_rol_club(p_club_id,'monitor') then raise exception 'No tienes permiso para generar sesiones'; end if;
  if p_horizonte_dias<7 or p_horizonte_dias>180 then p_horizonte_dias:=84; end if;
  for v_s in select * from public.series_sesiones where club_id=p_club_id and activa and (v_elevated or public.monitor_asignado_a_grupo_v057(grupo_id)) loop
    for v_d in select gs::date from generate_series(greatest(current_date,v_s.fecha_inicio),least(current_date+p_horizonte_dias,coalesce(v_s.fecha_fin,current_date+p_horizonte_dias)),interval '1 day') gs
      where extract(isodow from gs)::int=any(v_s.dias_semana)
    loop
      insert into public.sesiones_entrenamiento(club_id,grupo_id,fecha,hora_inicio,hora_fin,monitor_nombre,estado,observacion_general,codigo_acceso,serie_id,sala)
      values(v_s.club_id,v_s.grupo_id,v_d,v_s.hora_inicio,v_s.hora_fin,v_s.monitor_nombre,'programada','Sesión recurrente',null,v_s.id,v_s.sala)
      on conflict do nothing;
      if found then v_count:=v_count+1; end if;
    end loop;
  end loop;
  return v_count;
end; $$;

-- Cierra dos mutaciones históricas que todavía aceptaban cualquier monitor del club.
create or replace function public.app_registrar_checkin(p_sesion_id uuid,p_socio_id uuid,p_codigo text,p_metodo text default 'codigo')
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_sesion public.sesiones_entrenamiento; v_acceso uuid;
begin
  select * into v_sesion from public.sesiones_entrenamiento where id=p_sesion_id for update;
  if v_sesion.id is null then raise exception 'Sesión no encontrada'; end if;
  if v_sesion.estado='cancelada' then raise exception 'La sesión está cancelada'; end if;
  if v_sesion.fecha<>current_date then raise exception 'El check-in solo está disponible el día de la sesión'; end if;
  if not (public.puede_aportar_pago_socio(p_socio_id) or public.tiene_rol_club(v_sesion.club_id,'direccion','secretaria') or public.app_kombax_monitor_puede_asistencia_v057(v_sesion.grupo_id)) then raise exception 'No tienes acceso a este alumno'; end if;
  if not exists(select 1 from public.socio_disciplinas where club_id=v_sesion.club_id and socio_id=p_socio_id and grupo_id=v_sesion.grupo_id and activa) then raise exception 'El alumno no está matriculado en este grupo'; end if;
  if nullif(v_sesion.codigo_acceso,'') is not null and upper(trim(coalesce(p_codigo,'')))<>upper(trim(v_sesion.codigo_acceso)) then raise exception 'El código de acceso no es correcto'; end if;
  if p_metodo not in ('codigo','qr','manual','nfc') then raise exception 'Método de acceso no válido'; end if;
  insert into public.registros_acceso_clase(club_id,sesion_id,socio_id,metodo,resultado,registrado_por)
  values(v_sesion.club_id,v_sesion.id,p_socio_id,p_metodo,'permitido',auth.uid())
  on conflict(club_id,sesion_id,socio_id) do update set resultado='permitido',registrado_en=now(),registrado_por=auth.uid() returning id into v_acceso;
  insert into public.asistencias(club_id,sesion_id,socio_id,estado,registrado_por)
  values(v_sesion.club_id,v_sesion.id,p_socio_id,'presente',auth.uid())
  on conflict(club_id,sesion_id,socio_id) do update set estado='presente',registrado_por=auth.uid(),registrado_en=now();
  return v_acceso;
end; $$;

create or replace function public.app_registrar_graduacion(p_club_id uuid,p_socio_id uuid,p_disciplina_id uuid,p_grado_id uuid,p_fecha date,p_examinador text,p_nota text)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid; v_anterior uuid; v_perfil uuid; v_alumno text; v_grado text;
begin
  if not (public.tiene_rol_club(p_club_id,'direccion','secretaria') or public.app_kombax_monitor_puede_seguimiento_v057(p_socio_id)) then raise exception 'No tienes permiso para registrar graduaciones'; end if;
  if not exists(select 1 from public.socios where club_id=p_club_id and id=p_socio_id) then raise exception 'Alumno no válido'; end if;
  if not exists(select 1 from public.socio_disciplinas where club_id=p_club_id and socio_id=p_socio_id and disciplina_id=p_disciplina_id and activa) then raise exception 'El alumno no tiene matrícula activa en esa disciplina'; end if;
  if not exists(select 1 from public.grados where club_id=p_club_id and id=p_grado_id and disciplina_id=p_disciplina_id and activo) then raise exception 'El grado no pertenece a la disciplina'; end if;
  select grado_id into v_anterior from public.socio_disciplinas where club_id=p_club_id and socio_id=p_socio_id and disciplina_id=p_disciplina_id and activa order by fecha_inicio desc,id desc limit 1;
  insert into public.graduaciones(club_id,socio_id,disciplina_id,grado_id,grado_anterior_id,fecha,examinador,nota,registrado_por)
  values(p_club_id,p_socio_id,p_disciplina_id,p_grado_id,v_anterior,coalesce(p_fecha,current_date),nullif(trim(coalesce(p_examinador,'')),''),nullif(trim(coalesce(p_nota,'')),''),auth.uid()) returning id into v_id;
  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(s.nombre||' '||s.apellidos),g.nombre into v_perfil,v_alumno,v_grado
  from public.socios s join public.grados g on g.id=p_grado_id and g.club_id=s.club_id
  left join lateral(select tutor_perfil_id from public.tutores_socios where club_id=s.club_id and socio_id=s.id and contacto_principal order by id limit 1)t on true
  where s.id=p_socio_id and s.club_id=p_club_id;
  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(p_club_id,v_perfil,'graduacion-'||v_id,'graduacion','Nuevo grado registrado',v_alumno||' ha alcanzado '||v_grado||'.','profile',jsonb_build_object('graduacion_id',v_id,'socio_id',p_socio_id,'disciplina_id',p_disciplina_id),auth.uid())
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return v_id;
end; $$;

create or replace function public.app_kombax_mi_progreso_v057(p_club_id uuid)
returns table(
  club_id uuid,socio_id uuid,nombre text,apellidos text,asistencias_presentes bigint,asistencias_registradas bigint,ultima_graduacion date,grado_actual text,observaciones_seguimiento bigint
) language sql stable security definer set search_path=public,auth as $$
  select s.club_id,s.id,s.nombre,s.apellidos,
    count(distinct a.id) filter(where a.estado='presente'),
    count(distinct a.id) filter(where a.estado in ('presente','ausente','ausencia_justificada','retraso')),
    max(gra.fecha),max(g.nombre) filter(where g.id=sd.grado_id),count(distinct seg.id)
  from public.socios s
  left join public.socio_disciplinas sd on sd.club_id=s.club_id and sd.socio_id=s.id and sd.activa
  left join public.grados g on g.club_id=s.club_id and g.id=sd.grado_id
  left join public.asistencias a on a.club_id=s.club_id and a.socio_id=s.id
  left join public.graduaciones gra on gra.club_id=s.club_id and gra.socio_id=s.id
  left join public.seguimiento seg on seg.club_id=s.club_id and seg.socio_id=s.id
  where s.club_id=p_club_id and public.monitor_puede_ver_socio_v057(s.id)
  group by s.club_id,s.id,s.nombre,s.apellidos
  order by s.apellidos,s.nombre;
$$;

-- Puerta histórica: intercepta operaciones de sesiones para que un monitor no
-- pueda mutar grupos ajenos mediante el SECURITY DEFINER legacy.
do $migration$
begin
  if to_regprocedure('public.app_mutate_v160_pre_work_scopes_057(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception '057: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_work_scopes_057;
  end if;
end
$migration$;
revoke all on function public.app_mutate_v160_pre_work_scopes_057(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_club uuid; v_group uuid; v_session uuid; v_series uuid;
begin
  if p_operation in ('sesion.excepcion.guardar','sesion.serie.guardar','sesion.serie.finalizar','sesiones.recurrentes.generar') then
    begin v_club:=nullif(p_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
    if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;
    if public.app_kombax_es_monitor_restringido_v057(v_club) then
      if p_operation='sesion.excepcion.guardar' then
        v_session:=nullif(p_payload->>'sesion_id','')::uuid;
        select grupo_id into v_group from public.sesiones_entrenamiento where club_id=v_club and id=v_session;
        if v_group is null or not public.monitor_asignado_a_grupo_v057(v_group) then raise exception 'MONITOR_SCOPE_REQUIRED'; end if;
      elsif p_operation='sesion.serie.guardar' then
        v_group:=nullif(p_payload->>'grupo_id','')::uuid;
        if v_group is null or not public.monitor_asignado_a_grupo_v057(v_group) then raise exception 'MONITOR_SCOPE_REQUIRED'; end if;
      elsif p_operation='sesion.serie.finalizar' then
        v_series:=nullif(p_payload->>'serie_id','')::uuid;
        select grupo_id into v_group from public.series_sesiones where club_id=v_club and id=v_series;
        if v_group is null or not public.monitor_asignado_a_grupo_v057(v_group) then raise exception 'MONITOR_SCOPE_REQUIRED'; end if;
      end if;
      -- sesiones.recurrentes.generar queda acotada dentro de app_generar_sesiones_recurrentes.
    end if;
  end if;
  return public.app_mutate_v160_pre_work_scopes_057(p_operation,p_payload,p_request_id);
end; $$;

revoke all on function public.app_kombax_puede_gestionar_ambitos_v057(uuid) from public,anon;
revoke all on function public.app_kombax_es_monitor_restringido_v057(uuid) from public,anon;
revoke all on function public.monitor_asignado_a_grupo_v057(uuid) from public,anon;
revoke all on function public.monitor_puede_ver_socio_v057(uuid) from public,anon;
revoke all on function public.app_kombax_monitor_puede_asistencia_v057(uuid) from public,anon;
revoke all on function public.app_kombax_monitor_puede_asistencia_socio_v057(uuid) from public,anon;
revoke all on function public.app_kombax_monitor_puede_asistencia_registro_v057(uuid,uuid) from public,anon;
revoke all on function public.app_kombax_monitor_puede_seguimiento_v057(uuid) from public,anon;
revoke all on function public.app_kombax_finance_level_socio_v057(uuid) from public,anon;
revoke all on function public.app_kombax_mi_ambito_v057(uuid) from public,anon;
revoke all on function public.app_kombax_mis_alumnos_v057(uuid) from public,anon;
revoke all on function public.app_kombax_mi_cartera_v057(uuid) from public,anon;
revoke all on function public.app_kombax_mi_progreso_v057(uuid) from public,anon;
revoke all on function public.app_kombax_monitor_cobro_v057(uuid,numeric,date,text,text,text) from public,anon;
revoke all on function public.app_kombax_ambitos_v057(uuid) from public,anon;
revoke all on function public.app_kombax_ambito_mutate_v057(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_puede_gestionar_ambitos_v057(uuid) to authenticated;
grant execute on function public.app_kombax_es_monitor_restringido_v057(uuid) to authenticated;
grant execute on function public.monitor_asignado_a_grupo_v057(uuid) to authenticated;
grant execute on function public.monitor_puede_ver_socio_v057(uuid) to authenticated;
grant execute on function public.app_kombax_monitor_puede_asistencia_v057(uuid) to authenticated;
grant execute on function public.app_kombax_monitor_puede_asistencia_socio_v057(uuid) to authenticated;
grant execute on function public.app_kombax_monitor_puede_asistencia_registro_v057(uuid,uuid) to authenticated;
grant execute on function public.app_kombax_monitor_puede_seguimiento_v057(uuid) to authenticated;
grant execute on function public.app_kombax_finance_level_socio_v057(uuid) to authenticated;
grant execute on function public.app_kombax_mi_ambito_v057(uuid) to authenticated;
grant execute on function public.app_kombax_mis_alumnos_v057(uuid) to authenticated;
grant execute on function public.app_kombax_mi_cartera_v057(uuid) to authenticated;
grant execute on function public.app_kombax_mi_progreso_v057(uuid) to authenticated;
grant execute on function public.app_kombax_monitor_cobro_v057(uuid,numeric,date,text,text,text) to authenticated;
grant execute on function public.app_kombax_ambitos_v057(uuid) to authenticated;
grant execute on function public.app_kombax_ambito_mutate_v057(text,jsonb,uuid) to authenticated;


revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;
revoke all on function public.app_guardar_asistencia(uuid,uuid,public.estado_asistencia,text) from public,anon;
grant execute on function public.app_guardar_asistencia(uuid,uuid,public.estado_asistencia,text) to authenticated;
revoke all on function public.app_guardar_seguimiento(uuid,uuid,text,text,public.visibilidad_seguimiento,date) from public,anon;
grant execute on function public.app_guardar_seguimiento(uuid,uuid,text,text,public.visibilidad_seguimiento,date) to authenticated;
revoke all on function public.app_generar_sesiones_recurrentes(uuid,integer) from public,anon;
grant execute on function public.app_generar_sesiones_recurrentes(uuid,integer) to authenticated,service_role;

grant select on public.club_ambitos_trabajo,public.club_ambito_equipo,public.club_ambito_socios,public.club_ambito_grupos to authenticated;

notify pgrst,'reload schema';
commit;
