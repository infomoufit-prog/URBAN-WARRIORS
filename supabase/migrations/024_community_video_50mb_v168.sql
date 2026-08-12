-- Urban Warriors RC12 - aumento seguro del límite de vídeo de Comunidad a 50 MB.
-- Aditiva: no altera datos ni políticas RLS; únicamente ajusta el límite del bucket existente.

update storage.buckets
set file_size_limit = 52428800
where id = 'community-media';

-- Si el bucket no existiera por cualquier motivo, se crea con la misma configuración privada y MIME admitidos.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'community-media',
  'community-media',
  false,
  52428800,
  array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime']::text[]
)
on conflict(id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
