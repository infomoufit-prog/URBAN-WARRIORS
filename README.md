# Urban Warriors 2.0.0-rc.9 · Final Release Candidate

RC9 parte de RC8 y solo cierra el modelo de acceso del equipo. No reconstruye persistencia, documentos, reservas, publicaciones, material, finanzas ni asistencia.

## Roles visibles definitivos

- **Gestor de la app**: máximo nivel. Internamente conserva la clave histórica `direccion` para mantener compatibilidad con el backend certificado. Es el único perfil con invitaciones de personal, herramientas técnicas, diagnóstico, certificación E2E y acciones de borrado total.
- **Coordinación**: administración operativa amplia del club. Puede trabajar con alumnos, solicitudes, disciplinas, grupos, sesiones, asistencia, progreso, seguimiento, finanzas, avisos, publicaciones, material, archivo documental, equipo en modo consulta y personalización del club. No recibe el rol interno `direccion`, no ejecuta E2E y no dispone de `Eliminar todo`.
- **Secretaría**: altas, solicitudes, alumnos, grupos, sesiones, documentos, comunicaciones administrativas y operativa asociada.
- **Economía / Tesorería**: tarifas, cuotas, pagos, recibos, avisos y material.
- **Comunicación**: publicaciones y contenidos.
- **Monitor**: grupos, sesiones, asistencia y seguimiento.
- **Familia / Alumno**: portal personal, reservas de sesión, material, publicaciones, documentos visibles y actividad propia.

## Compatibilidad de Coordinación

PostgreSQL conserva el enum histórico de roles. RC9 añade una marca `coordinacion` y materializa ese nivel mediante las membresías operativas ya existentes `secretaria + economia + comunicacion`. Esto reutiliza las RLS probadas y evita otorgar privilegios reservados a `direccion`.

En frontend esas membresías se presentan como un único rol **Coordinación**.

## Migración

Si 018, 019 y 020 ya están instaladas, ejecutar una sola vez:

`supabase/migrations/021_access_roles_gestor_coordinacion_v165.sql`

El archivo duplicado para copiar directamente al SQL Editor es `SQL_EJECUTAR_RC9_021.sql`.

El diagnóstico final es:

```sql
select * from public.app_diagnostico_final_v165();
```

Solo el Gestor de la app puede ejecutarlo.

## Contrato estable

- backend: `1.6.0`
- schema epoch: `160`
- gateway: `app_mutate_v160`
- las 62 operaciones de RC8 se conservan
- RC8 queda encapsulado como `app_mutate_v160_v164`

## Validación

```bash
npm install
npm test
npm run build
npm run dev
```

Antes del deploy final, verificar al menos una invitación de **Coordinación** con una cuenta de prueba y confirmar que ve gestión operativa pero no herramientas técnicas ni `Eliminar todo`.
