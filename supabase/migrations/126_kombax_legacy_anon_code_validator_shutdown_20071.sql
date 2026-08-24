-- KOMBAX RC13 build 20071 · 126
-- El frontend dejó de usar la validación anónima directa en 20.046.
-- Retiramos el oracle público; los flujos autenticados conservan la RPC segura.
begin;
revoke execute on function public.app_kombax_codigo_validar_v060(text,text,text) from anon;
notify pgrst,'reload schema';
commit;
