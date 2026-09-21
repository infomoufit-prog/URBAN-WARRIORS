# KOMBAX 20.101 R48 · Combat Events Premium Visual & Fight Card Experience

## Base
R47 final. La base se preserva sin modificaciones.

## Objetivo
Cerrar Combat Events con una jerarquía visual premium y una experiencia de cartelera profesional sin sacrificar estabilidad, compatibilidad ni flujo móvil.

## Alcance cerrado
1. Main Event con tratamiento visual de máxima jerarquía.
2. Co-Main Event con tratamiento propio, inmediatamente inferior al Main Event.
3. Fight Card completa visible y ordenada.
4. Cartel gráfico adicional de cartelera, reutilizando el álbum oficial sin nueva tabla ni nueva cuota física.
5. Evento válido con o sin fotos individuales de peleadores.
6. Tipografía display local/system-stack para títulos deportivos y tipografía UI para lectura.
7. Iconografía/estados/metadata más claros.
8. Neon cian + oro controlado y fondos premium sin saturación.
9. Constructor y gestores con jerarquía visual, pasos y llamadas a la acción más claras.
10. Responsive móvil/tablet/desktop y reduced-motion.
11. Preservación del flujo R44: abrir/editar/guardar/reabrir sin depender de discovery.

## Decisión backend
El cartel de cartelera se implementará inicialmente como una foto real del álbum oficial con marcador semántico en `descripcion` (`[KOMBAX_FIGHT_CARD_POSTER]`). Esto permite:
- usar el Storage/RLS/cuotas existentes;
- mostrarlo tanto en la Fight Card como en el álbum;
- retirarlo con el flujo media existente;
- evitar una migración DDL innecesaria.
Solo se abrirá una migración si el contrato vivo demuestra que esta reutilización no es suficiente.

## Riesgos
- Regresiones de Fight Card/Main Event históricas.
- Saturación visual en móvil.
- Duplicación de cartelera en álbum y sección de combates.
- Fotos faltantes o payloads demo antiguos.
- Carga de posters grandes.

## QA obligatorio
- R48 focal.
- R44 Events.
- R40 visibility.
- R47 regression.
- npm test completo.
- npm run build.
- paridad web/dist/Android.
- secret scan.
- android:preflight.
- ZIP limpio + smoke.

## Criterio de cierre
Un organizador puede presentar una velada con Main Event, Co-Main, undercard y cartel gráfico completo, con o sin retratos individuales, y el resultado mantiene lectura, impacto visual y navegación estable en móvil y escritorio.
