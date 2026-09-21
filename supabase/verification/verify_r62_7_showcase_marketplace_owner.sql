-- KOMBAX 20.110 R62.7 · non-mutating verification
select 'marketplace_tables' as check_name,
       count(*) = 7 as ok,
       array_agg(table_name order by table_name) as detail
from information_schema.tables
where table_schema='kombax_marketplace'
  and table_name in ('policy_documents','policy_acceptances','seller_applications','seller_events','buyer_identity_requests','buyer_identity_documents','buyer_events');

select 'qa_policies' as check_name,
       count(*) = 4 and bool_and(status='active') and bool_and(legal_review_status='pending') as ok,
       jsonb_agg(jsonb_build_object('code',policy_code,'version',version,'legal_review',legal_review_status) order by policy_code) as detail
from kombax_marketplace.policy_documents
where policy_code in ('marketplace_terms','seller_agreement','buyer_protection','prohibited_products');

select 'r627_security_definer_search_path' as check_name,
       count(*) >= 15 and bool_and(p.prosecdef) and bool_and(coalesce(array_to_string(p.proconfig,','),'') like '%search_path=%') as ok,
       jsonb_agg(jsonb_build_object('schema',n.nspname,'function',p.proname,'secdef',p.prosecdef,'config',p.proconfig) order by n.nspname,p.proname) as detail
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where (n.nspname='public' and p.proname like '%r627%')
   or (n.nspname='kombax_marketplace' and p.proname like '%r627%');

select 'checkout_gate_service_only' as check_name,
       has_function_privilege('service_role','public.app_showcase_checkout_gate_r627(uuid,uuid)','EXECUTE')
       and not has_function_privilege('authenticated','public.app_showcase_checkout_gate_r627(uuid,uuid)','EXECUTE')
       and not has_function_privilege('anon','public.app_showcase_checkout_gate_r627(uuid,uuid)','EXECUTE') as ok,
       'service_role only'::text as detail;

select 'marketplace_direct_table_access_blocked' as check_name,
       not has_schema_privilege('authenticated','kombax_marketplace','USAGE')
       and not has_schema_privilege('anon','kombax_marketplace','USAGE') as ok,
       'private schema; access through RPCs'::text as detail;

select 'platform_fee_zero' as check_name,
       not exists(select 1 from kombax_payments.platform_fee_rules where active) as ok,
       coalesce((select jsonb_agg(to_jsonb(x)) from (select id,scope_type,active from kombax_payments.platform_fee_rules where active) x),'[]'::jsonb) as detail;

select 'marketplace_no_synthetic_qa_data' as check_name,
       (select count(*) from kombax_marketplace.seller_applications)=0
       and (select count(*) from kombax_marketplace.buyer_identity_requests)=0
       and (select count(*) from kombax_marketplace.policy_acceptances)=0 as ok,
       jsonb_build_object(
         'seller_applications',(select count(*) from kombax_marketplace.seller_applications),
         'buyer_identity_requests',(select count(*) from kombax_marketplace.buyer_identity_requests),
         'policy_acceptances',(select count(*) from kombax_marketplace.policy_acceptances)
       ) as detail;

select 'r627_fk_indexes' as check_name,
       count(*) = 8 as ok,
       array_agg(indexname order by indexname) as detail
from pg_indexes
where schemaname='kombax_marketplace'
  and indexname in (
    'idx_marketplace_policy_acceptances_policy',
    'idx_marketplace_seller_apps_applicant',
    'idx_marketplace_seller_apps_base_verification',
    'idx_marketplace_seller_apps_reviewer',
    'idx_marketplace_seller_events_actor',
    'idx_marketplace_buyer_requests_reviewer',
    'idx_marketplace_buyer_docs_user',
    'idx_marketplace_buyer_events_actor'
  );
