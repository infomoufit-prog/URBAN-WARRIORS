-- Roll back 090 only to the state after 089 (common CRUD/USAGE already revoked;
-- ancillary historical defaults restored).
begin;
alter default privileges for role postgres in schema public
  grant truncate, references, trigger on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant update on sequences to anon, authenticated, service_role;
commit;
