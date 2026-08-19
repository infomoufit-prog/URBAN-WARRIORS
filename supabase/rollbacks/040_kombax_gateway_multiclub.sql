-- Rollback conservador: cierra las APIs 040 sin borrar identidades, suscripciones ni capacidades.
begin;
revoke execute on function public.app_buscar_clubes_kombax_v040(text,integer) from anon,authenticated;
revoke execute on function public.app_mis_contextos_kombax_v040() from authenticated;
drop function if exists public.app_buscar_clubes_kombax_v040(text,integer);
drop function if exists public.app_mis_contextos_kombax_v040();
commit;
