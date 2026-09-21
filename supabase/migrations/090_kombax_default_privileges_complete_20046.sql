-- KOMBAX 20.046 / 090
-- Complete deny-by-default for FUTURE public objects. 089 removed the common
-- Data API privileges, but PostgreSQL table/sequence ACLs still retained
-- ancillary privileges (TRUNCATE/REFERENCES/TRIGGER and sequence UPDATE).
begin;
alter default privileges for role postgres in schema public
  revoke all privileges on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all privileges on sequences from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all privileges on functions from public, anon, authenticated, service_role;
commit;
