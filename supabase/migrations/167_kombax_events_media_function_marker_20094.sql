-- Mirrors live 20260827015338 marker migration. No schema change.
begin;
comment on function public.app_kombax_evento_media_asset_v165(uuid) is 'Edge event-media-url firma solo assets visibles de KOMBAX Eventos.';
commit;
