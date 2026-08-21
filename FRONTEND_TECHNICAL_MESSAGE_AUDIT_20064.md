# Auditoría frontend · mensajes técnicos · KOMBAX 20.064

## Alcance

Revisión de módulos de usuario y de los mecanismos centrales de error con foco en exposición accidental de:

- mensajes de Supabase/PostgREST/PostgreSQL;
- RLS/policies;
- nombres de RPC y funciones `app_*`;
- constraints, schemas, tablas, columnas y UUID;
- códigos SQL/PGRST;
- versiones/builds internas;
- etiquetas de arquitectura que no aportan valor al usuario.

## Hallazgos

1. El traductor de errores podía devolver concatenados `message + details + hint` si el error no coincidía con unos pocos casos conocidos.
2. Existían rutas UI que renderizaban directamente `e.message`/`error.message`.
3. Perfil Profesional / Representante mostraba una referencia interna a build.
4. Gateway conservaba labels internos de cuenta/acceso.
5. El menú/configuración de un platform admin revelaba la existencia de Administración KOMBAX y herramientas técnicas dentro del contexto del club.

## Correcciones

- Sanitizador central `humanError()` reforzado.
- `technicalError()` preserva detalle para trazas privadas.
- Módulos de usuario migrados a `humanError`/`setError`.
- Admin/diagnóstico retirados del routing y navegación ordinarios.
- Consola técnica separada en acceso maestro.
- Copy interno del Gateway/Profesional sustituido.
- Test automático de no-renderizado directo de errores backend.

## Módulos revisados/corregidos

- `core/utils.js`
- `core/backend.js`
- `modules/auth-recovery.js`
- `modules/admin.js`
- `modules/finance.js`
- `modules/showcase.js`
- `modules/kombax-social.js`
- `modules/lifecycle.js`
- `modules/work-scopes.js`
- `modules/public-profile.js`
- `modules/events.js`
- `modules/help-legal.js`
- `modules/training.js`
- `modules/comms-material.js`
- `modules/community.js`
- `modules/documents.js`
- `modules/groups-members.js`
- `modules/dashboard-catalog.js`
- `modules/portal.js`
- `modules/gateway.js`

## Resultado estático

El test 20064 falla si un módulo público vuelve a insertar directamente `message`, `details` o `hint` del backend en componentes de UI. Las herramientas técnicas heredadas permanecen fuera del routing cotidiano y los detalles técnicos se reservan para Mantenimiento de la Consola KOMBAX.

## Pendiente de QA manual

La auditoría estática debe completarse provocando errores reales en APK contra backend QA: red, sesión, RLS, permisos, validación y recursos inexistentes. El criterio es que el usuario reciba una explicación humana y que la traza técnica siga disponible únicamente para administración/mantenimiento.
