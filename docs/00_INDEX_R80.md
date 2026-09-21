# Índice documental KOMBAX R80

Este índice explica dónde encontrar la información del proyecto después de la reorganización de R80 build 20131.

## 01_CURRENT_RELEASE
Documentación que debe consultarse primero para conocer el estado actual de R80:
- informe final Stripe Connect + SEPA;
- scorecard QA;
- auditoría AS-IS/preimplementación;
- lista de cambios;
- manifest SHA-256;
- guía premium de cobros y domiciliaciones.

## 02_TECHNICAL_CORE
Arquitectura y documentación técnica transversal:
- arquitectura general;
- base de datos;
- seguridad;
- RLS;
- matriz de permisos y perfiles;
- roadmap y reglas de evolución.

## 03_OPERATIONS
Operación, despliegue y plataforma:
- Android Studio / APK / AAB;
- Netlify;
- Supabase;
- preflight;
- backups y recuperación;
- monitorización;
- escalabilidad y pruebas de carga;
- runbooks operativos.

## 04_LEGAL_SECURITY
Material legal, seguridad y privacidad:
- matrices contractuales;
- privacidad;
- child safety;
- DPA/piloto;
- incident response;
- cybersecurity handoffs;
- responsabilidades legales.

## 05_GUIDES
Guías de usuario y operación preservadas en PDF/Markdown.
La guía R80 de Stripe/SEPA también está duplicada en `01_CURRENT_RELEASE` para localizarla rápidamente.

## 06_HISTORY
Histórico acumulativo de KOMBAX:
- `CHANGELOGS/`: cambios por versión;
- `PLANS/`: planes y prompts de implementación;
- `RELEASES/`: notas, rollback y ficheros modificados;
- `EVIDENCE/`: carpetas de evidencias que antes estaban sueltas en raíz.

## 07_QA_AUDITS
Auditorías y validaciones históricas:
- QA;
- build validations;
- readiness;
- parity;
- Stripe Connect QA;
- Events/Social/Showcase audits;
- freeze/pilot checks.

## 08_MANIFESTS_LOGS
Evidencia técnica de integridad:
- manifests;
- checksums;
- SHA-256;
- logs;
- freeze manifests;
- `ROOT_REORGANIZATION_MAP_R80.json`, que indica dónde fue trasladado cada archivo que estaba en la raíz original.

## 99_ARCHIVE_ROOT
Archivos históricos no clasificados como documentación crítica actual. Se conservan para no perder trazabilidad.

## Carpetas documentales heredadas
Algunas colecciones que ya estaban ordenadas antes de R80 se conservan con su estructura propia (`i18n`, `commercial`, `legal`, `r74`, `r76`, `releases`, etc.) para evitar pérdida de contexto y referencias internas.

## Regla práctica
Si quieres saber **qué tiene hoy KOMBAX**, empieza por `01_CURRENT_RELEASE`.
Si quieres **modificar código**, trabaja en `web`, `supabase`, `android` y `scripts`.
Si necesitas **historial o auditorías antiguas**, utiliza `06_HISTORY`, `07_QA_AUDITS` y `08_MANIFESTS_LOGS`.
