-- KOMBAX RC13 build 20.094 · Result write-path hardening
-- Prevent legacy event.fight.save from mutating result fields. Results must use event.fight.result.set.
begin;
create or replace function public.app_kombax_eventos_mutate_v166(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
begin
  if p_operation='event.fight.save' then
    v_payload:=v_payload - array['resultado','metodo_resultado','ganador_participante_id','asalto','tiempo_resultado','resultado_estado','notas_publicas'];
  end if;
  return public.app_kombax_eventos_mutate_v165(p_operation,v_payload,p_request_id);
end $$;
revoke all on function public.app_kombax_eventos_mutate_v166(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v166(text,jsonb,uuid) to authenticated;
comment on function public.app_kombax_eventos_mutate_v166(text,jsonb,uuid) is '20.094 gateway: Fight Card edits cannot write results; event.fight.result.set is the only result write path.';
notify pgrst,'reload schema';
commit;
