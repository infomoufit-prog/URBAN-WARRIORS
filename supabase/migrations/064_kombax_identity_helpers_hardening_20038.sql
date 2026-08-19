-- KOMBAX RC13 build 20038 · 064 · hardening de helpers internos de identidad visual.
begin;

-- Estos helpers solo son consumidos desde RPC SECURITY DEFINER controladas.
-- No forman parte de la API pública directa y no necesitan EXECUTE para clientes.
revoke all on function public.app_kombax_social_avatar_url_v063(uuid) from public,anon,authenticated;
revoke all on function public.app_kombax_social_banner_url_v063(uuid) from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
