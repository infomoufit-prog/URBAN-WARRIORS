# Runbook de capacidad KOMBAX · 10 / 50 / 100 clubes

## Estado actual

La arquitectura y los escenarios reproducibles quedan preparados. **No existe certificación de 100 clubes** hasta ejecutar este runbook contra un entorno QA aislado, conservar métricas y revisar consultas/recursos.

## Protección del entorno

- Usar una base Supabase local o proyecto QA desechable. Nunca producción.
- No reutilizar usuarios, tokens, medios ni información reales.
- Aplicar migraciones 001–042 y ejecutar sus preflights/verificaciones antes de cargar datos.
- Habilitar el fixture solo durante esa sesión SQL con `set app.kombax_load_fixture_enabled = 'on';`.
- Guardar tamaño inicial/final de base, índices, CPU, memoria, conexiones y límites del plan.

## Datos generados

`scripts/generate-kombax-load-fixture.mjs` acepta únicamente 10, 50 o 100 clubes y genera SQL determinista. Cada club contiene 3 disciplinas, 4 grupos, 40 socios, 112 sesiones, 1.120 asistencias, 20 notificaciones y 240 cuotas. No crea cuentas `auth.users`, publicaciones UGC ni medios; esos flujos requieren identidades QA explícitas para no fabricar relaciones de autenticación inválidas.

Ejemplos:

```powershell
node scripts/generate-kombax-load-fixture.mjs --clubs=10
node scripts/generate-kombax-load-fixture.mjs --clubs=50
node scripts/generate-kombax-load-fixture.mjs --clubs=100
```

## Ejecución progresiva

1. Cargar 10 clubes y validar recuentos, RLS cruzada, selector, notificaciones, asistencia y finanzas.
2. Ejecutar K6 cinco minutos con 10 usuarios virtuales; conservar JSON y resumen.
3. Repetir con 50 clubes / 35 VU y después 100 clubes / 70 VU. No saltar etapas si el error supera 1 %.
4. Proporcionar tokens QA distribuidos entre clubes mediante `KOMBAX_AUTH_TOKENS` y los `club_id` alineados en `KOMBAX_CLUB_IDS`.
5. Revisar `pg_stat_statements`, planes de consultas lentas, bloqueos, conexiones, tamaño de índices y métricas del proveedor.
6. Probar aparte escrituras idempotentes, cambio de tenant, procesamiento por lotes y recuperación tras error inducido.

Ejemplo de ejecución, sin incluir secretos en el repositorio:

```powershell
k6 run -e KOMBAX_LOAD_PROFILE=10 -e KOMBAX_LOAD_DURATION=5m -e SUPABASE_URL=$env:SUPABASE_URL -e SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY -e KOMBAX_AUTH_TOKENS=$env:KOMBAX_AUTH_TOKENS -e KOMBAX_CLUB_IDS=$env:KOMBAX_CLUB_IDS load/k6-kombax-capacity.js
```

## Umbrales provisionales de aceptación

- Errores HTTP y funcionales: menos de 1 %.
- Directorio público P95: menos de 2 s.
- Feed/notificaciones autenticados P95: menos de 2,5 s.
- Ninguna lectura cruzada entre clubes en las pruebas RLS.
- Ninguna consulta sin límite en directorio, feed o centro de notificaciones.
- Sin agotamiento de conexiones ni crecimiento no controlado de memoria/almacenamiento.

Los umbrales deben confirmarse con el plan real de Supabase, regiones, volumen de medios y concurrencia prevista. Un PASS estático o la generación correcta de fixtures no sustituye esta evidencia.
