# AUDITORÍA · Combat Events Premium · KOMBAX 20.101 R48

## Resultado
R48 implementa el cierre visual premium solicitado sobre R47 sin introducir un segundo modelo de media ni modificar el esquema de Supabase.

## Arquitectura visual
La ficha del evento conserva el flujo funcional estabilizado en R44 y añade una jerarquía visual explícita:
1. Main Event: máxima jerarquía.
2. Co-Main Event: segundo foco de la velada.
3. Fight Card / undercard completa: resto de combates ordenados.
4. Cartelera oficial: poster gráfico completo opcional.

El sistema no exige fotografía individual de cada peleador. Cuando faltan retratos, el componente utiliza el fallback existente y la velada puede seguir presentándose mediante el cartel gráfico completo.

## Cartel general de la velada
Se decidió reutilizar `kombax_evento_media` en lugar de crear una tabla nueva. El cartel se registra como foto oficial del momento `previo` y se reconoce mediante el marcador `[KOMBAX_FIGHT_CARD_POSTER]` en la descripción, con compatibilidad de lectura para títulos legacy conocidos.

Ventajas:
- una sola fuente de verdad para Storage, RLS, cuotas, álbum y fullscreen;
- evita duplicar uploads;
- evita una migración DDL innecesaria;
- permite que el mismo recurso esté en Fight Card y álbum;
- mantiene compatibilidad con eventos actuales.

## Riesgos auditados
- **Saturación visual móvil:** mitigada con jerarquía de glow selectiva, tamaños responsive y bloques separados.
- **Main/Co-Main duplicados:** el backend vivo conserva índice de un único Co-Main y la lógica histórica de Main.
- **Poster duplicado:** sustitución no destructiva; nuevo upload antes de retirar el anterior.
- **Evento sin fotos individuales:** soportado mediante fallback.
- **Regresión de Events:** cubierta por suite histórica y R48 focal.
- **Movimiento/animación:** soporte `prefers-reduced-motion`.

## Evidencia automatizada
- R48 focal: 28/28 PASS.
- Suite completa: EXIT 0.
- Build: 189 archivos, PASS.
- Paridad web/dist/Android: 189/189/189, 0 diferencias.
- Secret scan activo: 910 archivos, 0 hallazgos.
- Android preflight: 4/5; firma local pendiente.

## Estado
**Candidata técnica PRE-QA / QA.** La implementación y regresión automatizada están cerradas. Sigue pendiente la validación manual autenticada del ciclo real del poster y el cierre de deuda heredada de Advisors antes de declarar producción/ciberseguridad aprobada.
