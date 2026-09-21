-- KOMBAX RC13 build 20085 · targeted supporting indexes
-- Only indexes FKs introduced/used by Finance Premium and Security Go-Live.
-- Additive, no data rewrite.
begin;

create index if not exists idx_cuotas_ejecucion_v154
  on public.cuotas(generado_por_ejecucion_id)
  where generado_por_ejecucion_id is not null;

create index if not exists idx_finance_qa_shadow_runs_creado_por_v154
  on public.finance_qa_shadow_runs(creado_por)
  where creado_por is not null;

create index if not exists idx_informes_financieros_source_report_v154
  on public.informes_financieros(source_report_id)
  where source_report_id is not null;

create index if not exists idx_kombax_security_controls_verified_by_v154
  on public.kombax_security_controls_v149(verified_by)
  where verified_by is not null;

create index if not exists idx_kombax_security_settings_enabled_by_v154
  on public.kombax_security_settings_v149(enabled_by)
  where enabled_by is not null;

commit;
