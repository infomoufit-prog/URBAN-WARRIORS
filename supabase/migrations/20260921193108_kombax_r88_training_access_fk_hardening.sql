begin;

create index if not exists idx_consulting_requests_assigned_to_r88 on kombax_consulting.requests(assigned_to) where assigned_to is not null;
create index if not exists idx_consulting_documents_uploaded_by_r88 on kombax_consulting.documents(uploaded_by);
create index if not exists idx_consulting_events_actor_r88 on kombax_consulting.events(actor_user_id) where actor_user_id is not null;

create index if not exists idx_training_access_activated_by_r88 on kombax_training.access_grants(activated_by) where activated_by is not null;
create index if not exists idx_training_programs_created_by_r88 on kombax_training.programs(created_by) where created_by is not null;
create index if not exists idx_training_modules_program_r88 on kombax_training.modules(program_id);
create index if not exists idx_training_resources_module_r88 on kombax_training.resources(module_id);
create index if not exists idx_training_enrollments_user_r88 on kombax_training.enrollments(user_id,status);
create index if not exists idx_training_evaluations_module_r88 on kombax_training.evaluations(module_id);
create index if not exists idx_training_attempts_evaluation_r88 on kombax_training.evaluation_attempts(evaluation_id);
create index if not exists idx_training_attempts_user_r88 on kombax_training.evaluation_attempts(user_id);
create index if not exists idx_training_credentials_enrollment_r88 on kombax_training.credentials(enrollment_id);

create or replace function public.app_kombax_training_status_r86(p_subject_type text,p_subject_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_actor uuid:=(select auth.uid());
  v_enabled boolean:=false;
  v_agreement text;
  v_programs jsonb:='[]'::jsonb;
  v_enrollments jsonb:='[]'::jsonb;
begin
 if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_subject_type is null or p_subject_id is null then raise exception 'TRAINING_SUBJECT_REQUIRED'; end if;
 if p_subject_type not in ('club','federation') then raise exception 'TRAINING_SUBJECT_ACCESS_UNAVAILABLE'; end if;
 if not kombax_payments.can_access_subject_r80(v_actor,p_subject_type,p_subject_id,false) then raise exception 'TRAINING_SUBJECT_FORBIDDEN'; end if;

 select g.training_enabled,g.agreement_reference into v_enabled,v_agreement
 from kombax_training.access_grants g
 where g.subject_type=p_subject_type and g.subject_id=p_subject_id;

 if not coalesce(v_enabled,false) then
   return jsonb_build_object('enabled',false,'subject_type',p_subject_type,'subject_id',p_subject_id,'programs','[]'::jsonb,'enrollments','[]'::jsonb);
 end if;

 select coalesce(jsonb_agg(jsonb_build_object(
   'id',p.id,'title',p.title,'description',p.description,'status',p.status,'source_locale',p.source_locale,
   'module_count',(select count(*) from kombax_training.modules m where m.program_id=p.id)
 ) order by p.created_at desc),'[]'::jsonb)
 into v_programs
 from kombax_training.programs p
 where p.subject_type=p_subject_type and p.subject_id=p_subject_id and p.status='private';

 select coalesce(jsonb_agg(jsonb_build_object(
   'id',e.id,'program_id',e.program_id,'status',e.status,'started_at',e.started_at,'completed_at',e.completed_at
 ) order by e.started_at desc),'[]'::jsonb)
 into v_enrollments
 from kombax_training.enrollments e
 join kombax_training.programs p on p.id=e.program_id
 where e.user_id=v_actor and p.subject_type=p_subject_type and p.subject_id=p_subject_id;

 return jsonb_build_object('enabled',true,'subject_type',p_subject_type,'subject_id',p_subject_id,'agreement_reference',v_agreement,'programs',v_programs,'enrollments',v_enrollments);
end $$;

revoke all on function public.app_kombax_training_status_r86(text,uuid) from public,anon;
grant execute on function public.app_kombax_training_status_r86(text,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
