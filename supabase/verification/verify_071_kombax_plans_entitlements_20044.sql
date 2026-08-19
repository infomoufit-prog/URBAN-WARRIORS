select codigo,perfil_tipo,modalidad,requiere_checkout,activo from public.kombax_planes order by codigo;
select plan_codigo,recurso,limite from public.kombax_plan_limites order by plan_codigo,recurso;
select
  to_regclass('public.kombax_planes') is not null as plans_table,
  (select count(*) from public.kombax_planes where activo)>=4 as plans_seeded,
  exists(select 1 from public.kombax_plan_capacidades where plan_codigo='competidor_premium' and capacidad_clave='competitor.profile.advanced') as competitor_capability,
  exists(select 1 from public.kombax_plan_capacidades where plan_codigo='marca_profesional' and capacidad_clave='showcase.publish') as brand_showcase,
  exists(select 1 from public.kombax_plan_capacidades where plan_codigo='federacion_institucional' and capacidad_clave='federation.documents.publish') as federation_capability;
