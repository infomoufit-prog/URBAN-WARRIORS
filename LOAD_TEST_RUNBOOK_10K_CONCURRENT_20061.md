# KOMBAX 20.061 · RUNBOOK 10K CONCURRENT

Estado: preparación reproducible. **No ejecutar carga masiva contra producción.**

## Objetivo
Validar KOMBAX con hasta 10.000 sesiones simultáneas sobre un proyecto Supabase QA/staging dimensionado para la prueba. La certificación solo existe si se conservan métricas de cada peldaño y se cumplen los umbrales.

## Dataset
Generador:
`node scripts/generate-kombax-load-fixture.mjs --clubs=200 --members=100`

Ese escenario crea 20.000 socios sintéticos, además de cuotas, sesiones, asistencias y notificaciones. El fixture no crea `auth.users`: las identidades y tokens QA deben generarse de forma separada y nunca usar datos reales.

Formato recomendado de `KOMBAX_AUTH_FIXTURE` (una línea por identidad):
`ACCESS_TOKEN|CLUB_ID|CONTACTO_ID_OPCIONAL`

## Escalado
Ejecutar, en orden, sin saltos:

100 → 250 → 500 → 1.000 → 2.500 → 5.000 → 7.500 → 10.000 VU.

Ejemplo:

```powershell
k6 run `
  -e KOMBAX_CONCURRENT_TARGET=1000 `
  -e KOMBAX_LOAD_DURATION=5m `
  -e KOMBAX_RAMP_DURATION=2m `
  -e SUPABASE_URL=$env:SUPABASE_URL `
  -e SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
  -e KOMBAX_AUTH_FIXTURE=./load/qa-auth-fixture.txt `
  load/k6-kombax-10k-concurrent.js
```

A partir de 2.500 VU se recomienda generación de carga distribuida o infraestructura k6 dedicada; una sola estación de trabajo puede convertirse en el cuello de botella y falsear el resultado.

## Mezcla de lectura
El escenario mezcla:
- directorio público;
- feed Social v085;
- resumen de cabecera v106;
- Showcase paginado;
- bandeja Contacto v106;
- historial de chat v106 cuando hay `contacto_id`.

El escenario es de lectura por defecto. Las escrituras deben probarse en una campaña separada, con usuarios QA, request IDs idempotentes y limpieza posterior.

## Umbrales de candidata
- error rate < 1 %;
- cabecera p95 < 600 ms extremo a extremo;
- feed p95 < 900 ms;
- Showcase p95 < 700 ms;
- bandeja p95 < 800 ms;
- historial chat p95 < 600 ms;
- sin crecimiento sostenido de conexiones/backlog;
- sin lecturas cruzadas entre Clubes;
- sin pérdida ni duplicación en pruebas de escritura separadas.

## Métricas a conservar por peldaño
- p50/p95/p99 HTTP por RPC;
- errores 4xx/5xx;
- `pg_stat_statements`: calls, mean/max/total;
- CPU/IO/memoria de Compute;
- conexiones DB y pool;
- locks;
- egress;
- Realtime connections si se habilita en una fase posterior.

## Criterio de parada
Detener el siguiente peldaño si:
- error >= 1 %;
- p95 supera el umbral dos ventanas consecutivas;
- DB/pool se mantiene cerca de saturación;
- aparece bloqueo, timeout o degradación creciente;
- el generador de carga alcanza CPU/red antes que Supabase.

## Nota Realtime
La documentación actual de Supabase recomienda Broadcast para escalas altas y advierte que Postgres Changes no es la vía adecuada para miles de suscriptores sobre los mismos cambios. KOMBAX 20.061 reduce el polling y deja el chat con autosync de respaldo; Broadcast privado debe validarse en staging antes de sustituir el fallback en producción.
