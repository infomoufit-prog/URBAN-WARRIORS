begin;
do $test$
declare u uuid:=gen_random_uuid(); req uuid:=gen_random_uuid(); result jsonb; retry jsonb; c uuid; before_count integer; remaining integer; blocked boolean:=false; j integer;
begin
 select count(*) into before_count from kombax_commercial.pilot_entities_r97 where subject_type='club';
 remaining:=4-before_count;
 if remaining<1 then raise exception 'NO_AVAILABLE_TEST_SLOT';end if;
 for j in 1..remaining+1 loop
 u:=gen_random_uuid(); req:=gen_random_uuid();
 insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
 values(u,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','pilot-test-'||u||'@example.invalid',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{"nombre":"Pilot Test","apellidos":"Rollback","fecha_nacimiento":"1990-01-01"}'::jsonb,now(),now());
 perform set_config('request.jwt.claim.sub',u::text,true);
 perform set_config('request.jwt.claim.role','authenticated',true);
 if j=remaining+1 then
 begin
 perform public.app_kombax_pilot_club_activate_r110('{"nombre_publico":"FIFTH TEST CLUB","declaration":true}'::jsonb,req);
 exception when others then if SQLERRM='KOMBAX_PILOT_CLUB_SLOTS_FULL' then blocked:=true;else raise;end if;end;
 if not blocked then raise exception 'FIFTH_CLUB_NOT_BLOCKED';end if;
 exit;
 end if;
 result:=public.app_kombax_pilot_club_activate_r110(jsonb_build_object('nombre_publico','TEST '||u,'declaration',true),req);
 c:=(result->>'club_id')::uuid;
 retry:=public.app_kombax_pilot_club_activate_r110(jsonb_build_object('nombre_publico','TEST '||u,'declaration',true),req);
 if not coalesce((result->>'ok')::boolean,false) then raise exception 'ACTIVATION_FAILED';end if;
 if not exists(select 1 from public.miembros_club where club_id=c and perfil_id=u and activo and rol='direccion') then raise exception 'MANAGER_NOT_CREATED';end if;
 if not exists(select 1 from kombax_commercial.plan_benefits_r97 where subject_id=c and benefit_code='PILOT_ACCESS' and plan_code='premium') then raise exception 'BENEFIT_NOT_CREATED';end if;
 if retry<>result then raise exception 'IDEMPOTENCE_FAILED';end if;
 end loop;
 perform set_config('kombax.pilot_test_result',jsonb_build_object('ok',true,'initial_clubs',before_count,'test_clubs_created',remaining,'fifth_club_blocked',blocked,'free_account_created',true,'club_created',true,'director_membership',true,'premium_pilot_access',true,'same_request_idempotent',true,'payment_not_required',true)::text,true);
exception when others then perform set_config('kombax.pilot_test_result',jsonb_build_object('ok',false,'error',SQLERRM,'state',SQLSTATE)::text,true);
end $test$;
select current_setting('kombax.pilot_test_result',true)::jsonb as pilot_free_account_test;
rollback;
