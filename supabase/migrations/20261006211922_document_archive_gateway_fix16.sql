-- Preserve the existing mutation contract, permissions, idempotency and audit.
-- Enable the lifecycle guard only around the validated document archive branch.
do $fix$
declare d text; old_branch text; new_branch text;
begin
 select pg_get_functiondef('public.app_mutate_v160_v163(text,jsonb,uuid)'::regprocedure) into d;
 if position('v_document_gateway_fix16' in d)>0 then return;end if;
 d:=replace(d,'v_doc public.documentos_socios;','v_doc public.documentos_socios; v_document_gateway_fix16 text:=coalesce(current_setting(''kombax.lifecycle_gateway'',true),'''');');
 old_branch:=$old$      v_id := (v_payload->>'documento_id')::uuid;
      update public.documentos_socios set
        estado=case when coalesce(v_payload->>'estado','archivado')='sustituido' then 'sustituido' else 'archivado' end,$old$;
 new_branch:=$new$      v_id := (v_payload->>'documento_id')::uuid;
      perform set_config('kombax.lifecycle_gateway','on',true);
      update public.documentos_socios set
        estado=case when coalesce(v_payload->>'estado','archivado')='sustituido' then 'sustituido' else 'archivado' end,$new$;
 if position(old_branch in replace(d,chr(13),''))=0 then raise exception 'UNEXPECTED_DOCUMENT_ARCHIVE_DEFINITION';end if;
 d:=replace(replace(d,chr(13),''),old_branch,new_branch);
 d:=replace(d,$old$      v_result:=jsonb_build_object('id',v_id,'storage_path',v_path,'estado',coalesce(v_payload->>'estado','archivado'));$old$,
 $new$      perform set_config('kombax.lifecycle_gateway',v_document_gateway_fix16,true);
      v_result:=jsonb_build_object('id',v_id,'storage_path',v_path,'estado',coalesce(v_payload->>'estado','archivado'));$new$);
 d:=replace(d,'exception when others then'||chr(10)||'  -- No dejar',$new$exception when others then
  if p_operation='documento.archivar' then perform set_config('kombax.lifecycle_gateway',v_document_gateway_fix16,true);end if;
  -- No dejar$new$);
 execute d;
end $fix$;
