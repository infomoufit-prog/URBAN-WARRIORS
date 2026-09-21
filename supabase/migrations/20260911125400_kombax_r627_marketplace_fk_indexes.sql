-- KOMBAX 20.110 R62.7 · Marketplace FK performance closure
begin;
create index if not exists idx_marketplace_policy_acceptances_policy on kombax_marketplace.policy_acceptances(policy_code,policy_version);
create index if not exists idx_marketplace_seller_apps_applicant on kombax_marketplace.seller_applications(applicant_user_id);
create index if not exists idx_marketplace_seller_apps_base_verification on kombax_marketplace.seller_applications(base_verification_application_id);
create index if not exists idx_marketplace_seller_apps_reviewer on kombax_marketplace.seller_applications(reviewed_by);
create index if not exists idx_marketplace_seller_events_actor on kombax_marketplace.seller_events(actor_user_id);
create index if not exists idx_marketplace_buyer_requests_reviewer on kombax_marketplace.buyer_identity_requests(reviewed_by);
create index if not exists idx_marketplace_buyer_docs_user on kombax_marketplace.buyer_identity_documents(user_id);
create index if not exists idx_marketplace_buyer_events_actor on kombax_marketplace.buyer_events(actor_user_id);
commit;
