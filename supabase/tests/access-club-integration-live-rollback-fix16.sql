begin;
insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('10000000-0000-4000-8000-000000000026','00000000-0000-0000-0000-000000000000','authenticated','authenticated','qa-fix16-team@example.invalid',now(),'{"provider":"email","providers":["email"]}','{"nombre":"QA_FIX16","apellidos":"TEAM","fecha_nacimiento":"1990-01-01"}',now(),now());
select set_config('request.jwt.claim.sub','369abf28-93d7-40a6-a589-cd10cae7ea67',true);
set local role authenticated;
do $test$
declare u uuid:='369abf28-93d7-40a6-a589-cd10cae7ea67';c uuid:='4f5996fe-fe77-4f0b-b22c-06923b2e46a2';u2 uuid:='10000000-0000-4000-8000-000000000026';d uuid;g uuid;s uuid;z uuid;op jsonb;invitation jsonb;email2 text;blocked boolean:=false;material_id uuid;publication_id uuid;stage text;
begin
stage:='discipline'; op:=public.app_mutate_v160('disciplina.guardar',jsonb_build_object('club_id',c,'nombre','QA_FIX16 Test Discipline','activa',true),gen_random_uuid());
 if not coalesce((op->>'ok')::boolean,false) then raise exception 'GATEWAY_%: %',stage,op;end if; d:=(op->'data'->>'id')::uuid;
 stage:='group'; op:=public.app_mutate_v160('grupo.guardar',jsonb_build_object('club_id',c,'disciplina_id',d,'nombre','QA_FIX16 Test Group','activo',true,'horarios','[]'::jsonb),gen_random_uuid());
 if not coalesce((op->>'ok')::boolean,false) then raise exception 'GATEWAY_%: %',stage,op;end if; g:=(op->'data'->>'id')::uuid;
 stage:='student'; op:=public.app_mutate_v160('alumno.guardar',jsonb_build_object('club_id',c,'nombre','QA_FIX16','apellidos','Test Student','fecha_nacimiento','1990-01-01','disciplina_id',d,'grupo_id',g,'estado','activo'),gen_random_uuid());
 if not coalesce((op->>'ok')::boolean,false) then raise exception 'GATEWAY_%: %',stage,op;end if; s:=(op->'data'->>'id')::uuid;
 stage:='session'; op:=public.app_mutate_v160('sesion.guardar',jsonb_build_object('club_id',c,'grupo_id',g,'fecha',current_date+2,'hora_inicio','10:00','hora_fin','11:00','estado','programada'),gen_random_uuid());
 if not coalesce((op->>'ok')::boolean,false) then raise exception 'GATEWAY_%: %',stage,op;end if; z:=(op->'data'->>'id')::uuid;
 if d is null or g is null or s is null or z is null then raise exception 'MISSING_CREATED_ID';end if;

stage:='material'; op:=public.app_mutate_v160('material.guardar',jsonb_build_object('club_id',c,'nombre','QA_FIX16 TEST MATERIAL','categoria','Equipamiento','precio',20,'stock',3,'activo',true),gen_random_uuid());
 if not coalesce((op->>'ok')::boolean,false) then raise exception 'GATEWAY_%: %',stage,op;end if; material_id:=(op->'data'->>'id')::uuid;
 stage:='club_publication'; op:=public.app_mutate_v160('publicacion.guardar',jsonb_build_object('club_id',c,'tipo','noticia','titulo','QA_FIX16 TEST PUBLICATION','cuerpo','Test reverted','audiencia','todos','estado','publicada'),gen_random_uuid());
 if not coalesce((op->>'ok')::boolean,false) then raise exception 'GATEWAY_%: %',stage,op;end if; publication_id:=(op->'data'->>'id')::uuid;
 if material_id is null or publication_id is null then raise exception 'MISSING_PRODUCT_OR_PUBLICATION';end if;
 stage:='team_invitation'; email2:='qa-fix16-team@example.invalid';
 invitation:=public.app_kombax_invitacion_crear_v059(c,'equipo',email2,'comunicacion','FIX02 TEST TEAM',168);
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

perform set_config('kombax.qa_fix16_integration',jsonb_build_object('ok',true,'authenticated_role',current_user,'discipline_group_student_session',true,'club_material_and_publication',true,'personal_invitation_and_acceptance',true,'wrong_email_denied',blocked)::text,true);
exception when others then raise exception 'QA_FIX16_STAGE_%: %',stage,SQLERRM;
end $test$;
select current_setting('kombax.qa_fix16_integration',true)::jsonb result;
rollback;
