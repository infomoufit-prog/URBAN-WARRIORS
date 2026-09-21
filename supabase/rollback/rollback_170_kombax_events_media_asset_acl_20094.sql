begin;
revoke all on function public.app_kombax_evento_media_asset_v165(uuid) from service_role;
grant execute on function public.app_kombax_evento_media_asset_v165(uuid) to anon,authenticated;
commit;
