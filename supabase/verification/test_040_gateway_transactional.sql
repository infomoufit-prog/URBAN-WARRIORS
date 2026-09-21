-- Prueba de contextos propios; revierte el perfil directo temporal.
begin;
do $$ declare v_uid uuid; v_ctx jsonb; v_profile uuid;
begin
  select perfil_id into v_uid from public.miembros_club where activo order by creado_en limit 1;
  if v_uid is null then raise exception 'TEST_FIXTURE_REQUIRED: falta membresía'; end if;
  perform set_config('request.jwt.claim.sub',v_uid::text,true);
  insert into public.perfiles_kombax_directos(perfil_id,tipo,slug,nombre_publico)
  values(v_uid,'competidor','test-'||replace(v_uid::text,'-',''), 'Perfil transaccional') returning id into v_profile;
  v_ctx:=public.app_mis_contextos_kombax_v040();
  if jsonb_array_length(v_ctx->'clubs')<1 then raise exception 'MEMBERSHIP_CONTEXT_MISSING'; end if;
  if not exists(select 1 from jsonb_array_elements(v_ctx->'direct_profiles') x where x->>'id'=v_profile::text) then raise exception 'DIRECT_PROFILE_CONTEXT_MISSING'; end if;
  if exists(select 1 from jsonb_array_elements(v_ctx->'direct_profiles') x where x->>'perfil_id' is not null) then raise exception 'PRIVATE_ID_EXPOSED'; end if;
end $$;
rollback;
