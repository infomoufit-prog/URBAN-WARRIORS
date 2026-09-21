# Plan de implementación · KOMBAX 20.101 R3

## Alcance
Hardening visual/authoring sobre 20.101 sin cambio de versionCode: reparar Main Event, hacer visibles los Brand Heroes, elevar Organiza/Avala a portada, permitir upload/reencuadre de cartel/banner, foto de participante externo y referencia Social con peleadores.

## Riesgos controlados
- no romper workspace isolation 20.097;
- no duplicar Events en Social;
- no reabrir write-path de resultados;
- no convertir Storage privado de álbum en público;
- no introducir un editor exclusivo del evento de ejemplo;
- no crear/reemplazar JKS;
- no tocar dominios financieros o Mi Club para resolver avisos no relacionados.

## Backend / migración
Migración 178 aditiva con focales X/Y, lectores v178 y mutation v178 que conserva v175 y fuerza un único Main Event destacado.

## Frontend
- Events: Main Event battle + editor visual + upload participante.
- Social: duelo visual con fotos.
- Brand Heroes: stacking y atmósfera.
- repositorios: v178 + uploads públicos controlados para cartel/banner/foto de participante.

## QA
- syntax checks;
- test R3 específico;
- regresión completa;
- build determinista;
- legal gate;
- Android preflight;
- Supabase ACL/readers/advisors;
- checklist manual de 4 recorridos.

## Cierre
ZIP autocontenido 20.101 R3 con JKS existente, sin credenciales de firma, logs, migración, documentación, manifiesto y SHA-256.
