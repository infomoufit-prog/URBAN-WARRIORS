# KOMBAX Events · Auditoría específica del creador de eventos · R10

## Veredicto ejecutivo
La arquitectura de KOMBAX Events ya contiene buena parte del dominio necesario para participantes, Fight Cards, Main Event, horarios, resultados, álbum y organizaciones, pero el flujo de `Crear evento` todavía no expone esas capacidades como un constructor integral. El problema principal es de producto/UX y de orquestación, con varios huecos de modelo para brackets/árboles, co-main explícito y multimedia semántica por combate/peleador.

## Lo que existe hoy y está funcional
- Crear/editar ficha básica del evento.
- Organizar como identidad habilitada y aislada por workspace/club.
- Cartel + banner + reencuadre persistente.
- Lugar, dirección, aforo, accesos, fechas, entradas, inscripciones, streaming y web oficial.
- Gestión posterior de participantes públicos.
- Alta de competidores KOMBAX y externos.
- Una foto pública por participante externo durante el alta.
- Creación posterior de combates entre dos participantes confirmados.
- Disciplina, categoría, peso/división, tatami/ring, orden y hora programada por combate.
- Estado del combate y Main Event/destacado.
- Resultados provisional/oficial/anulado.
- Álbum oficial previo/evento/postevento.
- Backend multimedia capaz de asociar media a `combate_id` o `competidor_social_profile_id`.
- Organizaciones, avales, colaboradores y patrocinadores.
- Aislamiento multiclub/workspace y entitlements de organización.

## Problema confirmado del flujo actual
El formulario inicial `Crear KOMBAX Evento` termina tras guardar la ficha principal. Solo después, al abrir el detalle del evento, aparecen botones separados para `Participantes`, `Crear combate`, `Álbum`, `Organización`, `Editar ficha` y `Portada / encuadre`.

Esto significa que el usuario que está “creando un evento” no ve un flujo continuo de construcción de cartelera. Técnicamente existe un editor de Fight Card, pero no aparece dentro del proceso inicial y exige haber creado previamente al menos dos participantes confirmados.

## Participantes / peleadores · estado actual
### Existe
- Nombre público.
- Club.
- Disciplina.
- Categoría.
- Peso.
- Foto pública única para participante externo.
- Selección de perfil Competidor KOMBAX.

### Falta para 10/10
- Editor de participante después de crearlo.
- Sustituir/reencuadrar foto del participante desde el gestor.
- Tipos de foto: retrato/carné, plano medio, cuerpo entero/promocional.
- Foto específica utilizable en Fight Card sin tener que cambiar la foto general del participante.
- Datos deportivos opcionales: cinturón/grado, récord, nacionalidad, academia/equipo, apodo.
- Para menores: usar categoría/edad deportiva sin publicar datos sensibles ni fecha de nacimiento.
- Duplicación/importación rápida de participantes entre combates cuando proceda.

## Fight Card · estado actual
### Existe
- Competidor A / B.
- Disciplina.
- Categoría.
- Peso/división.
- Tatami/ring.
- Orden.
- Hora programada.
- Estado.
- Booleano `destacado` usado como Main Event.
- Resultado posterior.

### Falta para 10/10
- Crear la Fight Card dentro del asistente inicial.
- Card visual previa mientras se construye.
- Botón `+ Añadir combate` repetible en una lista ordenable.
- Crear/editar peleador desde la propia card sin abandonar el combate.
- Drag & drop / subir-bajar orden.
- Co-Main como rol explícito separado de Main Event.
- Combate preliminar / undercard / reserva / exhibición como rol de cartelera.
- Imagen promocional propia del combate.
- Selector de retrato A y retrato B para esa pelea.
- Edición y eliminación completa desde la lista de Fight Card.
- Detección de conflictos de horario o mismo competidor en combates solapados.
- Vista agenda por hora y por tatami/ring.
- Duplicar combate / mover a otro tatami.

## Multimedia · hallazgo importante
El backend ya permite registrar media con `combate_id` y con `competidor_social_profile_id`, pero la UI de `Álbum` actual sube fotos/vídeos a nivel de evento y no expone esos enlaces.

### Existe
- 15 fotos por evento.
- 5 vídeos almacenados por evento.
- previo / evento / posterior.
- destacado.
- vídeos externos.
- storage privado + URLs firmadas.

### Falta para 10/10
- Elegir destino de cada imagen: evento / combate / peleador.
- Tipo semántico: portada, retrato, fight-card, pesaje, teaser, backstage, combate, resultado, highlight, podio.
- Subida directa desde la card de un combate.
- Subida directa desde la ficha de un peleador.
- Ver qué media está enlazada a cada combate.
- Reasignar media sin volver a subirla.
- Marcar una imagen como `imagen principal del combate`.
- Generación automática de Fight Card a partir de retratos + datos.

## Árboles / brackets / torneos
No existe en R10 un modelo público de bracket/árbol de torneo. `torneo` y `campeonato` son tipos de evento, pero la capa pública de KOMBAX Events solo modela combates independientes ordenados.

Para 10/10 hacen falta:
- Categorías/llaves.
- Rondas: preliminar, octavos, cuartos, semifinal, final.
- Nodo de bracket con origen de cada participante.
- Avance automático del ganador.
- BYE.
- Tercer puesto opcional.
- Brackets por categoría/peso/edad/cinturón.
- Visualización responsive del árbol.
- Separar bracket de una velada lineal para no complicar eventos que no lo necesitan.

## Horarios / programación
Existe `hora_programada` por combate y `tatami_ring`, pero no hay planificador visual.

Para 10/10:
- Agenda del evento.
- Timeline por tatami/ring.
- Reordenación rápida.
- Aviso de conflicto de competidor.
- Duración estimada.
- margen entre combates.
- llamada/cámara de espera opcional.
- actualización masiva de horarios.

## Main Event / Co-Main · inconsistencia detectada
El flujo normal de mutación R178 desmarca otros combates cuando uno nuevo se guarda como `destacado`, por lo que en la práctica trata `destacado` como Main Event único. Sin embargo, el seed R8 del evento de Jiu-Jitsu inserta directamente dos combates con `destacado=true`.

Esto demuestra que `destacado` no debe servir a la vez para Main Event, Co-Main y otros destacados. Debe sustituirse/evolucionarse a un campo de rol de cartelera (`main_event`, `co_main`, `featured`, `undercard`, etc.) y mantener una restricción real para un único Main Event.

## Escalabilidad / muchos eventos
### Bien
- índices por estado/fecha/tipo/creador.
- workspace isolation por club.
- dominio público separado de Mi Club.
- media indexada por evento, combate y competidor.

### Pendiente
- discovery público tiene límite máximo 100 y no dispone de cursor/keyset pagination.
- frontend carga hasta 100 eventos base y 120 live de una vez.
- participantes visibles se recortan a 16 en la ficha del evento.
- no hay paginación/lazy loading de participantes, combates o media más allá de las cuotas actuales.

Para muchos clubes/eventos se recomienda keyset pagination, carga progresiva por secciones y filtros server-side.

## Seguridad / multiclub
Estado fuerte y debe conservarse:
- creación de evento de club exige workspace explícito.
- subject y workspace deben coincidir.
- gestión posterior comprueba club creador o entidad coorganizadora aceptada.
- media usa storage privado y permisos por evento.
- KOMBAX Events público no mezcla tablas privadas de Mi Club.

## Test coverage · hueco
Los tests actuales verifican que existen marcadores como `Crear combate`, `FIGHT CARD`, álbum, etc., y validan backend/seguridad. No existe todavía una prueba E2E de producto que simule:
1. crear evento,
2. crear 4 participantes con fotos,
3. crear 2 combates,
4. marcar Main Event,
5. vincular media al combate,
6. publicar,
7. comprobar landing pública.

Ese E2E debe ser obligatorio para cerrar la siguiente fase.

## Puntuación actual
- Modelo base del evento: 9/10
- Multiclub / aislamiento: 9.5/10
- Portada y presentación: 9/10
- Organización/partners: 8.5/10
- Participantes: 6.5/10
- Fight Card funcional: 6.5/10
- Fight Card UX dentro de creación: 3.5/10
- Multimedia de evento: 8/10
- Multimedia por combate/peleador: 3/10
- Horarios/programación: 5/10
- Brackets/árboles: 0/10
- Escalabilidad discovery: 6.5/10
- E2E del creador completo: 4/10

Valoración global del `Event Creator` hoy: ~6.5/10.

## Arquitectura objetivo 10/10
Un único Event Builder por pasos:
1. Identidad y datos básicos.
2. Portada y branding.
3. Organización y partners.
4. Participantes / peleadores.
5. Fight Card / emparejamientos.
6. Agenda / tatamis / horarios.
7. Brackets (solo si el tipo lo requiere).
8. Multimedia por evento, pelea y peleador.
9. Entradas / inscripción / ubicación / streaming.
10. Revisión, completitud y publicación.

Cada paso debe poder guardarse como borrador y volver atrás. El sistema debe mostrar progreso de completitud y bloqueos solo cuando un dato sea realmente obligatorio para publicar.

## Prioridad propuesta para R11
P0
- Event Builder por pasos.
- Participantes integrados.
- `+ Añadir combate` dentro del builder.
- alta/edición rápida de peleador desde Fight Card.
- hora, orden y tatami visibles y editables en lista.
- rol de cartelera Main Event / Co-Main / Featured / Undercard.
- multimedia vinculada a combate/peleador desde UI.
- E2E completo.

P1
- agenda visual y detección de conflictos.
- reutilización/reasignación de media.
- tarjetas preview en tiempo real.
- paginación y carga progresiva.

P2
- brackets/árboles para torneo/campeonato.
- drag & drop avanzado.
- automatización de piezas sociales y resultados.
