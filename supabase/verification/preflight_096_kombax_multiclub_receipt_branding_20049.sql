select
  to_regclass('public.clubes') is not null as clubes_ok,
  to_regclass('public.recibos_cuota') is not null as recibos_ok,
  to_regclass('public.perfiles_club_publicos') is not null as perfiles_publicos_ok,
  to_regprocedure('public.emitir_recibo_cuota(uuid)') is not null as emision_ok,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='clubes' and column_name='logo_url') as club_logo_ok,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='perfiles_club_publicos' and column_name='logo_url') as public_logo_ok,
  not has_table_privilege('anon','public.recibos_cuota','SELECT') as anon_sin_recibos,
  has_table_privilege('authenticated','public.recibos_cuota','SELECT') as auth_lectura_rls;
