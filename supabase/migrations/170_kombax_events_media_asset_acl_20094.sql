-- KOMBAX RC13 build 20.094 · 170 · Media asset RPC least privilege
begin;
revoke all on function public.app_kombax_evento_media_asset_v165(uuid) from public,anon,authenticated;
grant execute on function public.app_kombax_evento_media_asset_v165(uuid) to service_role;
comment on function public.app_kombax_evento_media_asset_v165(uuid) is 'Internal asset resolver for event-media-url; service_role only.';
commit;
