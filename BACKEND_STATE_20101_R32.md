# Backend State · KOMBAX 20.101 R32

R32 no añade DDL nuevo. Su objetivo es certificar el contrato vivo de R28-R31.

## Auditoría dirigida
Tablas auditadas: 15 objetos privados R28/R30/R31.
Resultado:
- RLS: habilitada en todas.
- DML directo `anon/authenticated`: 0 grants.
- Finanzas Profesional: 0 columnas `club_id`.
- `notificaciones`: 1 policy SELECT para `authenticated`, con branch `direct_profile` presente.

## RPC sensibles
Auditados v196/v197/v198/v199:
- `anon_execute=false`.
- endpoints públicos relevantes: `authenticated_execute=true`.
- helpers internos críticos no expuestos cuando no corresponde.
- `search_path` explícito.

## Fronteras contractuales
- Federación no obtiene private Club access por afiliación.
- Professional workspace declara `clinical_health_records_enabled=false`.
- Finanzas v199 declara no procesamiento de dinero, no facturación fiscal y no fake Club.
