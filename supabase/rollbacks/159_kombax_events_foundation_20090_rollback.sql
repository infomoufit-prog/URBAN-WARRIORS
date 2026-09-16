-- Safe rollback 20.090: close public RPC surface but preserve all event rows.
begin;
revoke execute on function public.app_kombax_eventos_publicos_v159(text,text,text,integer) from anon,authenticated;
revoke execute on function public.app_kombax_evento_publico_detalle_v159(uuid) from anon,authenticated;
drop function if exists public.app_kombax_evento_publico_detalle_v159(uuid);
drop function if exists public.app_kombax_eventos_publicos_v159(text,text,text,integer);
-- public.kombax_eventos_publicos is intentionally NOT dropped: rollback must not erase event data.
commit;
