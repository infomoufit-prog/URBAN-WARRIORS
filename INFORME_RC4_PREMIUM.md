# Urban Warriors 2.0.0-rc.4 · Rediseño Premium y paridad de experiencia

## Objetivo

RC4 parte de la RC3 que ya superó la certificación E2E contra el Supabase real y fue validada en producción para persistencia de grupos y disciplinas. El trabajo de RC4 se limita a experiencia de producto, presentación visual y paridad funcional de interfaz por rol.

No se modifica la arquitectura de persistencia ni el backend Supabase.

## Backend congelado

RC4 conserva byte por byte respecto a RC3:

- `web/js/core/backend.js`
- `web/js/core/supabase.js`
- migraciones `supabase/migrations/001` a `017`

Las pruebas RC4 verifican sus SHA-256 para impedir cambios accidentales.

Se mantienen:

- Supabase Auth
- PostgreSQL + RLS
- Storage
- `app_mutate_v160`
- contrato backend `1.6.0`
- schema epoch `160`
- idempotencia por `request_id`
- diagnóstico v161
- Certification Runner E2E

## Diseño Premium

Se ha creado un nuevo sistema visual Urban Warriors:

- negro carbón como base;
- superficies oscuras escalonadas;
- blanco como CTA principal;
- estados en verde/amarillo/rojo;
- hero y métricas de alto contraste;
- badges, avatares y barras de progreso;
- tablas profesionales en escritorio;
- conversión automática de tablas a cards en móvil;
- navegación lateral de escritorio y navegación inferior por rol en móvil;
- login/onboarding de marca y formularios oscuros premium.

## Experiencia por rol

### Dirección

Dashboard operativo con métricas, preinscripciones, ocupación, cuotas vencidas, acciones pendientes, grupos y próximas sesiones. Mantiene acceso a toda la gestión y al diagnóstico/certificación.

### Secretaría

Prioriza solicitudes, alumnos, documentación, matrículas, sesiones y operaciones administrativas. No hereda controles que el backend no autoriza.

### Economía / Tesorería

Dashboard financiero y navegación orientada a cuotas, pagos, recibos, avisos y material cuando corresponde.

### Comunicación

Dashboard editorial, publicaciones visuales, notificaciones y perfil.

### Monitor

Pantalla “Hoy”, sesiones, grupos asignados, asistencia y seguimiento. El backend sigue aplicando el ámbito real del monitor.

### Familia / Alumno

Se reconstruye como portal personal y no como backoffice genérico:

- selector de socio/hijo vinculado;
- porcentaje de asistencia;
- grado actual;
- próxima clase;
- estado de cuota;
- avisos no leídos;
- horarios y sesiones;
- check-in;
- comunicar pago;
- solicitar material;
- solicitar nueva matrícula en disciplina/grupo;
- añadir menor desde una cuenta familia;
- comunicaciones;
- graduaciones, seguimiento visible y documentos visibles para familia.

## Registro e invitaciones

Se recupera el onboarding por contexto:

- persona adulta;
- padre/madre/tutor;
- personal mediante invitación.

El registro muestra bloques de cuenta, datos del adulto, menor cuando corresponde, selección deportiva y consentimientos de interfaz.

Dirección dispone de una experiencia de Equipo/Invitaciones y puede generar/copiar el enlace de invitación.

## Limitaciones conscientes sin modificar SQL

1. La RLS actual no permite a Familia/Alumno consultar directamente `preinscripciones`. RC4 muestra solicitudes realizadas y utiliza las notificaciones del backend como vía de estado, en vez de abrir una nueva política RLS.
2. Los consentimientos del nuevo onboarding se muestran y validan en interfaz, pero no se persisten en `consentimientos`, porque el contrato gobernado actual no expone una operación específica para esa escritura. No se añade DML directo.
3. Comunicaciones y material conservan el mecanismo de URL de imagen disponible; no se abre un nuevo flujo de subida ni permisos de Storage en esta RC.
4. Generación masiva de cuotas/cobros no se automatiza dentro del Certification Runner para no alterar contabilidad legítima.

## Corrección adicional de coherencia

La UI de comunicaciones se limita a las audiencias admitidas por el backend: `todos`, `familias`, `monitores`.

## Validación estática ejecutada

- sintaxis de todos los módulos JavaScript: OK;
- arquitectura sin `UW_STORE`/store 1.x: OK;
- ningún `fetch` de negocio fuera del cliente Supabase: OK;
- contrato comprobado antes de cada mutación: OK;
- validación de versión/operación/request_id: OK;
- 37/37 operaciones v160 contempladas: OK;
- listeners de formulario explícitos y bloqueo de doble envío: OK;
- grafo de imports: OK;
- backend.js idéntico a RC3 por SHA-256: OK;
- supabase.js idéntico a RC3 por SHA-256: OK;
- migraciones 001→017 idénticas a RC3 por SHA-256: OK;
- navegación específica por rol: OK;
- portal Familia/Alumno: controles estructurales OK;
- audiencias de comunicaciones alineadas con SQL: OK;
- build: web = dist = Android, 32 archivos: OK.

## Estado de certificación

RC4 NO se declara todavía certificada E2E real solo por estas comprobaciones. Antes de desplegarla debe ejecutarse, desde localhost y con la cuenta Dirección real, el Certification Runner existente contra el Supabase real.

Si la certificación completa vuelve a terminar en OK, RC4 puede sustituir a RC3 en GitHub/Netlify mediante un único deploy.
