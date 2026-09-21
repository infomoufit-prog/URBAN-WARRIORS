-- 027_community_cursor_index.sql
-- Índice estable por club/estado/fecha/id para paginación por cursor.

begin;
create index if not exists idx_comunidad_club_estado_cursor
  on public.publicaciones_comunidad(club_id,estado,creado_en desc,id desc);
commit;

select indexname,indexdef from pg_indexes
where schemaname='public' and indexname='idx_comunidad_club_estado_cursor';
