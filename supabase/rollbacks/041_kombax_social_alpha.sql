-- Rollback conservador 041: cierra la superficie RPC y conserva contenido/auditoría.
begin;
revoke execute on function public.app_kombax_social_mutate_v041(text,jsonb,uuid) from authenticated;
revoke execute on function public.app_kombax_social_contactos_v041() from authenticated;
revoke execute on function public.app_kombax_social_directorio_v041(text,integer) from authenticated;
revoke execute on function public.app_kombax_social_feed_v041(timestamptz,uuid,integer) from authenticated;
revoke execute on function public.app_kombax_social_mis_perfiles_v041() from authenticated;
revoke execute on function public.app_kombax_social_estado_v041(uuid) from authenticated;
revoke execute on function public.app_kombax_social_contactable_v041(uuid) from authenticated;
revoke execute on function public.app_kombax_social_puede_publicar_v041(uuid) from authenticated;
revoke execute on function public.app_kombax_social_acceso_v041() from authenticated;
drop function if exists public.app_runtime_contract_v160(uuid);
alter function public.app_runtime_contract_v160_pre_kombax_social_041(uuid) rename to app_runtime_contract_v160;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;
drop trigger if exists kombax_social_likes_count_v041 on public.kombax_social_likes;
drop trigger if exists directos_sync_kombax_social_v041 on public.perfiles_kombax_directos;
drop trigger if exists identidades_sync_kombax_social_v041 on public.identidades_sociales;
drop trigger if exists clubes_sync_kombax_social_v041 on public.clubes;
update public.textos_legales set vigente=false where tipo='comunidad_general' and version='1.1.0';
update public.textos_legales set vigente=true where tipo='comunidad_general' and version='1.0.0';
notify pgrst,'reload schema';
commit;

-- Las tablas 041 y sus filas se conservan deliberadamente para no destruir
-- publicaciones, solicitudes, denuncias ni auditoría durante una reversión.
