begin;
select set_config('request.jwt.claim.sub','369abf28-93d7-40a6-a589-cd10cae7ea67',true);
set local role authenticated;
do $qa$
declare payload jsonb; r jsonb;sid uuid;
begin
 select to_jsonb(p) into payload from public.app_perfil_club_publico_v132('4f5996fe-fe77-4f0b-b22c-06923b2e46a2') p;
 if payload is null then raise exception 'CLUB_PUBLIC_PROFILE_MISSING';end if;
 r:=public.app_mutate_v160('club_publico.guardar',payload||jsonb_build_object('club_id','4f5996fe-fe77-4f0b-b22c-06923b2e46a2','descripcion','QA biography reverted'),gen_random_uuid());
 if r#>>'{data,descripcion}'<>'QA biography reverted' then raise exception 'CLUB_PUBLIC_EDIT_FAILED';end if;
 select id into sid from public.app_kombax_social_mis_perfiles_r117('4f5996fe-fe77-4f0b-b22c-06923b2e46a2') where sujeto_tipo='club' and club_id='4f5996fe-fe77-4f0b-b22c-06923b2e46a2';
 r:=public.app_kombax_social_mutate_v123('kombax.social.publicar',jsonb_build_object('club_id','4f5996fe-fe77-4f0b-b22c-06923b2e46a2','autor_perfil_id',sid,'tipo','actualizacion','texto','QA pilot post reverted','audiencia','publica'),gen_random_uuid());
 if r#>>'{data,id}' is null then raise exception 'CLUB_PUBLICATION_FAILED';end if;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','f680963e-13cf-4d87-b405-a9435add0a7a',true);
set local role authenticated;
do $qa$
declare payload jsonb; r jsonb;sid uuid;
begin
 select to_jsonb(p) into payload from public.app_perfil_club_publico_v132('40caffb6-be7c-451e-abcf-5f8f35b516da') p;
 if payload is null then raise exception 'CLUB_PUBLIC_PROFILE_MISSING';end if;
 r:=public.app_mutate_v160('club_publico.guardar',payload||jsonb_build_object('club_id','40caffb6-be7c-451e-abcf-5f8f35b516da','descripcion','QA biography reverted'),gen_random_uuid());
 if r#>>'{data,descripcion}'<>'QA biography reverted' then raise exception 'CLUB_PUBLIC_EDIT_FAILED';end if;
 select id into sid from public.app_kombax_social_mis_perfiles_r117('40caffb6-be7c-451e-abcf-5f8f35b516da') where sujeto_tipo='club' and club_id='40caffb6-be7c-451e-abcf-5f8f35b516da';
 r:=public.app_kombax_social_mutate_v123('kombax.social.publicar',jsonb_build_object('club_id','40caffb6-be7c-451e-abcf-5f8f35b516da','autor_perfil_id',sid,'tipo','actualizacion','texto','QA pilot post reverted','audiencia','publica'),gen_random_uuid());
 if r#>>'{data,id}' is null then raise exception 'CLUB_PUBLICATION_FAILED';end if;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','b9333e3f-536a-47f9-9dfb-5a8ea74d30c4',true);
set local role authenticated;
do $qa$
declare payload jsonb; r jsonb;sid uuid;
begin
 select to_jsonb(p) into payload from public.app_perfil_club_publico_v132('47406610-b046-4738-bc98-b91cc06a70be') p;
 if payload is null then raise exception 'CLUB_PUBLIC_PROFILE_MISSING';end if;
 r:=public.app_mutate_v160('club_publico.guardar',payload||jsonb_build_object('club_id','47406610-b046-4738-bc98-b91cc06a70be','descripcion','QA biography reverted'),gen_random_uuid());
 if r#>>'{data,descripcion}'<>'QA biography reverted' then raise exception 'CLUB_PUBLIC_EDIT_FAILED';end if;
 select id into sid from public.app_kombax_social_mis_perfiles_r117('47406610-b046-4738-bc98-b91cc06a70be') where sujeto_tipo='club' and club_id='47406610-b046-4738-bc98-b91cc06a70be';
 r:=public.app_kombax_social_mutate_v123('kombax.social.publicar',jsonb_build_object('club_id','47406610-b046-4738-bc98-b91cc06a70be','autor_perfil_id',sid,'tipo','actualizacion','texto','QA pilot post reverted','audiencia','publica'),gen_random_uuid());
 if r#>>'{data,id}' is null then raise exception 'CLUB_PUBLICATION_FAILED';end if;
end $qa$;
reset role;
select jsonb_build_object('clubs_tested',3,'real_public_profile_edit',true,'real_social_post',true,'rollback',true) result;
rollback;
