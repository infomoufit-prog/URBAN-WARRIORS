-- Release H: metadatos de imágenes optimizadas sin almacenar binarios en PostgreSQL.
begin;

alter table public.publicaciones_comunidad
  add column if not exists media_mime text,
  add column if not exists media_width integer,
  add column if not exists media_height integer,
  add column if not exists media_size_bytes bigint;

do $migration$
begin
  if to_regprocedure('public.app_mutate_v160_pre_media_028(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception '028: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_media_028;
  end if;
end
$migration$;
revoke all on function public.app_mutate_v160_pre_media_028(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_result jsonb;
  v_data jsonb;
  v_id uuid;
  v_mime text;
  v_width integer;
  v_height integer;
  v_bytes bigint;
begin
  v_result:=public.app_mutate_v160_pre_media_028(p_operation,p_payload,p_request_id);
  if p_operation<>'comunidad.publicar' then return v_result; end if;
  v_data:=coalesce(v_result->'data','{}'::jsonb);
  begin v_id:=nullif(v_data->>'id','')::uuid; exception when others then v_id:=null; end;
  if v_id is null then return v_result; end if;
  v_mime:=left(nullif(p_payload->>'media_mime',''),100);
  begin v_width:=nullif(p_payload->>'media_width','')::integer; exception when others then v_width:=null; end;
  begin v_height:=nullif(p_payload->>'media_height','')::integer; exception when others then v_height:=null; end;
  begin v_bytes:=nullif(p_payload->>'media_size_bytes','')::bigint; exception when others then v_bytes:=null; end;
  if v_width not between 1 and 20000 then v_width:=null; end if;
  if v_height not between 1 and 20000 then v_height:=null; end if;
  if v_bytes not between 1 and 52428800 then v_bytes:=null; end if;
  update public.publicaciones_comunidad set
    media_mime=v_mime,media_width=v_width,media_height=v_height,media_size_bytes=v_bytes
  where id=v_id;
  v_data:=v_data||jsonb_build_object('media_mime',v_mime,'media_width',v_width,'media_height',v_height,'media_size_bytes',v_bytes);
  v_result:=jsonb_set(v_result,'{data}',v_data,true);
  update public.app_mutation_requests set result=v_result where request_id=p_request_id;
  return v_result;
end
$$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;

select
  to_regprocedure('public.app_mutate_v160_pre_media_028(text,jsonb,uuid)') is not null as rollback_ok,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='publicaciones_comunidad' and column_name='media_size_bytes') as metadata_ok;
