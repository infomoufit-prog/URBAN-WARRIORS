# KOMBAX R73 · Auditoría de deduplicación del prompt R71→R72

Fecha: 14/09/2026  
Base efectiva auditada: **KOMBAX R72 / build 20123 · SHOWCASE REVIEWS + EVENTS COMMUNITY + CATALOG +25 · PILOT FREEZE CANDIDATE**  
Nueva revisión: **R73 / build 20124 · REPUTATION + COMMUNITY PROMPT COMPLETION**

## Criterio
El prompt histórico partía de R71/build 20122 y ordenaba crear R72/build 20123. Como R72 ya existe, está congelado y sus 11 migraciones están aplicadas en Supabase, repetir las fases habría sido una regresión. R73 solo completa brechas verificadas entre el prompt, el ZIP R72 y el backend vivo.

## Matriz de deduplicación
| Bloque del prompt | Estado en R72 | Supabase vivo antes de R73 | Acción R73 | Resultado |
|---|---|---|---|---|
| A. +25 Showcase · 8 €/30 días · acumulable | Completo | Entitlements/capacidad R72 live | Ninguna | Conservado |
| B. Preservación de referencias/reputación | Completo | `archivado`, `fuera_capacidad`, `retirado`; safe delete | Ninguna | Conservado |
| C. Reseñas Showcase | Base completa | Reviews, media, verified purchase, seller response, reports | Completar dashboard seller y verificación dinámica | **Completado** |
| D. Comunidad Events | Comentarios, respuestas, multimedia, valoración | RPC R72 live; `Me interesa` ya existía | Añadir preguntas + reacciones de evento sin duplicar interés/share | **Completado** |
| E. Centro del evento | Entrada básica disponible | Manager R72 solo añadía reportes | Añadir métricas de preguntas, respuestas, reacciones, fotos/vídeos, seguidores e interacción | **Completado** |
| F. Moderación | Completo | `reputation_reports` y moderación R72 | Reutilizar | Conservado |
| G. Precios/planes | Completo | +25 y Commerce separados | Ninguna | Conservado |
| H. Contratos/legal UGC | Completo como borrador QA | Políticas R72 live | No duplicar contratos; preguntas/reacciones quedan bajo comunidad/UGC existente | Conservado |
| I. Backend | Estructura R72 completa | 4 tablas privadas reputación + RPCs R72 | Solo columna `kind`, reacción por evento y RPCs R73 | **Sin tablas duplicadas** |
| J. UI/UX | Parcial para métricas avanzadas | N/A | Completar Mi Showcase y Centro Events | **Completado** |
| K. PC/PWA/Android | R72/20123 | N/A | Subir a R73/20124 y resincronizar | **Completado** |
| L. QA | R72 106/106 | N/A | +7 pruebas R73 y regresión R72 | **113/113** |
| M. Auditoría previa | R72 histórica | N/A | Cruce prompt ↔ ZIP ↔ Supabase | **Completado** |
| N. Versionado | El prompt pedía R72 | R72 ya existe | Nueva revisión coherente R73/build 20124 | **Completado** |
| O. ZIP completo | R72 disponible | N/A | Empaquetado R73 completo | Gate final |

## Brechas reales detectadas
1. `app_kombax_showcase_seller_reviews_r72` solo entregaba media, total, verificadas y sin responder. Faltaban rankings, evolución y reportes requeridos por el prompt.
2. `app_kombax_event_community_manage_r72` no ofrecía la capa estadística completa solicitada para el Centro del evento.
3. `Me interesa` y `Compartir` ya existían: no se duplican. Faltaban preguntas y reacciones.
4. `verified_purchase` y `verified_attendance` podían conservar un valor de creación. R73 deriva también la verificación de la evidencia actual: pedido entregado o ticket usado/check-in.
5. El primer borrador local de R73 modeló reacciones por comentario. La auditoría del backend vivo detectó que Supabase ya había materializado una solución mejor: reacción única por usuario y evento (`like`, `fire`, `applause`, `support`). El borrador provisional se descartó y **no forma parte del release**.

## Decisiones de no duplicación
- No se crea una segunda tabla de pedidos, tickets, reseñas, comentarios, reportes, interés o compartidos.
- No se crea un segundo sistema de “Compra verificada” ni “Asistió al evento”.
- No se duplican precios, planes, Commerce, add-ons ni contratos.
- Las reacciones son del **evento**, no una red social paralela sobre cada comentario.
- Los RPC R72 permanecen intactos para compatibilidad; R73 añade superficies nuevas.

## Resultado
R73 es una extensión estrictamente acumulativa de R72. No rehace el prompt histórico: conserva todo lo ya cerrado y completa únicamente los puntos que el código y Supabase demostraron incompletos.
