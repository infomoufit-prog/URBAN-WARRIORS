-- Repair the existing request upsert: its unique request index is partial.
-- No new public RPC, entitlement or payment is created by this migration.
do $repair$
declare definition text; old_clause text := 'on conflict(request_id) do update set updated_at=now() returning id into v_id;';
begin
 select pg_get_functiondef('public.app_kombax_commercial_activation_request_r64(text,uuid,text,uuid,integer,uuid)'::regprocedure) into definition;
 if position(old_clause in definition)=0 then raise exception 'FIX19_ACTIVATION_SOURCE_MISMATCH';end if;
 execute replace(definition,old_clause,'on conflict(request_id) where request_id is not null do update set updated_at=now() returning id into v_id;');
end $repair$;
