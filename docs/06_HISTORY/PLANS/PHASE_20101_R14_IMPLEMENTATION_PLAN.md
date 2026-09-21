# KOMBAX 20.101 R14 · EVENT CREATOR COMPLETE

## Base
- R13 Mobile + Events Fight Cards Hardening.

## Objetivo
Cerrar el flujo operativo de creación/edición de KOMBAX Events para clubes y federaciones con permiso real, integrando en una experiencia coherente:
1. Ficha e información.
2. Portada y banner.
3. Organización.
4. Participantes/peleadores y fotos.
5. Fight Card/emparejamientos.
6. Horarios/tatamis.
7. Álbum oficial: fotos, vídeos y enlaces externos.
8. Revisión y continuidad de edición.

## Principios
- No crear un dominio paralelo.
- Reutilizar `kombax_eventos_publicos`, participantes, combates y `kombax_evento_media`.
- Mantener aislamiento multiclub/workspace y permisos `can_manage`.
- No obligar a que exista fotografía para crear una Fight Card.
- Mostrar Álbum al gestor aunque esté vacío; al público solo cuando haya contenido.
- Permitir seguir editando después de crear/publicar.
- Mobile-first sin degradar desktop/PWA.
- Aplicar backend real antes del cierre cuando exista una carencia contractual.

## Carencia backend detectada y resuelta
La auditoría encontró que un participante externo podía recibir foto durante su alta, pero no existía una operación específica y segura para editar/reemplazar esa foto posteriormente.

Se añadió y aplicó al Supabase principal:
- `supabase/migrations/181_kombax_events_creator_participant_update_20101_r14.sql`
- RPC `app_kombax_eventos_mutate_v181(...)`
- nueva operación `event.participant.update`
- delegación de operaciones anteriores a v178
- control de workspace mediante `app_kombax_evento_contexto_gestion_v171`
- `anon`: sin EXECUTE
- `authenticated`: EXECUTE, sujeto a validación interna de gestión.

## Implementación frontend
- Constructor del evento de seis etapas operativas.
- Tras crear un evento se continúa directamente en el constructor.
- Participantes con creación, edición y sustitución de foto.
- Fight Card con alta/edición/eliminación, orden, horario y tatami/ring.
- Álbum siempre visible para gestor, incluso vacío: `Álbum · 0`.
- CTA directo `Subir fotos o vídeos` en álbum vacío.
- Subida múltiple de fotos y vídeos reutilizando el Storage oficial.
- Asociación opcional de multimedia a combate y a Competidor KOMBAX reutilizando `combate_id` y `competidor_social_profile_id` existentes.
- Cuotas conservadas: 15 fotos y 5 vídeos almacenados por evento; vídeo <=60 s, <=100 MB y <=1080p.
- Público no ve una sección de álbum vacía.

## Riesgos tratados
- Regresión del editor existente.
- Doble apertura/modal anidado.
- Desincronización del detalle tras guardar.
- Ocultar herramientas a organizadores delegados.
- Confundir álbum vacío con función no disponible.
- Debilitar aislamiento de workspace al editar participantes.

## QA obligatorio ejecutado
- Test dedicado R14.
- Sintaxis JS y `package.json`.
- Regresión histórica completa.
- Build determinista `web = dist = Android`.
- Verificación Supabase de permisos y guard de workspace de v181.
- Advisors de seguridad y rendimiento ejecutados.
- Preflight Android y hash del JKS.

## Criterios de cierre
- Un club/federación autorizado puede crear el evento y continuar desde un único panel hasta dejar participantes, fotos, Fight Card, horarios y álbum preparados.
- El Álbum es descubrible y accionable aunque esté vacío.
- La foto de un participante externo puede reemplazarse después del alta.
- No se rompen Noche de Impacto ni Urban Warriors.
- Build completo PASS.
- ZIP completo WITH_SIGNING + QA + continuidad.

## Fuera de alcance R14
- Brackets/árboles de torneo.
- `card_role` estructural independiente para Main Event / Co-Main / Featured / Undercard.
- Drag & drop avanzado de programación.
Estos bloques se mantienen para una fase posterior y no se simulan como cerrados en R14.
