# CHANGELOG · KOMBAX 20.101 R14 · Event Creator Complete

## Constructor de evento
- Nuevo constructor operativo de seis etapas: Ficha, Portada, Organización, Participantes y fotos, Fight Card y horarios, Álbum y multimedia.
- Al crear un evento nuevo, KOMBAX continúa directamente al constructor en lugar de finalizar el flujo tras la ficha básica.
- El constructor muestra estado/completitud y permite volver a cualquier bloque de gestión.

## Participantes y fotos
- Nuevo editor de participante desde gestión del evento.
- Participantes externos: edición de nombre público, club, disciplina, categoría, peso y reemplazo de fotografía mediante archivo o URL HTTPS.
- Competidores KOMBAX: identidad pública protegida; se conservan editables los datos deportivos del evento.
- Nueva operación backend `event.participant.update` mediante RPC v181.

## Fight Card y programación
- Gestor específico de Fight Card.
- Crear, editar y retirar combates.
- Emparejamiento entre participantes aceptados.
- Orden, horario programado, tatami/ring, disciplina, categoría y peso.
- Conserva la visualización R13 con fallback cuando falta fotografía.

## Álbum y multimedia
- El organizador ve la pestaña del álbum aunque esté vacío, con contador `Álbum · 0`.
- Estado vacío con CTA directo `Subir fotos o vídeos`.
- Subida múltiple de fotos y vídeos.
- Enlaces de vídeo externos conservados.
- Clasificación Previo / Evento / Posterior.
- Descarga permitida/no permitida y retirada de contenido conservadas.
- Asociación opcional de cada subida a un combate mediante `combate_id`.
- Asociación opcional a Competidor KOMBAX mediante `competidor_social_profile_id`.
- Sin tablas ni Storage paralelos.

## Backend real
- Aplicada al proyecto Supabase principal la migración 181.
- `anon` no puede ejecutar v181.
- `authenticated` puede ejecutar v181, pero la función exige gestión válida del evento/workspace.
- Operaciones antiguas continúan delegándose a v178.

## Seguridad y continuidad
- Aislamiento multiclub v171 preservado.
- No se modifican los modelos de Fight Card, álbum ni eventos públicos existentes fuera de la nueva operación de actualización de participante.
- Advisors de seguridad/rendimiento ejecutados. Los avisos globales históricos del proyecto permanecen fuera del alcance de R14; no se introdujo exposición anon para v181.

## Cache/build
- Cache web: `20101r14`.
- Service Worker: `media-r14`.
- `npm run build`: PASS.
- Resultado: `152 archivos · web = dist = Android`.
