# Backend State · KOMBAX 20.101 R31

Supabase principal verificado: `poggsobhtutbuagjiydc`.

## Objetos R31
Tablas privadas v199:
- `kombax_professional_services_v199`
- `kombax_professional_charges_v199`
- `kombax_professional_payments_v199`
- `kombax_professional_expenses_v199`
- `kombax_professional_finance_audit_v199`

RPC:
- `app_kombax_professional_finance_v199(uuid)` — authenticated.
- `app_kombax_professional_finance_notifications_v199(uuid)` — authenticated.
- `app_kombax_professional_finance_mutate_v199(text,jsonb,uuid)` — authenticated.
- `app_kombax_professional_charge_restate_v199(uuid)` — interno; no EXECUTE para authenticated/anon.

## Invariantes comprobadas
- Sin `club_id` en tablas v199.
- RLS habilitada.
- Sin INSERT/UPDATE/DELETE directo para `anon` ni `authenticated`.
- `anon_execute=false` en todos los RPC sensibles R28-R31 auditados.
- `SECURITY DEFINER` solo como gateway controlado; cada RPC sensible fija `search_path` y valida sesión/sujeto/capability.
- No procesamiento de pagos; solo registro operativo.
- No facturación fiscal completa.
- Manager requiere relación aceptada, vigente y no revocada para imputar a representado.

## Notificaciones
`notificaciones.club_id` pasó a nullable solo para permitir subjects globales. Las filas históricas de Club conservan `club_id`; las profesionales usan `subject_type='direct_profile'` + `subject_id`.
La policy SELECT histórica fue fusionada con el branch `direct_profile`; queda una sola policy SELECT de `authenticated`.
