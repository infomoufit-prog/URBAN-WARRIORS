# KOMBAX 20.061 · 10K Concurrent Scale Target

## Qué significa “10.000 simultáneos”
10.000 sesiones abiertas no equivalen a 10.000 escrituras por segundo. El modelo objetivo presupone una mayoría de usuarios leyendo, navegando o inactivos, con una fracción menor en Social, Showcase, Mi Club y chat.

## Guardrails 20.061
- máximo de 6 lecturas HTTP simultáneas por pestaña/instancia;
- coalescing de lecturas idénticas en vuelo;
- contrato backend cacheado 5 minutos por cuenta + Club, sin eliminar la validación inicial;
- cabecera completamente pausada en background;
- cabecera con backoff por inactividad hasta 5 minutos;
- chat visible: 2,5 s en fase caliente y backoff por inactividad hasta 30 s;
- chat completamente pausado en background;
- reconexión con jitter;
- autorización Social precomputada por conjunto de identidades controladas en RPC v106;
- historial de chat keyset por ordinal;
- feed Social y Showcase mantienen cursor/keyset;
- límites explícitos en listados operativos que antes podían crecer sin cota;
- harness k6 hasta 10.000 VU y fixture de hasta 50.000 socios sintéticos.

## No afirmado todavía
Esta build **no certifica** que el plan Supabase actual soporte 10.000 concurrentes. La capacidad depende del Compute, límites de Realtime, Data API, pool de conexiones, región, egress y mezcla real de uso.

## Realtime
Para el objetivo final de baja latencia con muchos chats, la vía objetivo es Broadcast privado. Supabase recomienda Broadcast frente a Postgres Changes para mayor escalabilidad y señala que Postgres Changes no escala bien por encima de miles de suscriptores al mismo cambio. La 20.061 no añade una dependencia remota al runtime ni sustituye un fallback probado por una capa WebSocket sin ensayo de staging.

## Condición de certificación
Solo se podrá rotular “10K concurrent certified” después de ejecutar el runbook 100 → 10.000 sobre staging, conservar resultados y dimensionar Compute/pool conforme a los picos observados.
