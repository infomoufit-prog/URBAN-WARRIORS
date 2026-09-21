-- KOMBAX 20.101 R33 · FK/index hardening (live: kombax_federation_r33_fk_index_hardening_20101)
begin;
create index if not exists idx_kombax_fed_rel_approved_by_v200 on public.kombax_federation_club_relationships_v200(approved_by) where approved_by is not null;
create index if not exists idx_kombax_fed_rel_requested_by_v200 on public.kombax_federation_club_relationships_v200(requested_by);
create index if not exists idx_kombax_fed_audit_actor_v200 on public.kombax_federation_license_audit_v200(actor_profile_id);
create index if not exists idx_kombax_fed_audit_license_v200 on public.kombax_federation_license_audit_v200(license_id) where license_id is not null;
create index if not exists idx_kombax_fed_doc_shares_granted_by_v200 on public.kombax_federation_license_document_shares_v200(granted_by);
create index if not exists idx_kombax_fed_documents_uploaded_by_v200 on public.kombax_federation_license_documents_v200(uploaded_by);
create index if not exists idx_kombax_fed_license_shares_granted_by_v200 on public.kombax_federation_license_shares_v200(granted_by);
create index if not exists idx_kombax_fed_licenses_created_by_v200 on public.kombax_federation_licenses_v200(created_by);
create index if not exists idx_kombax_fed_licenses_holder_member_v200 on public.kombax_federation_licenses_v200(holder_club_member_id) where holder_club_member_id is not null;
create index if not exists idx_kombax_fed_licenses_reviewed_by_v200 on public.kombax_federation_licenses_v200(reviewed_by) where reviewed_by is not null;
create index if not exists idx_kombax_fed_role_caps_capability_v200 on public.kombax_federation_role_capabilities_v200(capability_key);
create index if not exists idx_kombax_fed_invites_accepted_by_v200 on public.kombax_federation_team_invitations_v200(accepted_by) where accepted_by is not null;
create index if not exists idx_kombax_fed_invites_invited_by_v200 on public.kombax_federation_team_invitations_v200(invited_by);
create index if not exists idx_kombax_fed_team_added_by_v200 on public.kombax_federation_team_v200(added_by);
create index if not exists idx_kombax_fed_team_perfil_v200 on public.kombax_federation_team_v200(perfil_id);
commit;
