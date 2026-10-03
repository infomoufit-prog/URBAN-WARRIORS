begin;
do $test$
declare u uuid:=gen_random_uuid(); req uuid:=gen_random_uuid(); result jsonb; retry jsonb; c uuid; d uuid; g uuid; s uuid; z uuid; op jsonb; stage text:='activation';
begin
 insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
 values(u,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','pilot-test-'||u||'@example.invalid',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{"nombre":"Pilot Test","apellidos":"Rollback","fecha_nacimiento":"1990-01-01"}'::jsonb,now(),now());
 perform set_config('request.jwt.claim.sub',u::text,true);
 perform set_config('request.jwt.claim.role','authenticated',true);
 result:=public.app_kombax_pilot_club_activate_r110('{"nombre_publico":"TEST ROLLBACK CLUB","declaration":true}'::jsonb,req);
 c:=(result->>'club_id')::uuid;
 retry:=public.app_kombax_pilot_club_activate_r110('{"nombre_publico":"TEST ROLLBACK CLUB","declaration":true}'::jsonb,req);
 if not coalesce((result->>'ok')::boolean,false) then raise exception 'ACTIVATION_FAILED';end if;
 if not exists(select 1 from public.miembros_club where club_id=c and perfil_id=u and activo and rol='direccion') then raise exception 'MANAGER_NOT_CREATED';end if;
 if not exists(select 1 from kombax_commercial.plan_benefits_r97 where subject_id=c and benefit_code='PILOT_ACCESS' and plan_code='premium') then raise exception 'BENEFIT_NOT_CREATED';end if;
 if retry<>result then raise exception 'IDEMPOTENCE_FAILED';end if;
stage:='discipline'; op:=public.app_mutate_v160('disciplina.guardar',jsonb_build_object('club_id',c,'nombre','FIX02 Test Discipline','activa',true),gen_random_uuid());
 if not coalesce((op->>'ok')::boolean,false) then raise exception 'GATEWAY_%: %',stage,op;end if; d:=(op->'data'->>'id')::uuid;
 stage:='group'; op:=public.app_mutate_v160('grupo.guardar',jsonb_build_object('club_id',c,'disciplina_id',d,'nombre','FIX02 Test Group','activo',true,'horarios','[]'::jsonb),gen_random_uuid());
 if not coalesce((op->>'ok')::boolean,false) then raise exception 'GATEWAY_%: %',stage,op;end if; g:=(op->'data'->>'id')::uuid;
 stage:='student'; op:=public.app_mutate_v160('alumno.guardar',jsonb_build_object('club_id',c,'nombre','FIX02','apellidos','Test Student','fecha_nacimiento','1990-01-01','disciplina_id',d,'grupo_id',g,'estado','activo'),gen_random_uuid());
 if not coalesce((op->>'ok')::boolean,false) then raise exception 'GATEWAY_%: %',stage,op;end if; s:=(op->'data'->>'id')::uuid;
 stage:='session'; op:=public.app_mutate_v160('sesion.guardar',jsonb_build_object('club_id',c,'grupo_id',g,'fecha',current_date+2,'hora_inicio','10:00','hora_fin','11:00','estado','programada'),gen_random_uuid());
 if not coalesce((op->>'ok')::boolean,false) then raise exception 'GATEWAY_%: %',stage,op;end if; z:=(op->'data'->>'id')::uuid;
 if d is null or g is null or s is null or z is null then raise exception 'MISSING_CREATED_ID';end if;

 perform set_config('kombax.pilot_test_result',jsonb_build_object('ok',true,'discipline_created',true,'group_created',true,'student_created',true,'session_created',true,'free_account_created',true,'club_created',true,'director_membership',true,'premium_pilot_access',true,'same_request_idempotent',true,'payment_not_required',true)::text,true);
exception when others then perform set_config('kombax.pilot_test_result',jsonb_build_object('ok',false,'error',SQLERRM,'stage',stage,'state',SQLSTATE)::text,true);
end $test$;
select current_setting('kombax.pilot_test_result',true)::jsonb as pilot_free_account_test;
rollback;
