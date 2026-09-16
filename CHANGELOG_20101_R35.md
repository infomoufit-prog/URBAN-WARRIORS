# KOMBAX 20.101 R35 · Event-Centric Competition Preparation

Fecha de cierre técnico: 2026-09-04 (Europe/Madrid)
Base: `KOMBAX_20101_R34_ASSIST_PREPARATION_CONTINUITY_AUDITED_VERIFIED.zip`

## Cambio funcional

- Se elimina la navegación independiente de `Preparación y peso` dentro de Mi Club.
- La preparación pasa a pertenecer a una inscripción concreta: **Evento → Inscripción → Preparación → Peso**.
- El mismo patrón funciona en `Mi Club > Eventos` y en `KOMBAX Events`.
- Perfil Competidor y miembro/alumno conservan un acceso personal `Mis competiciones` a sus preparaciones e histórico.
- Cada inscripción admite como máximo una preparación privada.
- El pesaje oficial se separa del histórico privado y queda bloqueado como dato del evento.
- Las fichas externas pueden tener pesaje oficial, pero no histórico privado hasta enlazarse con un perfil KOMBAX.

## Privacidad

- Organizar/avalar un evento no concede acceso al histórico diario.
- Federación/organizador puede gestionar la inscripción y el pesaje oficial según permisos del evento.
- Dirección/coordinación del club propio puede administrar la preparación.
- Entrenador/monitor/preparador requiere autorización explícita sobre esa preparación.
- Delegaciones profesionales y autorizaciones explícitas existentes se conservan.
- El peso no se publica en Social ni se comparte entre clubes.

## Backend

- `218_kombax_event_centric_preparation.sql`.
- `219_kombax_event_centric_preparation_privacy_hardening.sql`.
- Nuevo roster unificado `app_kombax_event_preparation_roster_v218`.
- Mutación de inscripción/pesaje oficial `app_kombax_event_preparation_mutate_v218`.
- Tabla privada `kombax_event_official_weigh_ins_v218`.

## Estado

- Backend R35: APLICADO LIVE y verificado.
- Frontend R35: IMPLEMENTADO, PROBADO y BUILT.
- `web = dist = Android`: 186 / 186 / 186, 0 diferencias.
- Netlify: NO desplegado en este cierre.
- Google Play: NO publicado en este cierre.
- APK/AAB signed: NO generado; firma local privada pendiente deliberadamente.
