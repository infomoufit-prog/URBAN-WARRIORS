-- KOMBAX R72 / build 20123 live section 11
begin;
create index if not exists idx_r72_product_reviews_verified_order on kombax_reputation.product_reviews(verified_order_id) where verified_order_id is not null;
create index if not exists idx_r72_product_reviews_seller_response_by on kombax_reputation.product_reviews(seller_response_by) where seller_response_by is not null;
create index if not exists idx_r72_event_comments_user on kombax_reputation.event_comments(user_id,created_at desc);
create index if not exists idx_r72_event_reviews_user on kombax_reputation.event_reviews(user_id,updated_at desc);
create index if not exists idx_r72_event_reviews_organizer_response_by on kombax_reputation.event_reviews(organizer_response_by) where organizer_response_by is not null;
create index if not exists idx_r72_reports_resolved_by on kombax_reputation.reputation_reports(resolved_by) where resolved_by is not null;
commit;
