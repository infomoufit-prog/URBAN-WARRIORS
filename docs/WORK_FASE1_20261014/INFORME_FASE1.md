# FASE 1 — Una cuenta, varios espacios dentro de Mi Club

## Estado

**Implementación local finalizada; no desplegada y pendiente de validación real en pilotos.** No se han creado usuarios, clubes, vinculaciones ni datos de producción.

## Hallazgo arquitectónico

La autenticación ya identifica varias filas de `miembros_club` por usuario y club, así como relaciones de alumno por `socios.perfil_id` y tutela por `tutores_socios.tutor_perfil_id`. La interfaz anterior priorizaba un rol efectivo único y no ofrecía un conmutador de contextos.

## Diseño e implementación

- `club-workspaces.js`: catálogo y orden de roles, ámbitos por club, preferencia persistente validada por el servidor; las facetas personales (`alumno`, `familia`) nunca habilitan cargos administrativos.
- `club-session-role.js` preserva el conjunto completo de roles activos, incluida coordinación cuando está asignada.
- `backend.js` carga las asociaciones personales y tutelas reales, resuelve la vista inicial y permite cambiarla sin cambiar de sesión de Supabase.
- `components.js` y `app.js` incorporan selector de contexto en menú lateral y cabecera adaptativa y recalculan la navegación al cambiar de rol.
- `permissions.js`, `finance.js` y `finance-premium.js` evalúan controles visibles conforme al rol seleccionado, sin conceder autorización en backend.
- `repositories.js` limita la lectura del portal a las fichas propias y tuteladas mediante filtros explícitos de Supabase PostgREST.
- `finance-member-scope.js` impide que un espacio familiar consulte filas de finanzas de otros miembros del club, incluso cuando la misma persona tiene otro rol de plantilla.
- `portal.js` filtra consultas de cuotas, reservas, inscripciones, graduaciones, seguimientos y documentos por la lista autorizada de socios.
- `app.css` añade un selector usable en móvil y escritorio.

## Matriz de casos

| Usuario | Espacios visibles | Restricción |
|---|---|---|
| Participante + tutor | Participante, Familia | Solo fichas propia y tuteladas |
| Participante + monitor | Participante, Monitor | Monitor sujeto a permisos y grupos asignados |
| Tutor + monitor | Familia, Monitor | Finanzas familiares restringidas |
| Dirección + alumno | Dirección, Participante | Contexto familiar/participante no hereda botones de tesorería |
| Secretaría + coordinación | Secretaría, Coordinación | Coordinación solo con autorización activa |
| Roles distintos en 2 clubes | Selector del club activo | Sin acceso cruzado |
| Revocación del rol | Solo roles todavía activos tras reautenticación | Preferencia inválida descartada |

## Supabase / migraciones

**Ninguna migración nueva es necesaria para este cambio local**: se reutilizan estructuras ya existentes y los permisos siguen dependiendo de RLS/RPC. No se realizaron escrituras a Supabase. El backend r262/r263 posterior al ZIP original requiere reconciliación documental separada en la fase 2.

## Entrega

ZIP acumulativo con Fase 0 y Fase 1, frontend en las tres copias, scripts de prueba y continuidad. El versionado interno se conserva por compatibilidad: 20178/R118.
