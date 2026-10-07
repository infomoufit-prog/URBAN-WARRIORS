begin;
insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('19000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','qa-member-fix19@example.invalid',now(),'{"provider":"email","providers":["email"]}','{"nombre":"QA","apellidos":"FIX19","fecha_nacimiento":"1990-01-01"}',now(),now());
insert into public.kombax_account_private_r117(perfil_id,fecha_nacimiento) values('19000000-0000-4000-8000-000000000002','1990-01-01') on conflict(perfil_id) do update set fecha_nacimiento='1990-01-01';
select set_config('request.jwt.claim.sub','19000000-0000-4000-8000-000000000002',true);
set local role authenticated;
do $test$
declare r jsonb;s uuid;blocked boolean:=false;
begin
r:=public.app_kombax_identity_mutate_v124('kombax.identity.member.activate','{"acepta_normas":true,"acepta_privacidad":true,"fecha_nacimiento":"1990-01-01"}',gen_random_uuid());
select id into s from public.app_kombax_social_mis_perfiles_r117(null) where sujeto_tipo='miembro' limit 1;
if s is null then raise exception 'MEMBER_IDENTITY_NOT_CREATED';end if;
begin perform public.app_kombax_social_mutate_v123('kombax.social.publicar',jsonb_build_object('autor_perfil_id',s,'tipo','actualizacion','texto','QA unlinked member forbidden','audiencia','publica'),gen_random_uuid());
exception when others then if SQLERRM like '%NOT_ALLOWED%' or SQLERRM like '%FORBIDDEN%' then blocked:=true;else raise;end if;end;
if not blocked then raise exception 'UNLINKED_MEMBER_PUBLISHED';end if;
end $test$;
select jsonb_build_object('member_without_approved_club_cannot_publish',true,'rollback',true) result;
rollback;
