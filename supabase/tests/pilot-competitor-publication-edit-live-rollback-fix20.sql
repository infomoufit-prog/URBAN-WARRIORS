begin;
do $seed$
declare n int; u uuid;
begin
for n in 1..6 loop
 u:=('18000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
 insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
 values(u,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','qa-pilot-fix18-'||n||'@example.invalid',now(),'{"provider":"email","providers":["email"]}','{"nombre":"QA Pilot","apellidos":"FIX18","fecha_nacimiento":"1990-01-01"}',now(),now());
 insert into public.kombax_account_private_r117(perfil_id,fecha_nacimiento)
 values(u,'1990-01-01') on conflict(perfil_id) do update set fecha_nacimiento='1990-01-01';
end loop;end $seed$;
set local role authenticated;
do $test$
declare n int; u uuid; r jsonb; d jsonb; sid uuid;
begin
for n in 1..6 loop
 u:=('18000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
 perform set_config('request.jwt.claim.sub',u::text,true);
 r:=public.app_kombax_perfil_mutate_r58('kombax.profile.save',jsonb_build_object('tipo','competidor','nombre_publico','QA Pilot FIX18 '||n,'disciplinas',jsonb_build_array('Boxeo','Kickboxing')),gen_random_uuid());
 d:=r->'data';
 if n<=5 then
  if d->>'verificacion_estado'<>'verificado' or d->>'verificacion_version'<>'pilot-owner-authorized-fix18' then raise exception 'PILOT_NOT_GRANTED % %',n,r;end if;
  r:=public.app_kombax_perfil_mutate_r58('kombax.profile.save',jsonb_build_object('perfil_directo_id',d->>'id','tipo','competidor','nombre_publico','QA Edited Pilot '||n,'descripcion','QA temporary biography','disciplinas',jsonb_build_array('Boxeo','Kickboxing')),gen_random_uuid());
  if r#>>'{data,nombre_publico}'<>'QA Edited Pilot '||n then raise exception 'PILOT_EDIT_FAILED';end if;
  perform public.app_kombax_social_mutate_v123('kombax.social.direct.activate',jsonb_build_object('perfil_directo_id',d->>'id','acepta_normas',true,'acepta_privacidad',true),gen_random_uuid());
  select id into sid from public.app_kombax_social_mis_perfiles_r117(null) where perfil_directo_id=(d->>'id')::uuid;
  r:=public.app_kombax_social_mutate_v123('kombax.social.publicar',jsonb_build_object('autor_perfil_id',sid,'tipo','actualizacion','texto','QA temporary pilot post','audiencia','publica'),gen_random_uuid());
  if r#>>'{data,id}' is null then raise exception 'PILOT_POST_FAILED';end if;
  perform public.app_kombax_profile_contacts_fix18(gen_random_uuid(),10);
  if (public.app_kombax_managed_profile_hub_v200((d->>'id')::uuid)->'profile'->>'id')<>d->>'id' then raise exception 'WORKSPACE_MISMATCH';end if;
  if exists(select b.capacidad_clave from public.kombax_profile_base_capabilities_v196 b where b.perfil_tipo='competidor'
    except select x.capacidad_clave from public.app_kombax_profile_capabilities_v196((d->>'id')::uuid) x) then raise exception 'COMPETITOR_CAPABILITIES_MISSING';end if;
 else
  if d->>'verificacion_estado'='verificado' then raise exception 'SIXTH_GRANTED';end if;
 end if;
end loop;
end $test$;
reset role;
do $count$
begin
if (select count(*) from kombax_pilot.competitor_grants)<>5 then raise exception 'CAPACITY_COUNT';end if;
if (select enabled from kombax_pilot.competitor_cohorts where id='competitor-pilot-five-fix18') then raise exception 'COHORT_NOT_CLOSED';end if;
end $count$;
select jsonb_build_object('first_five_enabled',true,'sixth_not_enabled',true,'free_social_read',true,'real_registration_rpc',true,'rollback',true) as qa;
rollback;


