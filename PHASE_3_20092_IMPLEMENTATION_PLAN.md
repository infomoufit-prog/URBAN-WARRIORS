# KOMBAX RC13 build 20.092 · Fase 3 · Plan previo de implementación

## Objetivo
Implementar Fighters & Fight Cards dentro de KOMBAX Eventos como dominio público transversal, sin reutilizar ni exponer los eventos, alumnos, participantes o combates privados de Mi Club.

## Plan previo obligatorio
1. Partir únicamente de la build completa 20.091.
2. Auditar 159/160 y conservar `eventos_competicion`, `evento_participantes` y `evento_combates` como dominio interno independiente.
3. Crear tablas públicas específicas para participantes y combates de KOMBAX Eventos.
4. Admitir competidor KOMBAX visible o ficha externa explícita, nunca lectura automática de alumnos privados.
5. Permitir solicitudes de participación por identidad pública controlada y gestión total solo al organizador autorizado.
6. Crear combates solo entre participantes confirmados del mismo evento.
7. Incorporar foto, club, disciplina, categoría, división, ring/tatami, hora, estado, ganador y resultado.
8. Diseñar Fight Cards dinámicas y animadas con assets SVG locales, sin API key.
9. Garantizar `prefers-reduced-motion`, responsive y compatibilidad Android/PWA.
10. Ejecutar QA acumulativo 20.090 + 20.091 + 20.092 y toda la suite histórica antes de empaquetar.

## Gate de privacidad
- Nunca leer ni copiar automáticamente alumnos o fichas privadas del club.
- Un competidor KOMBAX solo se expone mediante su perfil público.
- Una ficha externa contiene únicamente datos introducidos expresamente para el evento.
- Solicitudes no aceptadas no aparecen en la superficie pública.

## Fuera de alcance de esta fase
Social sharing externo, QR/deep links, exportación PNG/Story, modo Live completo, álbum, vídeos, highlights y archivo postevento. Todo ello corresponde a Fases 4 y 5.
