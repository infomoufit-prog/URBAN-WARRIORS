-- Rollback conservador 042: cierra Showcase y conserva catálogo y auditoría.
begin;
revoke execute on function public.app_kombax_showcase_mutate_v042(text,jsonb,uuid) from authenticated;
revoke execute on function public.app_kombax_showcase_mis_marcas_v042() from authenticated;
revoke execute on function public.app_kombax_showcase_mis_elementos_v042(uuid) from authenticated;
revoke execute on function public.app_kombax_showcase_list_v042(text,text,timestamptz,uuid,integer) from anon,authenticated;
revoke execute on function public.app_kombax_showcase_categorias_v042() from anon,authenticated;
revoke execute on function public.app_kombax_showcase_puede_gestionar_v042(uuid) from authenticated;
drop trigger if exists showcase_validar_elemento_v042 on public.kombax_showcase_elementos;
drop trigger if exists showcase_validar_marca_v042 on public.kombax_showcase_marcas;
notify pgrst,'reload schema';
commit;

-- No se eliminan marcas, elementos ni gestores: una reversión operativa no debe
-- destruir contenido informativo que pueda restaurarse tras corregir la incidencia.
