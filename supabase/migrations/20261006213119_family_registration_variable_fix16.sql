do $fix$ declare d text;begin
select pg_get_functiondef('public.app_mutate_v160_pre_lifecycle_133(text,jsonb,uuid)'::regprocedure) into d;
if position('v_registration_result_fix16' in d)>0 then return;end if;
if position('result jsonb;' in d)=0 then raise exception 'UNEXPECTED_REGISTRATION_VARIABLE';end if;
d:=replace(d,'result jsonb;','v_registration_result_fix16 jsonb;');
d:=replace(d,'result:=','v_registration_result_fix16:=');
d:=replace(d,'jsonb_set(result,','jsonb_set(v_registration_result_fix16,');
d:=replace(d,'set result=app_mutate_v160_pre_lifecycle_133.result where','set result=v_registration_result_fix16 where');
d:=replace(d,'set result=result where','set result=v_registration_result_fix16 where');
d:=replace(d,'return result;','return v_registration_result_fix16;');
execute d;
end $fix$;
