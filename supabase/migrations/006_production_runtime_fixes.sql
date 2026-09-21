-- ============================================================================
-- URBAN WARRIORS · FASE 1.2.2
-- Ajustes de producción: campos auxiliares, altas desde secretaría y medios.
-- Aplicar después de 005_security_hardening.sql.
-- ============================================================================

-- 1. Campos prácticos usados por la interfaz del club.
alter table public.socios add column if not exists tutor_nombre text;
alter table public.socios add column if not exists grado_texto text;
alter table public.material_catalogo add column if not exists stock integer not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'material_catalogo_stock_no_negativo'
      and conrelid = 'public.material_catalogo'::regclass
  ) then
    alter table public.material_catalogo
      add constraint material_catalogo_stock_no_negativo check (stock >= 0);
  end if;
end $$;

-- 2. Dirección y secretaría pueden registrar preinscripciones manuales.
drop policy if exists preinscripciones_crear_equipo on public.preinscripciones;
create policy preinscripciones_crear_equipo on public.preinscripciones
for insert to authenticated
with check (public.tiene_rol_club(club_id,'direccion','secretaria'));

-- 3. Bucket público para carteles, publicaciones y catálogo de material.
do $$
begin
  insert into storage.buckets(
    id, name, public, file_size_limit, allowed_mime_types
  ) values (
    'club-public-media',
    'club-public-media',
    true,
    5242880,
    array['image/jpeg','image/png','image/webp','image/gif']
  )
  on conflict (id) do update set
    public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;
exception when undefined_table then
  null;
end $$;

-- Lectura pública: el bucket está destinado a imágenes visibles en la app.
drop policy if exists club_public_media_read on storage.objects;
create policy club_public_media_read on storage.objects
for select using (bucket_id = 'club-public-media');

-- Escritura limitada a personal autorizado del club indicado en la primera carpeta.
drop policy if exists club_public_media_insert on storage.objects;
create policy club_public_media_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'club-public-media'
  and array_length(storage.foldername(name), 1) >= 2
  and public.tiene_rol_club(
    ((storage.foldername(name))[1])::uuid,
    'direccion','secretaria','economia','comunicacion'
  )
);

drop policy if exists club_public_media_update on storage.objects;
create policy club_public_media_update on storage.objects
for update to authenticated
using (
  bucket_id = 'club-public-media'
  and public.tiene_rol_club(
    ((storage.foldername(name))[1])::uuid,
    'direccion','secretaria','economia','comunicacion'
  )
)
with check (
  bucket_id = 'club-public-media'
  and public.tiene_rol_club(
    ((storage.foldername(name))[1])::uuid,
    'direccion','secretaria','economia','comunicacion'
  )
);

drop policy if exists club_public_media_delete on storage.objects;
create policy club_public_media_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'club-public-media'
  and public.tiene_rol_club(
    ((storage.foldername(name))[1])::uuid,
    'direccion','secretaria','economia','comunicacion'
  )
);

-- 4. Facilita que dirección/secretaría consulten nombres de perfiles vinculados.
drop policy if exists perfiles_lectura_equipo on public.perfiles;
create policy perfiles_lectura_equipo on public.perfiles
for select to authenticated
using (
  id = auth.uid()
  or exists (
    select 1
    from public.miembros_club mc_usuario
    join public.miembros_club mc_objetivo
      on mc_objetivo.club_id = mc_usuario.club_id
     and mc_objetivo.perfil_id = public.perfiles.id
    where mc_usuario.perfil_id = auth.uid()
      and mc_usuario.activo
      and mc_usuario.rol in ('direccion','secretaria')
  )
);

-- 5. La audiencia de las publicaciones se respeta también en la base de datos.
drop policy if exists comunicaciones_lectura on public.comunicaciones;
create policy comunicaciones_lectura on public.comunicaciones
for select to authenticated
using (
  public.tiene_rol_club(club_id,'direccion','secretaria','economia','comunicacion')
  or (
    public.es_miembro_club(club_id)
    and (
      estado = 'publicada'
      or (estado = 'programada' and coalesce(programada_para,evento_fecha,now()) <= now())
    )
    and (
      audiencia = 'todos'
      or (audiencia = 'familias' and public.tiene_rol_club(club_id,'familia','alumno'))
      or (audiencia = 'monitores' and public.tiene_rol_club(club_id,'monitor'))
    )
  )
);
