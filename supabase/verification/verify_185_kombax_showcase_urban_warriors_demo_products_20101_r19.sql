-- KOMBAX R19 verification · Urban Warriors Showcase demo products
select
  count(*) as demo_items,
  count(distinct e.imagen_url) as unique_images,
  count(*) filter(where e.estado='publicado') as published_items,
  count(*) filter(where e.cta_tipo='contact' and e.cta_label='Me interesa') as contact_items,
  count(*) filter(where m.club_id='11111111-1111-4111-8111-111111111111'::uuid) as urban_owned_items
from public.kombax_showcase_elementos e
join public.kombax_showcase_marcas m on m.id=e.marca_id
where e.slug in (
  'urban-warriors-casco-integral-pro-r19-demo',
  'urban-warriors-guantes-integrales-elite-r19-demo',
  'urban-performance-whey-recovery-r19-demo'
);

select e.slug,e.nombre,c.slug as categoria,e.precio_orientativo,e.moneda,e.estado,e.cta_tipo,e.cta_label,e.imagen_url,m.nombre as vendedor,m.club_id
from public.kombax_showcase_elementos e
join public.kombax_showcase_marcas m on m.id=e.marca_id
left join public.kombax_showcase_categorias c on c.id=e.categoria_id
where e.slug like '%r19-demo'
order by e.slug;
