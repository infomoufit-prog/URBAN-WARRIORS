-- R20 verification: expected event=1, protagonist=1, internal community seed posts=2, all scoped to Urban Warriors.
select e.id,e.slug,e.tipo,e.nombre,e.estado,e.creador_club_id,e.organizador_nombre,e.cartel_url,e.banner_url
from public.kombax_eventos_publicos e where e.slug='urban-warriors-seminario-pro-muay-thai-adrian-serrano-demo';

select count(*) as protagonist_count
from public.kombax_evento_participantes_publicos p join public.kombax_eventos_publicos e on e.id=p.evento_id
where e.slug='urban-warriors-seminario-pro-muay-thai-adrian-serrano-demo' and p.nombre_publico='Adrián Serrano' and p.estado_inscripcion<>'retirada';

select count(*) as community_post_count, min(club_id)=max(club_id) as one_club_only
from public.publicaciones_comunidad
where media_path in ('demo-static:assets/demo-events/urban-warriors-muay-thai-seminar/poster.webp','demo-static:assets/demo-events/urban-warriors-muay-thai-seminar/album-01-clinch.webp') and ciclo_estado='activo';

select count(*) as cross_club_contamination
from public.publicaciones_comunidad p
where p.media_path like 'demo-static:assets/demo-events/urban-warriors-muay-thai-seminar/%'
  and p.club_id <> (select id from public.clubes where lower(trim(coalesce(slug,'')))='urban-warriors' limit 1);
