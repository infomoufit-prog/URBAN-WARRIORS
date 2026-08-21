# KOMBAX RC13 · build 20065
## Role Invitations + Team Filter QA

Fecha: 2026-08-21

### Objetivo
Corregir la composición de **Equipo** y convertir los códigos de acceso ya existentes en invitaciones claras y compartibles, manteniendo aprobación explícita y separación de permisos.

### Implementado

1. **Equipo excluye Alumno y Familia**
   - Frontend: las consultas de miembros operativos usan una lista positiva de roles.
   - Backend: `app_kombax_club_team_v051()` devuelve únicamente `direccion`, `secretaria`, `economia`, `comunicacion` y `monitor`.
   - Coordinación sigue representándose mediante el flag `coordinacion` y sus reglas vigentes.

2. **Invitar alumno / familia**
   - Nuevo CTA visible en Alumnos.
   - Reutiliza el código de alumnos/familias vigente.
   - Permite compartir la invitación, copiar la invitación completa o copiar solo el código.
   - `Nuevo alumno` continúa siendo el alta manual, separado de la invitación.

3. **Invitar al equipo por rol**
   - Roles disponibles: Coordinación, Secretaría, Economía/Tesorería, Comunicación y Monitor.
   - La invitación incorpora `team_role` y el código de equipo.
   - El rol es **solicitado**, no concedido.
   - El Gestor debe aprobar la solicitud y puede confirmar/cambiar el rol antes de concederlo.
   - Solo Dirección/Gestor puede conceder Coordinación.

4. **Alumno + miembro del equipo**
   - Un alumno existente puede solicitar además un rol operativo (por ejemplo Monitor).
   - No se elimina ni altera su condición de alumno.
   - Equipo y Alumnos se mantienen como vistas funcionales distintas.

5. **Backend 109**
   - Añade `rol_solicitado` a solicitudes de equipo.
   - Añade RPC `app_kombax_equipo_solicitar_v109`.
   - Añade RPC `app_kombax_solicitudes_equipo_v109`.
   - Endurece `app_kombax_club_team_v051` con lista positiva de roles.
   - Mantiene contratos anteriores por compatibilidad.

### Estado externo
- Supabase 107: activo.
- Supabase 109: activo y verificado.
- Supabase 108 (Acceso Maestro OTP): pendiente, no aplicado.
- Netlify: sin cambios; la web publicada no se ha migrado con esta build.
- APK signed 20065: pendiente de generación local con el JKS existente.
