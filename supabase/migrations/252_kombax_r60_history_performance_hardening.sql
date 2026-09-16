-- KOMBAX 20.110 R60 · history deletion/listing performance hardening
-- Narrow, additive indexes used by R60 exact-owner history listing and cleanup.

begin;

create index if not exists tickets_user_tenant_updated_r60_idx
  on kombax_customer_ops.tickets(user_ref, tenant_ref, updated_at desc);

create index if not exists email_outbox_ticket_r60_idx
  on kombax_customer_ops.email_outbox(ticket_id)
  where ticket_id is not null;

commit;
