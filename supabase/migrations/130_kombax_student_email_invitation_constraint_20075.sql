-- KOMBAX RC13 build 20075 · student/family nominative email invitations.
-- Repairs a legacy constraint from 007 that only allowed staff roles even though
-- migration 059 introduced tipo_invitacion='alumno' and ALU-* one-time codes.
begin;

alter table public.invitaciones_club
  drop constraint if exists invitaciones_club_rol_check;

alter table public.invitaciones_club
  add constraint invitaciones_club_rol_check
  check (rol in ('direccion','secretaria','economia','comunicacion','monitor','alumno'));

-- The old pending index allowed only one pending invite per club/email globally.
-- Now team and student/family invitations are distinct workflows, so each type
-- gets its own pending slot while duplicate pending invites of the same type stay blocked.
drop index if exists public.invitaciones_pendientes_email_club;
create unique index invitaciones_pendientes_email_club_tipo_v130
  on public.invitaciones_club(club_id, lower(email), tipo_invitacion)
  where estado='pendiente';

notify pgrst,'reload schema';
commit;
