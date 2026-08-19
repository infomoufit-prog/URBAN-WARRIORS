select pg_get_userbyid(defaclrole) role_name,n.nspname,defaclobjtype,defaclacl::text
from pg_default_acl d left join pg_namespace n on n.oid=d.defaclnamespace
where pg_get_userbyid(defaclrole)='postgres' and n.nspname='public'
order by defaclobjtype;
