# Auditoría maestra RC9 final

## Objetivo

Separar mantenimiento/administración máxima de la aplicación de la coordinación operativa del club sin alterar la persistencia ya certificada.

## Decisiones de seguridad

1. No renombrar la clave PostgreSQL `direccion`: hacerlo implicaría reescribir enum, RLS, funciones históricas y migraciones ya instaladas.
2. Mostrar `direccion` como **Gestor de la app** en toda la UX de roles.
3. Crear **Coordinación** como nivel operativo explícito sin conceder `direccion`.
4. Materializar Coordinación con las membresías existentes `secretaria + economia + comunicacion`, marcadas con `coordinacion=true`.
5. Mantener exclusivamente para Gestor: invitaciones, diagnóstico, E2E y borrado total.
6. Mantener una sola puerta de escritura pública: `app_mutate_v160`.
7. Interceptar únicamente `invitacion.crear` y `invitacion.aceptar` cuando el rol solicitado es Coordinación; delegar el resto en RC8.

## Riesgos auditados

- Escalada a `direccion`: bloqueada; Coordinación nunca inserta esa membresía.
- Duplicación visual de roles auxiliares: frontend los colapsa a `Coordinación`.
- Rotura de RLS histórica: evitada al reutilizar roles existentes.
- Rotura de RC8: gateway anterior encapsulado como `app_mutate_v160_v164`.
- Acceso técnico desde navegación: diagnóstico/E2E solo se habilitan para `direccion`.
- Acciones irreversibles: `Eliminar todo` continúa comprobando exclusivamente `direccion`.

## Criterio de aceptación

RC9 es apta para deploy cuando: migración 021 devuelve Success/diagnóstico OK, `npm test` y `npm run build` pasan, un Gestor conserva acceso total y una cuenta invitada como Coordinación puede operar el club sin ver herramientas técnicas ni borrado total.
