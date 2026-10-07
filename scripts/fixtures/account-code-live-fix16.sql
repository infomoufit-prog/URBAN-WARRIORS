CREATE OR REPLACE FUNCTION public.app_mutate_v160_pre_lifecycle_133(p_operation text, p_payload jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare payload jsonb:=coalesce(p_payload,'{}'::jsonb); code text:=trim(coalesce(payload->>'invite_code','')); slug text:=trim(coalesce(payload->>'club_slug','')); chk jsonb; result jsonb;
begin
  if p_operation in ('invitacion.crear','invitacion.aceptar') then raise exception 'INVITATION_FLOW_DEPRECATED: usa los códigos permanentes del club';end if;
  if p_operation='cuenta.registrar' and code<>'' then
    chk:=public.app_kombax_codigo_validar_seguro_v086(slug,'alumnos',code);
    if coalesce((chk->>'valid')::boolean,false) is not true then
      return jsonb_build_object('ok',false,'operation',p_operation,'request_id',p_request_id,'error_code',case when coalesce((chk->>'rate_limited')::boolean,false) then 'KOMBAX_ACCESS_CODE_RATE_LIMIT' else 'KOMBAX_ACCESS_CODE_INVALID' end,'message',case when coalesce((chk->>'rate_limited')::boolean,false) then 'Demasiados intentos. Espera 15 minutos antes de volver a probar.' else 'Código de alumnos/familias no válido para este club.' end,'retry_after_seconds',coalesce((chk->>'retry_after_seconds')::integer,0));
    end if;
    payload:=jsonb_set(payload,'{invite_code}','null'::jsonb,true);
    result:=public.app_mutate_v160_pre_access_codes_060(p_operation,payload,p_request_id);
    result:=jsonb_set(result,'{data,club_access_code}',jsonb_build_object('tipo','alumnos','version',(chk->>'version')::integer),true);
    update public.app_mutation_requests set result=result where request_id=p_request_id;
    return result;
  end if;
  return public.app_mutate_v160_pre_access_codes_060(p_operation,p_payload,p_request_id);
end $function$
;
