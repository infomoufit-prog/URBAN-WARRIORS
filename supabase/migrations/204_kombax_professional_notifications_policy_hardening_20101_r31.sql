begin;

-- R31 hardening: keep one permissive SELECT policy on notificaciones.
-- Legacy Club visibility is preserved and direct-profile visibility is added as
-- another branch inside the existing policy rather than as a parallel policy.
drop policy if exists notificaciones_direct_profile_read_v199 on public.notificaciones;
drop policy if exists notificaciones_propias on public.notificaciones;

create policy notificaciones_propias on public.notificaciones
for select to authenticated
using (
  (perfil_id = (select auth.uid()))
  or ((rol_destino is not null) and tiene_rol_club(club_id, variadic array[rol_destino]))
  or ((audiencia = 'todos'::text) and es_miembro_club(club_id))
  or tiene_rol_club(club_id, variadic array['direccion'::rol_club,'secretaria'::rol_club,'economia'::rol_club,'comunicacion'::rol_club])
  or (
    subject_type='direct_profile'
    and subject_id is not null
    and public.app_kombax_puede_gestionar_perfil_v070(subject_id,'read')
  )
);

notify pgrst,'reload schema';
commit;
