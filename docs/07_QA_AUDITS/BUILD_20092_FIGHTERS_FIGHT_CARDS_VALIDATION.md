# KOMBAX RC13 build 20.092 · Fighters & Fight Cards · Validación

## Implementado
- Dominio público `kombax_evento_participantes_publicos`, separado de Mi Club.
- Dominio público `kombax_evento_combates_publicos`, separado de Mi Club.
- Solicitudes de participación con identidad pública controlada.
- Competidores KOMBAX mediante perfil público y participantes externos mediante ficha explícita.
- Estados de inscripción: pendiente, aceptada, rechazada, retirada.
- Estados de combate: propuesto, confirmado, programado, en curso, finalizado, cancelado.
- Datos Fight Card: fotos, nombres, clubes, disciplina, categoría, división/peso, ring/tatami, horario, destacado, ganador y resultado.
- Fight Cards dinámicas con motion y estado EN DIRECTO.
- Templates locales square/Story + placeholder de peleador; cero dependencia de API de generación.
- `prefers-reduced-motion` y responsive móvil.

## Seguridad y separación
La migración 161 no contiene SELECT/FK hacia `eventos_competicion`, `evento_participantes` ni `evento_combates`. Los participantes públicos pendientes/rechazados no se exponen a anónimos. Los combates públicos requieren participantes aceptados. La gestión sigue dependiendo del control de organizador de v160.

## QA
- `node --check web/js/modules/kombax-events.js`: PASS
- `node --check web/js/core/repositories.js`: PASS
- QA 20.090: PASS
- QA 20.091: PASS
- QA 20.092: PASS
- `npm run build`: PASS
- Suite histórica completa: PASS
- Build determinista: web = dist = Android

## Backend
La migración `161_kombax_events_fighters_fight_cards_20092.sql` está incluida pero NO se ha aplicado automáticamente al Supabase productivo.
