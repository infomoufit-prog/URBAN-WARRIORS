# Informe de reconstrucción · Urban Warriors 2.0.0-rc.1

## Resultado

Se ha reconstruido el frontend en una arquitectura modular independiente de la línea 1.6.x, conservando el backend Supabase ya validado.

No se han modificado las migraciones ni el contrato backend existente.

## Backend conservado

- Supabase Auth
- PostgreSQL
- RLS
- Storage
- backend `1.6.0`
- schema epoch `160`
- `app_mutate_v160`
- `app_runtime_contract_v160`
- `app_write_channel_probe_v160`
- `app_diagnostico_persistencia_v161`

## Frontend reconstruido

La aplicación ya no utiliza:
- `UW_STORE`
- `data-store.js`
- modo demo paralelo
- dispatcher global genérico de formularios
- recarga global de 32 colecciones después de cada escritura

La ruta de escritura es única:
`UI → repository → backend.mutate → app_mutate_v160 → respuesta → lectura → render`.

## Funcionalidad incluida

Autenticación, registro, invitaciones, disciplinas, grados, grupos, horarios, alumnos, matrículas, graduaciones, documentos, preinscripciones, sesiones, asistencia, check-in, progreso, seguimiento, tarifas, cuotas, pagos, justificantes, recibos, avisos de cobro, comunicaciones, material, variantes, pedidos, notificaciones, usuarios, configuración del club, perfil, push Android, diagnóstico y Certification Runner E2E.

## Verificaciones ejecutadas

- sintaxis JavaScript;
- arquitectura sin store 1.x;
- ausencia de fetch directo fuera del cliente Supabase;
- contrato antes de cada mutación;
- validación de versión/request_id;
- 37/37 operaciones v160 referenciadas;
- formularios con submit directo;
- bloqueo de doble envío;
- service worker sin caché de runtime;
- grafo de imports;
- Android 2.0.0-rc.1 / 20001;
- Web = dist = Android por SHA-256.

## Límite de certificación

No se declara esta RC como E2E real ni production-ready desde el entorno de construcción porque aquí no existe acceso autenticado al Supabase real.

Para evitar despliegues iterativos, la RC incorpora un Certification Runner que se ejecuta desde localhost contra el Supabase real. Solo después de superarlo debe hacerse el único deploy final a Netlify.

## Seguridad operativa del runner

El runner usa datos con prefijo `E2E_RC1_`, verifica lectura posterior y logout/login, y desactiva/archiva los datos de prueba que el contrato permite.

No genera cuotas masivas ni registra cobros reales automáticamente, porque esas operaciones pueden modificar contabilidad legítima del club.
