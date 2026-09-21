-- KOMBAX 20.110 R62.8 · Correct legal/operator identity to KOMBAX SPAIN
begin;

update kombax_marketplace.policy_documents
set body = replace(replace(body, ('Combats' || ' Spain'), 'KOMBAX SPAIN'), ('Combat' || ' Spain'), 'KOMBAX SPAIN'),
    updated_at = now()
where body ilike '%combat%spain%';

update kombax_commercial.event_contract_documents
set body = replace(replace(body, ('Combats' || ' Spain'), 'KOMBAX SPAIN'), ('Combat' || ' Spain'), 'KOMBAX SPAIN'),
    operator_name = 'KOMBAX SPAIN',
    updated_at = now()
where body ilike '%combat%spain%'
   or operator_name ilike '%combat%spain%';

notify pgrst,'reload schema';
commit;
