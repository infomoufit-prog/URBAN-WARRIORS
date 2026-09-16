-- KOMBAX RC13 build 20.098 · 174 · Large Format helper RPC least privilege
-- Public clients consume these states through the v173 discovery/detail/slug readers.
-- Keep helper execution internal to SECURITY DEFINER owners; do not expose them as standalone API endpoints.
begin;

revoke all on function public.app_kombax_evento_inscripciones_estado_v173(uuid) from public, anon, authenticated;
revoke all on function public.app_kombax_evento_entradas_estado_v173(uuid) from public, anon, authenticated;

grant execute on function public.app_kombax_evento_inscripciones_estado_v173(uuid) to service_role;
grant execute on function public.app_kombax_evento_entradas_estado_v173(uuid) to service_role;

comment on function public.app_kombax_evento_inscripciones_estado_v173(uuid) is
  '20.098 internal registration-state helper. Public state is exposed only through the curated v173 event readers.';
comment on function public.app_kombax_evento_entradas_estado_v173(uuid) is
  '20.098 internal ticket-state helper. Public state is exposed only through the curated v173 event readers.';

notify pgrst,'reload schema';
commit;
