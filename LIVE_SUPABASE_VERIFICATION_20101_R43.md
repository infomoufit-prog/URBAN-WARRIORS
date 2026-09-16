# R43 — Verificación de entorno Supabase vivo

## Proyecto
- Proyecto: KOMBAX
- Project ref: `poggsobhtutbuagjiydc`

## Aplicado
- Migración viva aplicada: `kombax_org_assist_priority_r43`.
- Objetivo: guardrail de acceso organizativo a Assist/Migrations.
- El SQL fuente versionado está en `supabase/migrations/235_kombax_org_assist_priority_r43.sql`.

## Diseño del guardrail
`kombax_ai_ops.org_assist_access_allowed(uuid,text)` autoriza:
1. `club:<uuid>`: miembro activo del club con rol direccion/coordinacion/secretaria/economia.
2. `profile:<uuid>`: propietario activo de perfil directo de tipo federacion.
3. Cualquier otro contexto: denegado.

Los RPC de reserva de turno y registro de migración invocan el guardrail antes del consumo/reserva de allowance.

## Evidencia que NO debe sobreinterpretarse
Tras aplicar la migración se intentó reconsultar ACL/definición viva y advisors. La consulta de lectura fue bloqueada por la capa de herramienta al no poder determinar su estado de seguridad, y no se obtuvo una captura fiable de advisors. Esto queda como gate pendiente de QA/backend/ciberseguridad.

## Gate antes de datos reales
- Releer migraciones/DDL vivo.
- Comprobar EXECUTE efectivo: `authenticated=true`, `anon=false` en RPC públicos relevantes.
- Validar RLS/tenant isolation con identidades reales de prueba: Federación, Club autorizado, Alumno/Miembro no autorizado.
- Ejecutar Supabase Security Advisors y Performance Advisors y archivar resultados.
- E2E que confirme que un perfil no autorizado no crea turnos, allowances ni archivos de migración.
