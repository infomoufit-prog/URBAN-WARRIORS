begin;
select to_regprocedure('public.app_kombax_release_contract_v056()') is not null as contract_present;
rollback;
