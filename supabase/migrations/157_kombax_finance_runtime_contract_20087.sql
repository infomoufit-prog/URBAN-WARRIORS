-- KOMBAX RC13 build 20087 · advertise finance lifecycle mutation in runtime contract.
do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_finance_explorer_157(uuid)') is null then
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_finance_explorer_157;
  end if;
end
$contract$;
revoke all on function public.app_runtime_contract_v160_pre_finance_explorer_157(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $function$
declare v_base jsonb;
begin
  v_base:=public.app_runtime_contract_v160_pre_finance_explorer_157(p_club_id);
  if not (coalesce(v_base->'operations','[]'::jsonb) @> '["finance.documento.estado"]'::jsonb) then
    v_base:=jsonb_set(v_base,'{operations}',coalesce(v_base->'operations','[]'::jsonb)||jsonb_build_array('finance.documento.estado'),true);
  end if;
  return v_base;
end $function$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;
