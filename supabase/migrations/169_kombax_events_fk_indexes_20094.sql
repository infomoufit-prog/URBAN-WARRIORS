-- KOMBAX RC13 build 20.094 · 169 · FK indexes hardening
begin;
create index if not exists idx_kombax_evento_combates_resultado_actualizado_por_v169
  on public.kombax_evento_combates_publicos(resultado_actualizado_por)
  where resultado_actualizado_por is not null;
create index if not exists idx_kombax_evento_media_creado_por_v169
  on public.kombax_evento_media(creado_por);
commit;
