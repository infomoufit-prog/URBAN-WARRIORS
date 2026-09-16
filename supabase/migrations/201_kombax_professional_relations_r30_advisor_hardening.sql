begin;

-- R30 performance hardening: make auth.uid() an initplan in INSERT RLS policies.
-- Private R30 tables remain without direct authenticated DML grants; these policies are defense-in-depth.

drop policy if exists kombax_prof_clients_insert_v198 on public.kombax_professional_clients_v198;
create policy kombax_prof_clients_insert_v198
on public.kombax_professional_clients_v198
for insert to authenticated
with check (
  public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'admin')
  and creado_por = (select auth.uid())
);

drop policy if exists kombax_prof_sessions_insert_v198 on public.kombax_professional_sessions_v198;
create policy kombax_prof_sessions_insert_v198
on public.kombax_professional_sessions_v198
for insert to authenticated
with check (
  public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'admin')
  and creado_por = (select auth.uid())
);

drop policy if exists kombax_prof_credentials_insert_v198 on public.kombax_professional_credentials_v198;
create policy kombax_prof_credentials_insert_v198
on public.kombax_professional_credentials_v198
for insert to authenticated
with check (
  public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'admin')
  and creado_por = (select auth.uid())
);

drop policy if exists kombax_prof_availability_insert_v198 on public.kombax_professional_availability_v198;
create policy kombax_prof_availability_insert_v198
on public.kombax_professional_availability_v198
for insert to authenticated
with check (
  public.app_kombax_puede_gestionar_perfil_v070(professional_profile_id,'admin')
  and creado_por = (select auth.uid())
);

notify pgrst, 'reload schema';
commit;
