-- KOMBAX R63 verification (read-only)
select to_regprocedure('public.app_kombax_commercial_purchase_eligibility_r63()') is not null as purchase_eligibility_rpc;
select to_regprocedure('public.app_showcase_checkout_gate_r627(uuid,uuid)') is not null as showcase_gate;
select to_regprocedure('public.app_event_ticket_checkout_gate_r628(uuid,uuid)') is not null as events_gate;
select to_regprocedure('public.app_kombax_commercial_report_r63(text,uuid,text,text,uuid)') is not null as notice_action;
select to_regprocedure('public.app_kombax_event_cancel_commercial_plan_r63(uuid,text,uuid)') is not null as cancellation_plan;
select to_regclass('kombax_compliance.legal_documents') is not null as legal_documents;
select to_regclass('kombax_compliance.commercial_cases') is not null as commercial_cases;
select column_name from information_schema.columns where table_schema='public' and table_name='kombax_showcase_elementos' and column_name in('manufacturer_name','eu_responsible_person','safety_warnings','safety_status') order by column_name;
select column_name from information_schema.columns where table_schema='kombax_payments' and table_name='event_ticket_orders' and column_name in('refund_state','refund_reason','stripe_refund_id') order by column_name;
