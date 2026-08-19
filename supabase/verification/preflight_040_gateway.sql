select 'perfil publico club 035' control,to_regclass('public.perfiles_club_publicos') is not null ok;
select 'branding 039' control,exists(select 1 from information_schema.columns where table_schema='public' and table_name='clubes' and column_name='branding_version') ok;
select 'membresias' control,to_regclass('public.miembros_club') is not null ok;
select 'coordinacion' control,exists(select 1 from information_schema.columns where table_schema='public' and table_name='miembros_club' and column_name='coordinacion') ok;
