select 'perfiles directos' control,to_regclass('public.perfiles_kombax_directos') is not null ok;
select 'capacidades' control,to_regclass('public.kombax_capacidades') is not null ok;
select 'suscripciones' control,to_regclass('public.kombax_suscripciones') is not null ok;
select 'entitlements' control,to_regclass('public.kombax_entitlements') is not null ok;
select 'directorio publico' control,to_regprocedure('public.app_buscar_clubes_kombax_v040(text,integer)') is not null ok;
select 'contextos propios' control,to_regprocedure('public.app_mis_contextos_kombax_v040()') is not null ok;
select 'tipos inválidos' control,count(*)=0 ok,count(*) detalle from public.perfiles_kombax_directos where tipo not in ('competidor','marca','federacion','espectador','profesional');
select 'sin perfiles directos públicos no activos' control,count(*)=0 ok,count(*) detalle from public.perfiles_kombax_directos where publico and estado<>'activo';
select 'sin checkout o precios' control,not exists(select 1 from information_schema.columns where table_schema='public' and table_name in ('perfiles_kombax_directos','kombax_suscripciones') and column_name in ('precio','importe','checkout_url')) ok;
