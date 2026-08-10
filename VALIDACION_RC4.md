# Validación · Urban Warriors 2.0.0-rc.4

## Controles ya superados en el artefacto

```text
npm test      -> OK
npm run build -> OK
node --check web/js/**/*.js -> OK
web = dist = Android -> 32/32 archivos
backend.js RC3 == RC4 -> OK (SHA-256)
supabase.js RC3 == RC4 -> OK (SHA-256)
migraciones 001→017 RC3 == RC4 -> OK (SHA-256)
contrato app_mutate_v160 -> 37/37 operaciones
```

## Certificación obligatoria antes de Netlify

1. `npm install`
2. `npm run dev`
3. Abrir `http://127.0.0.1:4173`
4. Iniciar sesión como Dirección.
5. Abrir **Certificación E2E**.
6. Ejecutar **Certificación completa**.
7. Exigir todos los pasos en `OK`, incluido logout/login y persistencia.

No hacer deploy si el runner muestra un fallo.

## Pruebas de experiencia recomendadas después del runner

Sin necesidad de modificar datos masivamente, comprobar visualmente los seis perfiles si existen cuentas disponibles:

- Dirección: dashboard, alumnos, grupos, equipo/invitaciones.
- Secretaría: solicitudes/alumnos/sesiones.
- Economía: finanzas/avisos.
- Comunicación: publicaciones/notificaciones.
- Monitor: Hoy/grupos/asistencia/seguimiento.
- Familia/Alumno: selector de perfil, asistencia, grado, horarios, cuotas, solicitudes y perfil.

Estas comprobaciones son de UX/visibilidad de permisos; la autorización final sigue siendo SQL/RLS.
