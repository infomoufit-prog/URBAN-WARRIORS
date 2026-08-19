-- KOMBAX RC13 build 20044 · 081 · internal RPC hardening
-- Los consumidores reciben badge/servicio/límites mediante APIs autorizadas; estos helpers quedan solo internos.

begin;
revoke execute on function public.app_kombax_badge_tipo_v069(uuid) from authenticated;
revoke execute on function public.app_kombax_badge_visible_v069(uuid) from authenticated;
revoke execute on function public.app_kombax_perfil_servicio_v071(uuid) from authenticated;
revoke execute on function public.app_kombax_perfil_servicio_activo_v071(uuid) from authenticated;
revoke execute on function public.app_kombax_plan_limite_v071(uuid,text) from authenticated;
notify pgrst,'reload schema';
commit;
