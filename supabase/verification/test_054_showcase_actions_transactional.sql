begin;
select count(*)>=0 as published_showcase_readable from public.kombax_showcase_elementos where estado='publicado';
select count(*)>=0 as saved_table_readable from public.kombax_showcase_guardados;
rollback;
