-- Verificación build 20040 · cobertura de FK del agregado Contacto KOMBAX.
with fk as (
  select con.conname,con.conrelid,con.conkey
  from pg_constraint con
  where con.contype='f'
    and con.conrelid in ('public.kombax_social_contactos'::regclass,'public.kombax_social_contacto_mensajes'::regclass)
)
select fk.conname,c.relname as table_name,
       exists(
         select 1 from pg_index i
         where i.indrelid=fk.conrelid and i.indisvalid and i.indisready
           and (i.indkey::smallint[])[0:cardinality(fk.conkey)-1] @> fk.conkey
       ) as has_covering_index
from fk join pg_class c on c.oid=fk.conrelid
order by table_name,conname;
