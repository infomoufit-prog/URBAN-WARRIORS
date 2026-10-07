begin;
insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select v.id,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',v.email,now(),'{"provider":"email","providers":["email"]}'::jsonb,'{"nombre":"QA_FIX16","apellidos":"ROLLBACK","fecha_nacimiento":"1990-01-01"}'::jsonb,now(),now() from (values
('10000000-0000-4000-8000-000000000027'::uuid,'qa-fix16-coord@example.invalid'),
('10000000-0000-4000-8000-000000000028'::uuid,'qa-fix16-family@example.invalid')) v(id,email);
select set_config('request.jwt.claim.sub','369abf28-93d7-40a6-a589-cd10cae7ea67',true);
set local role authenticated;
do $qa$
declare owner_id uuid:='369abf28-93d7-40a6-a589-cd10cae7ea67'; c uuid:='4f5996fe-fe77-4f0b-b22c-06923b2e46a2'; coord uuid:='10000000-0000-4000-8000-000000000027'; parent uuid:='10000000-0000-4000-8000-000000000028'; codes jsonb; slug text; out jsonb; d1 uuid;d2 uuid;g1 uuid;g2 uuid;g3 uuid; r uuid;kid record;kids uuid[]:='{}'; links jsonb; stage text;
begin
stage:='owner_codes';codes:=public.app_kombax_codigos_club_v060(c);select clubes.slug into slug from public.clubes where id=c;
stage:='team_code_request';perform set_config('request.jwt.claim.sub',coord::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',coord,'email','qa-fix16-coord@example.invalid','role','authenticated')::text,true);
out:=public.app_kombax_equipo_solicitar_v109(slug,codes#>>'{equipo,codigo}','coordinacion');
if exists(select 1 from public.miembros_club where club_id=c and perfil_id=coord and activo) then raise exception 'CODE_GRANTED_ROLE_BEFORE_APPROVAL';end if;
perform set_config('request.jwt.claim.sub',owner_id::text,true);select id into r from public.kombax_solicitudes_equipo_club where club_id=c and perfil_id=coord and estado='pendiente';
if r is null then raise exception 'REQUEST_MISSING';end if;
stage:='team_approval';out:=public.app_kombax_solicitud_equipo_resolver_v060(r,'aprobada','coordinacion',null);
stage:='catalog';out:=public.app_mutate_v160('disciplina.guardar',jsonb_build_object('club_id',c,'nombre','QA_FIX16_D1','activa',true),gen_random_uuid());d1:=(out#>>'{data,id}')::uuid;
out:=public.app_mutate_v160('disciplina.guardar',jsonb_build_object('club_id',c,'nombre','QA_FIX16_D2','activa',true),gen_random_uuid());d2:=(out#>>'{data,id}')::uuid;
out:=public.app_mutate_v160('grupo.guardar',jsonb_build_object('club_id',c,'disciplina_id',d1,'nombre','QA_FIX16_MORNING','activo',true,'horarios','[]'::jsonb),gen_random_uuid());g1:=(out#>>'{data,id}')::uuid;
out:=public.app_mutate_v160('grupo.guardar',jsonb_build_object('club_id',c,'disciplina_id',d1,'nombre','QA_FIX16_EVENING','activo',true,'horarios','[]'::jsonb),gen_random_uuid());g2:=(out#>>'{data,id}')::uuid;
out:=public.app_mutate_v160('grupo.guardar',jsonb_build_object('club_id',c,'disciplina_id',d2,'nombre','QA_FIX16_OTHER','activo',true,'horarios','[]'::jsonb),gen_random_uuid());g3:=(out#>>'{data,id}')::uuid;
stage:='family_registration';perform set_config('request.jwt.claim.sub',parent::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',parent,'email','qa-fix16-family@example.invalid','role','authenticated')::text,true);
out:=public.app_mutate_v160('cuenta.registrar',jsonb_build_object('club_slug',slug,'tipo_cuenta','tutor','adulto_nombre','QA_FIX16','adulto_apellidos','PARENT','fecha_nacimiento_adulto','1990-01-01','menor_nombre','QA_FIX16_CHILD1','menor_apellidos','ROLLBACK','fecha_nacimiento_menor','2016-01-01','disciplina_id',d1,'grupo_id',g1,'invite_code',codes#>>'{alumnos,codigo}'),gen_random_uuid());
if out->>'ok' is distinct from 'true' then raise exception 'FAMILY_REGISTRATION_FAILED: %',out;end if;
stage:='first_child_approval';perform set_config('request.jwt.claim.sub',coord::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',coord,'email','qa-fix16-coord@example.invalid','role','authenticated')::text,true);
select id into r from public.preinscripciones where club_id=c and nombre='QA_FIX16_CHILD1' and estado::text in ('enviada','pendiente','en_revision');
if r is null then raise exception 'FIRST_CHILD_REQUEST_MISSING';end if;out:=public.app_kombax_preinscripcion_aprobar_r59(r);
perform set_config('request.jwt.claim.sub',parent::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',parent,'email','qa-fix16-family@example.invalid','role','authenticated')::text,true);
stage:='second_child';out:=public.app_mutate_v160('preinscripcion.crear',jsonb_build_object('club_id',c,'tipo_solicitud','menor','nombre','QA_FIX16_CHILD2','apellidos','ROLLBACK','fecha_nacimiento','2017-01-01','tutor_nombre','QA_FIX16 PARENT','tutor_email','qa-fix16-family@example.invalid','disciplina_id',d1,'grupo_id',g1,'parentesco','madre'),gen_random_uuid());
if out->>'ok' is distinct from 'true' then raise exception 'SECOND_CHILD_FAILED: %',out;end if;
stage:='coord_approval';perform set_config('request.jwt.claim.sub',coord::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',coord,'email','qa-fix16-coord@example.invalid','role','authenticated')::text,true);
for kid in select id from public.preinscripciones where club_id=c and nombre in ('QA_FIX16_CHILD1','QA_FIX16_CHILD2') and estado::text in ('enviada','pendiente','en_revision') loop
out:=public.app_kombax_preinscripcion_aprobar_r59(kid.id);
end loop;
perform set_config('request.jwt.claim.sub',owner_id::text,true);
select array_agg(id) into kids from public.socios where club_id=c and nombre in ('QA_FIX16_CHILD1','QA_FIX16_CHILD2');
if coalesce(array_length(kids,1),0)<>2 then raise exception 'TWO_CHILDREN_NOT_APPROVED';end if;
if (select count(*) from public.tutores_socios where club_id=c and tutor_perfil_id=parent and socio_id=any(kids))<>2 then raise exception 'PARENT_LINKS_MISSING';end if;
stage:='multigroup_each_child';links:=jsonb_build_array(jsonb_build_object('disciplina_id',d1,'grupo_id',g1),jsonb_build_object('disciplina_id',d1,'grupo_id',g2),jsonb_build_object('disciplina_id',d2,'grupo_id',g3));
foreach r in array kids loop
out:=public.app_kombax_member_batch_mutate_r120('member.save.batch',jsonb_build_object('club_id',c,'member',(select to_jsonb(s) from public.socios s where s.id=r),'enrollments',links),gen_random_uuid());
if (select count(*) from public.socio_disciplinas where club_id=c and socio_id=r and activa)<>3 then raise exception 'THREE_GROUPS_NOT_SAVED';end if;
end loop;
perform set_config('request.jwt.claim.sub',parent::text,true);
if (select count(*) from public.socios where id=any(kids))<>2 then raise exception 'PARENT_CANNOT_READ_CHILDREN';end if;
perform set_config('kombax.qa_fix16_family',jsonb_build_object('ok',true,'role',current_user,'code_request_requires_approval',true,'coordination_approval',true,'family_code_registration',true,'two_children_linked_and_visible',true,'two_disciplines_three_groups_each',true)::text,true);
exception when others then raise exception 'QA_FIX16_STAGE_%: %',stage,SQLERRM;
end $qa$;
select current_setting('kombax.qa_fix16_family',true)::jsonb result;
rollback;
