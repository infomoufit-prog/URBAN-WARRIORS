-- Rollback conservador: restaura el gateway anterior; conserva paths y eleva solo capacidad del bucket.
begin;
do $rollback$
declare v_definition text;
begin
  if to_regprocedure('public.app_mutate_v160_pre_video_029(text,jsonb,uuid)') is null then
    raise exception 'Rollback 029 no disponible';
  end if;
  select pg_get_functiondef('public.app_mutate_v160_pre_video_029(text,jsonb,uuid)'::regprocedure) into v_definition;
  v_definition:=regexp_replace(v_definition,
    'CREATE OR REPLACE FUNCTION public\.app_mutate_v160_pre_video_029\(',
    'CREATE OR REPLACE FUNCTION public.app_mutate_v160(');
  execute v_definition;
end
$rollback$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
