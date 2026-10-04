
do $test$
declare u uuid:=gen_random_uuid(); req uuid:=gen_random_uuid(); result jsonb; retry jsonb; c uuid; d uuid; g uuid; s uuid; z uuid; op jsonb; stage text:='activation'; u2 uuid:=gen_random_uuid(); invitation jsonb; email2 text; blocked boolean:=false; material_id uuid; publication_id uuid; u3 uuid:=gen_random_uuid(); generic jsonb; clubslug text;
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

stage:='material'; op:=public.app_mutate_v160('material.guardar',jsonb_build_object('club_id',c,'nombre','FIX02 TEST MATERIAL','categoria','Equipamiento','precio',20,'stock',3,'activo',true),gen_random_uuid());
 if not coalesce((op->>'ok')::boolean,false) then raise exception 'GATEWAY_%: %',stage,op;end if; material_id:=(op->'data'->>'id')::uuid;
 stage:='club_publication'; op:=public.app_mutate_v160('publicacion.guardar',jsonb_build_object('club_id',c,'tipo','noticia','titulo','FIX02 TEST PUBLICATION','cuerpo','Test reverted','audiencia','todos','estado','publicada'),gen_random_uuid());
 if not coalesce((op->>'ok')::boolean,false) then raise exception 'GATEWAY_%: %',stage,op;end if; publication_id:=(op->'data'->>'id')::uuid;
 if material_id is null or publication_id is null then raise exception 'MISSING_PRODUCT_OR_PUBLICATION';end if;
 stage:='team_invitation'; email2:='pilot-test-'||u2||'@example.invalid';
 invitation:=public.app_kombax_invitacion_crear_v059(c,'equipo',email2,'comunicacion','FIX02 TEST TEAM',168);
 insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
 values(u2,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',email2,now(),'{"provider":"email","providers":["email"]}'::jsonb,'{"nombre":"Team Test","apellidos":"Rollback","fecha_nacimiento":"1990-01-01"}'::jsonb,now(),now());
 perform set_config('request.jwt.claim.sub',u2::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u2,'role','authenticated','email','wrong@example.invalid')::text,true);
 begin perform public.app_kombax_invitacion_aceptar_equipo_v059(invitation->>'codigo');
 exception when others then if SQLERRM='La invitación pertenece a otro correo' then blocked:=true;else raise;end if;end;
 if not blocked then raise exception 'WRONG_EMAIL_NOT_BLOCKED';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u2,'role','authenticated','email',email2)::text,true);
 stage:='team_acceptance'; op:=public.app_kombax_invitacion_aceptar_equipo_v059(invitation->>'codigo');
 if not exists(select 1 from public.miembros_club where club_id=c and perfil_id=u2 and activo and rol='comunicacion') then raise exception 'TEAM_MEMBERSHIP_NOT_CREATED';end if;
 perform set_config('request.jwt.claim.sub',u::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated')::text,true);

 perform set_config('kombax.pilot_test_result',jsonb_build_object('ok',true,'material_product_created',true,'club_publication_created',true,'team_invitation_created',true,'team_member_linked',true,'wrong_invitation_email_blocked',blocked,'discipline_created',true,'group_created',true,'student_created',true,'session_created',true,'free_account_created',true,'club_created',true,'director_membership',true,'premium_pilot_access',true,'same_request_idempotent',true,'payment_not_required',true)::text,true);

 perform public.app_kombax_codigo_rotar_v060(c,'equipo','54321');
 select slug into clubslug from public.clubes where id=c;
 insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
 values(u3,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','qa-'||u3||'@example.invalid',now(),'{"provider":"email","providers":["email"]}','{"nombre":"QA","apellidos":"Generic Team","fecha_nacimiento":"1990-01-01"}',now(),now());
 perform set_config('request.jwt.claim.sub',u3::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u3,'role','authenticated','email','qa-'||u3||'@example.invalid')::text,true);
 generic:=public.app_kombax_equipo_solicitar_v109(clubslug,'54321','monitor');
 if not coalesce((generic->>'ok')::boolean,false) then raise exception 'QA_GENERIC_TEAM_REQUEST_FAILED_%',generic;end if;
 if not exists(select 1 from public.kombax_solicitudes_equipo_club where club_id=c and perfil_id=u3 and estado='pendiente' and rol_solicitado='monitor') then raise exception 'QA_GENERIC_TEAM_NOT_PENDING';end if;
 if exists(select 1 from public.miembros_club where club_id=c and perfil_id=u3 and activo) then raise exception 'QA_GENERIC_TEAM_PREMATURE_PERMISSION';end if;
 blocked:=false;
 begin perform public.app_kombax_equipo_solicitar_v109(clubslug,'54321','direccion');exception when others then if SQLERRM='Selecciona un rol de equipo válido' then blocked:=true;else raise;end if;end;
 if not blocked then raise exception 'QA_DIRECTOR_SELF_ASSIGNMENT_NOT_BLOCKED';end if;
raise exception 'QA_FIX11_CLUB_TEAM_INVITE_GENERIC_REQUEST_APPROVAL_ROLE_STUDENT_SESSION_PRODUCTS_OK_ROLLBACK';
end $test$;
