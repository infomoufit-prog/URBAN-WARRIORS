begin;
select id,tipo,en_album,estado from public.kombax_social_media order by creado_en desc limit 5;
rollback;
