-- KOMBAX 20.101 R19 · Urban Warriors Showcase demo products
-- Idempotent production data seed. Uses the existing real Showcase brand for Urban Warriors.
begin;

do $$
declare
  v_brand uuid;
  v_actor uuid;
  v_cat_protecciones uuid;
  v_cat_equipamiento uuid;
  v_cat_nutricion uuid;
  v_base text := 'https://poggsobhtutbuagjiydc.supabase.co/storage/v1/object/public/kombax-public-media/23d246d2-7930-45b9-b09c-0086b9291166/showcase/bd18701c-d3fa-45a6-9f37-dc57d5a121de/r19-demo/';
begin
  select m.id,m.creada_por into v_brand,v_actor
  from public.kombax_showcase_marcas m
  where m.sujeto_tipo='club'
    and m.club_id='11111111-1111-4111-8111-111111111111'::uuid
    and m.slug='club-urban-warriors'
    and m.estado='publicada'
  order by m.creado_en
  limit 1;

  if v_brand is null or v_actor is null then
    raise exception 'R19_URBAN_WARRIORS_SHOWCASE_BRAND_REQUIRED';
  end if;

  if not exists (
    select 1 from public.kombax_social_perfiles sp
    where sp.sujeto_tipo='club'
      and sp.club_id='11111111-1111-4111-8111-111111111111'::uuid
      and sp.estado='activo' and sp.visible and sp.contacto_habilitado
  ) then
    raise exception 'R19_URBAN_WARRIORS_SOCIAL_CONTACT_REQUIRED';
  end if;

  select id into v_cat_protecciones from public.kombax_showcase_categorias where slug='protecciones' and activa limit 1;
  select id into v_cat_equipamiento from public.kombax_showcase_categorias where slug='equipamiento' and activa limit 1;
  select id into v_cat_nutricion from public.kombax_showcase_categorias where slug='nutricion' and activa limit 1;

  if v_cat_protecciones is null or v_cat_equipamiento is null or v_cat_nutricion is null then
    raise exception 'R19_SHOWCASE_CATEGORIES_REQUIRED';
  end if;

  insert into public.kombax_showcase_elementos(
    marca_id,categoria_id,slug,nombre,resumen,descripcion,imagen_url,galeria,
    precio_orientativo,moneda,visitar_url,donde_encontrar_url,contacto_url,
    estado,destacado,etiqueta_destacada,publicado_en,creado_por,actualizado_por,cta_tipo,cta_label
  ) values (
    v_brand,v_cat_protecciones,'urban-warriors-casco-integral-pro-r19-demo',
    'Casco Integral Urban Warriors Pro',
    'Casco integral de entrenamiento para sparring técnico y sesiones de contacto controlado.',
    'Producto ficticio de demostración Showcase de Urban Warriors. Casco integral con acolchado de alta densidad, cierre ajustable y cobertura reforzada en frente, pómulos y mentón. Pensado para entrenamiento técnico de boxeo, kickboxing y trabajo de contacto controlado. Tallas de ejemplo: S, M y L. Color: negro. Stock demostrativo: 12 unidades. Disponibilidad de ejemplo: recogida en Urban Warriors (Palafolls) y posibilidad de envío acordado directamente con el club. Las especificaciones son ilustrativas y no constituyen una certificación técnica ni de seguridad.',
    v_base||'urban-warriors-casco-integral-pro.webp','[]'::jsonb,
    79.90,'EUR',null,null,null,'publicado',false,null,now(),v_actor,v_actor,'contact','Me interesa'
  ) on conflict (marca_id,slug) do update set
    categoria_id=excluded.categoria_id,nombre=excluded.nombre,resumen=excluded.resumen,descripcion=excluded.descripcion,
    imagen_url=excluded.imagen_url,galeria=excluded.galeria,precio_orientativo=excluded.precio_orientativo,moneda=excluded.moneda,
    visitar_url=null,donde_encontrar_url=null,contacto_url=null,estado='publicado',destacado=false,etiqueta_destacada=null,
    publicado_en=coalesce(public.kombax_showcase_elementos.publicado_en,now()),actualizado_por=v_actor,actualizado_en=now(),
    cta_tipo='contact',cta_label='Me interesa';

  insert into public.kombax_showcase_elementos(
    marca_id,categoria_id,slug,nombre,resumen,descripcion,imagen_url,galeria,
    precio_orientativo,moneda,visitar_url,donde_encontrar_url,contacto_url,
    estado,destacado,etiqueta_destacada,publicado_en,creado_por,actualizado_por,cta_tipo,cta_label
  ) values (
    v_brand,v_cat_equipamiento,'urban-warriors-guantes-integrales-elite-r19-demo',
    'Guantes Integrales Urban Warriors Elite',
    'Guantes integrales de entrenamiento para striking, sparring ligero y trabajo técnico.',
    'Producto ficticio de demostración Showcase de Urban Warriors. Guantes de entrenamiento con diseño ergonómico, cierre reforzado de muñeca y acolchado orientado a sesiones regulares de striking y sparring técnico. Variantes de ejemplo: 12 oz, 14 oz y 16 oz. Color: negro. Stock demostrativo: 18 unidades. Disponibilidad de ejemplo: recogida en Urban Warriors (Palafolls) y posibilidad de envío acordado directamente con el club. Las características descritas son ilustrativas para la demostración de la ficha de producto.',
    v_base||'urban-warriors-guantes-integrales-elite.webp','[]'::jsonb,
    64.90,'EUR',null,null,null,'publicado',false,null,now(),v_actor,v_actor,'contact','Me interesa'
  ) on conflict (marca_id,slug) do update set
    categoria_id=excluded.categoria_id,nombre=excluded.nombre,resumen=excluded.resumen,descripcion=excluded.descripcion,
    imagen_url=excluded.imagen_url,galeria=excluded.galeria,precio_orientativo=excluded.precio_orientativo,moneda=excluded.moneda,
    visitar_url=null,donde_encontrar_url=null,contacto_url=null,estado='publicado',destacado=false,etiqueta_destacada=null,
    publicado_en=coalesce(public.kombax_showcase_elementos.publicado_en,now()),actualizado_por=v_actor,actualizado_en=now(),
    cta_tipo='contact',cta_label='Me interesa';

  insert into public.kombax_showcase_elementos(
    marca_id,categoria_id,slug,nombre,resumen,descripcion,imagen_url,galeria,
    precio_orientativo,moneda,visitar_url,donde_encontrar_url,contacto_url,
    estado,destacado,etiqueta_destacada,publicado_en,creado_por,actualizado_por,cta_tipo,cta_label
  ) values (
    v_brand,v_cat_nutricion,'urban-performance-whey-recovery-r19-demo',
    'Whey Protein Recovery Blend Urban Performance',
    'Producto de nutrición deportiva de demostración orientado al aporte proteico tras el entrenamiento.',
    'Producto ficticio de demostración Showcase de Urban Warriors. Preparado tipo whey pensado como ejemplo de nutrición deportiva para complementar el aporte de proteína de una dieta adaptada al entrenamiento. Sabor de ejemplo: chocolate. Formato de ejemplo: 907 g. Stock demostrativo: 20 unidades. Disponibilidad de ejemplo: recogida en Urban Warriors (Palafolls) y posibilidad de envío acordado directamente con el club. No se atribuyen valores nutricionales concretos a la imagen generada. Complemento alimenticio: no sustituye una dieta equilibrada y variada ni un estilo de vida saludable. La composición, alérgenos, dosis y etiquetado legal deberán corresponder al producto real antes de una comercialización efectiva.',
    v_base||'urban-performance-whey-recovery.webp','[]'::jsonb,
    49.90,'EUR',null,null,null,'publicado',false,null,now(),v_actor,v_actor,'contact','Me interesa'
  ) on conflict (marca_id,slug) do update set
    categoria_id=excluded.categoria_id,nombre=excluded.nombre,resumen=excluded.resumen,descripcion=excluded.descripcion,
    imagen_url=excluded.imagen_url,galeria=excluded.galeria,precio_orientativo=excluded.precio_orientativo,moneda=excluded.moneda,
    visitar_url=null,donde_encontrar_url=null,contacto_url=null,estado='publicado',destacado=false,etiqueta_destacada=null,
    publicado_en=coalesce(public.kombax_showcase_elementos.publicado_en,now()),actualizado_por=v_actor,actualizado_en=now(),
    cta_tipo='contact',cta_label='Me interesa';
end $$;

commit;
