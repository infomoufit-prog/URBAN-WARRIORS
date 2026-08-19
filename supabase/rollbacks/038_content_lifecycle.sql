-- Rollback compatible: impide nuevas transiciones sin borrar estados ni auditoría.
begin;
revoke execute on function public.app_ciclo_accion_v038(uuid,text,uuid[],text,text) from authenticated;
drop function if exists public.app_ciclo_accion_v038(uuid,text,uuid[],text,text);
-- Se conservan lector, columnas, auditoría y guardas para evitar pérdida o mutación directa.
commit;
