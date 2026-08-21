-- Rollback seguro 107 · KOMBAX build 20063.
-- Retira los endpoints v107 sin destruir conversaciones ni snapshots.
-- Las columnas/canales y la compatibilidad v104/v106 se conservan deliberadamente para
-- que la build 20062 desplegada siga viendo únicamente Social y no se pierda historial Showcase.
begin;

revoke all on function public.app_kombax_header_summary_v107(uuid) from public,anon,authenticated;
revoke all on function public.app_kombax_header_activity_v107() from public,anon,authenticated;
revoke all on function public.app_kombax_contactos_v107() from public,anon,authenticated;
revoke all on function public.app_kombax_social_network_mutate_v107(text,jsonb,uuid) from public,anon,authenticated;

drop function if exists public.app_kombax_header_summary_v107(uuid);
drop function if exists public.app_kombax_header_activity_v107();
drop function if exists public.app_kombax_contactos_v107();
drop function if exists public.app_kombax_social_network_mutate_v107(text,jsonb,uuid);

-- No se eliminan canal/showcase_* ni los índices por canal. Son datos/garantías de compatibilidad.
-- Tampoco se recrea el índice global v065: varias consultas Showcase de una misma pareja podrían
-- hacerlo imposible sin cerrar o eliminar datos.
notify pgrst,'reload schema';
commit;
