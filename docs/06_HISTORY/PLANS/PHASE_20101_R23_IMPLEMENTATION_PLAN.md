# KOMBAX 20.101 R23 · Urban Fighter Image Recovery

1. Objetivo: recuperar de forma determinista las imágenes de peleadores del evento Urban Warriors en KOMBAX Events.
2. Alcance: participantes, Fight Card, Main Event, resolución local de assets demo, servidor local CMD y cache bust.
3. Fuera de alcance: Finanzas, Auth, Showcase, Social, Netlify, GitHub, versionCode y firma Android.
4. Archivos principales: `web/js/modules/kombax-events.js`, `scripts/serve.mjs`, `web/index.html`, `web/service-worker.js`, tests Events.
5. Backend: se auditan RPC/datos del evento; no se modifica Supabase si las referencias ya son correctas.
6. Riesgos: ruta remota demo rota, MIME local incorrecto, caché heredada, regresión de imágenes HTTPS reales.
7. Regresión: preservar otros eventos y el resolver genérico de imágenes externas.
8. Multiclub: no modificar datos ni ownership; Urban Warriors permanece aislado.
9. Datos: no borrar participantes, combates, media, IDs ni relaciones.
10. Migración: no prevista salvo evidencia de defecto backend.
11. Seed: preservar íntegramente R19/R20/R22; no reseed.
12. QA: datos backend, existencia/binarios, MIME HTTP, test dedicado, regresión completa, build, paridad web/dist/Android y preflight Android.
13. Cierre: 10/10 retratos Urban presentes y servidos correctamente; participantes/Fight Card/Main Event usan resolver robusto; regresión global PASS.
