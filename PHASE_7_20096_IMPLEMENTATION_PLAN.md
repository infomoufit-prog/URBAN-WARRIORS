# Fase visual posterior a 20.095 · Plan 20.096

## Objetivo
Mejorar exclusivamente la identidad visual/estética de KOMBAX Eventos sobre 20.095, sin cambios destructivos ni nuevas dependencias backend.

## Alcance
1. Auditoría visual de 20.095.
2. Iconografía propia.
3. Paleta neon complementaria.
4. Fondo/motion premium.
5. Hero y cards.
6. Fight Cards y resultados.
7. Sponsors/highlights/landing pública.
8. Plantillas Visual Engine locales.
9. Responsive/Android/reduced-motion.
10. Regresión completa + build determinista + ZIP completo.

## Riesgos controlados
- exceso de animación;
- pérdida de legibilidad por glow;
- coste GPU en Android;
- ruptura de tests por versionado;
- cambio accidental de lógica Eventos.

## Mitigación
- motion lento y limitado;
- acentos neon secundarios;
- no WebGL/no vídeo/no librerías;
- `prefers-reduced-motion`;
- tests 20.095 heredados + test 20.096 nuevo;
- ninguna migración Supabase.

## Criterio de cierre
- `npm test` PASS;
- `npm run build` PASS;
- legal gate PASS;
- Android preflight 4/5 con firma local deliberadamente ausente;
- web=dist=Android;
- assets Visual Engine locales;
- ZIP completo + SHA-256.
