-- Prueba estructural reversible. No publica contenido persistente.
begin;
do $test$
begin
  if to_regclass('public.kombax_showcase_marcas') is null or to_regclass('public.kombax_showcase_elementos') is null then raise exception '042_TEST: falta modelo Showcase';end if;
  if to_regprocedure('public.app_kombax_showcase_list_v042(text,text,timestamp with time zone,uuid,integer)') is null then raise exception '042_TEST: falta lectura pública';end if;
  if has_table_privilege('authenticated','public.kombax_showcase_elementos','SELECT') then raise exception '042_TEST: lectura directa inesperada';end if;
  if not public.app_kombax_showcase_url_v042('https://example.invalid/info') or public.app_kombax_showcase_url_v042('http://example.invalid') then raise exception '042_TEST: guard HTTPS incorrecto';end if;
  if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname like 'kombax_showcase_%' and c.relname ~ '(carrito|pedido|pago|envio|devolucion|stock|checkout)') then raise exception '042_TEST: dominio comercial no autorizado';end if;
end
$test$;
select '042_TRANSACTIONAL_STRUCTURE' resultado,'PASS' estado;
rollback;
