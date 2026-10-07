-- The validated access-code branch must persist its result, not resolve an ambiguous column/variable.
do $fix$ declare d text;begin
select pg_get_functiondef('public.app_mutate_v160_pre_lifecycle_133(text,jsonb,uuid)'::regprocedure) into d;
if position('set result=result where request_id=p_request_id' in d)>0 then
execute replace(d,'set result=result where request_id=p_request_id','set result=app_mutate_v160_pre_lifecycle_133.result where request_id=p_request_id');
elsif position('set result=app_mutate_v160_pre_lifecycle_133.result where request_id=p_request_id' in d)=0 then raise exception 'UNEXPECTED_REGISTRATION_GATEWAY';end if;
end $fix$;
