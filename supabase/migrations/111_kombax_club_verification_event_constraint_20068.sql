-- KOMBAX RC13 build 20068
-- Permite los eventos de auditoria emitidos por el provisionamiento de Club v097.

alter table public.kombax_verificacion_eventos
  drop constraint if exists kombax_verificacion_eventos_evento_check;

alter table public.kombax_verificacion_eventos
  add constraint kombax_verificacion_eventos_evento_check
  check (evento = any (array[
    'draft_saved'::text,'submitted'::text,'review_started'::text,'information_requested'::text,
    'verified'::text,'limited'::text,'suspended'::text,'rejected'::text,'withdrawn'::text,
    'service_activated'::text,'service_deactivated'::text,'manager_added'::text,
    'manager_updated'::text,'manager_removed'::text,'member_promoted'::text,
    'club_provisioned'::text,'club_admin_provisioned'::text
  ]));
