-- New WORK prices are reference prices until the subscription checkout and webhook
-- are connected to the verified Stripe account. Keep existing contracts untouched.
begin;
update kombax_commercial.products_r98
set requestable=false
where product_code in ('club','premium') and requestable;
commit;
