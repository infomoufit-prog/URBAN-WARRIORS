select 'clubes' control,to_regclass('public.clubes') is not null ok;
select 'miembros_club.coordinacion' control,exists(
  select 1 from information_schema.columns where table_schema='public' and table_name='miembros_club' and column_name='coordinacion'
) ok;
select 'perfiles' control,to_regclass('public.perfiles') is not null ok;
select 'auth.uid' control,to_regprocedure('auth.uid()') is not null ok;
