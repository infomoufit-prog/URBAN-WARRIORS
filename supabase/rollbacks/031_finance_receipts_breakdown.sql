-- Rollback conservador: retira automatismos 031 y conserva los datos derivados.
begin;
drop trigger if exists trg_clasificar_recibo_v031 on public.recibos_cuota;
drop function if exists public.trg_clasificar_recibo_v031();
drop function if exists public.app_finance_receipts_audit_v031();
-- Las columnas origen/concepto se conservan para no perder clasificación histórica.
notify pgrst,'reload schema';
commit;
