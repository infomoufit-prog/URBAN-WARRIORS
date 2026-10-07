begin;
select set_config('request.jwt.claim.sub','369abf28-93d7-40a6-a589-cd10cae7ea67',true);
set local role authenticated;
do $pilot$
declare r jsonb;s uuid;
begin
select id into s from public.app_kombax_social_mis_perfiles_r117('4f5996fe-fe77-4f0b-b22c-06923b2e46a2') where sujeto_tipo='club' and club_id='4f5996fe-fe77-4f0b-b22c-06923b2e46a2';
r:=public.app_kombax_social_mutate_v123('kombax.social.publicar',jsonb_build_object('club_id','4f5996fe-fe77-4f0b-b22c-06923b2e46a2','autor_perfil_id',s,'tipo','actualizacion','texto','QA_FIX19_PILOT_VALIDATION_REVERTED','audiencia','publica'),gen_random_uuid());
if r#>>'{data,id}' is null then raise exception 'AUTHORIZED_PILOT_NOT_PUBLISHED';end if;
end $pilot$;
reset role;
update kombax_commercial.pilot_club_activations_r110 set activation_status='closed',transitioned_at=now() where club_id='4f5996fe-fe77-4f0b-b22c-06923b2e46a2';
set local role authenticated;
do $unvalidated$
declare s uuid;blocked boolean:=false;
begin
select id into s from public.app_kombax_social_mis_perfiles_r117('4f5996fe-fe77-4f0b-b22c-06923b2e46a2') where sujeto_tipo='club' and club_id='4f5996fe-fe77-4f0b-b22c-06923b2e46a2';
begin perform public.app_kombax_social_mutate_v123('kombax.social.publicar',jsonb_build_object('club_id','4f5996fe-fe77-4f0b-b22c-06923b2e46a2','autor_perfil_id',s,'tipo','actualizacion','texto','QA unvalidated club forbidden','audiencia','publica'),gen_random_uuid());
exception when others then if SQLERRM like '%NOT_ALLOWED%' or SQLERRM like '%FORBIDDEN%' then blocked:=true;else raise;end if;end;
if not blocked then raise exception 'UNVALIDATED_CLUB_PUBLISHED';end if;
end $unvalidated$;
reset role;
do $allpilots$
declare pilot record; owner_id uuid;
begin
for pilot in select club_id,manager_profile_id from kombax_commercial.pilot_club_activations_r110 where activation_status='active' loop
 perform set_config('request.jwt.claim.sub',pilot.manager_profile_id::text,true);
 if not exists(select 1 from public.app_kombax_social_mis_perfiles_r117(pilot.club_id) where sujeto_tipo='club' and club_id=pilot.club_id and publication_enabled) then raise exception 'PILOT_LOST_PUBLICATION %',pilot.club_id;end if;
end loop;
end $allpilots$;
update kombax_commercial.pilot_club_activations_r110 set activation_status='closed' where club_id='40caffb6-be7c-451e-abcf-5f8f35b516da';
do $verifiedclub$
declare owner_id uuid;
begin
select manager_profile_id into owner_id from kombax_commercial.pilot_club_activations_r110 where club_id='40caffb6-be7c-451e-abcf-5f8f35b516da';
perform set_config('request.jwt.claim.sub',owner_id::text,true);
if not exists(select 1 from public.app_kombax_social_mis_perfiles_r117('40caffb6-be7c-451e-abcf-5f8f35b516da') where sujeto_tipo='club' and publication_enabled) then raise exception 'VERIFIED_CLUB_REQUIRES_PILOT';end if;
end $verifiedclub$;
select jsonb_build_object('all_remaining_active_pilots_keep_publication',true,'verified_club_without_active_pilot_allowed',true,'authorized_pilot_publication_preserved',true,'club_without_verified_application_or_active_pilot_denied',true,'rollback',true) result;
rollback;
