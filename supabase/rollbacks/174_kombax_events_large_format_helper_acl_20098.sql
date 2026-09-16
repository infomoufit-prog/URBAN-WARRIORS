-- Rollback 174 only: restore the helper endpoints to the 173 grants.
begin;
grant execute on function public.app_kombax_evento_inscripciones_estado_v173(uuid) to anon, authenticated;
grant execute on function public.app_kombax_evento_entradas_estado_v173(uuid) to anon, authenticated;
commit;
