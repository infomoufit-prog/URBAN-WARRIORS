# QA LOCAL · KOMBAX RC13 build 20030

Ejecutar después de instalar/verificar 052–057 en el Supabase utilizado por QA.

## Matriz mínima

- Gestor o Coordinación.
- Monitor A.
- Monitor B.
- Alumno A asignado al ámbito A.
- Alumno B asignado al ámbito B.
- Un alumno compartido entre A y B para probar muchos-a-muchos.
- Grupo A y Grupo B.

## Gestor / Coordinación

1. Entrar en `Ámbitos y privacidad`.
2. Crear `Equipo A` y `Equipo B`.
3. Asignar Monitor A/B.
4. Asignar alumnos y grupos.
5. Cambiar ámbito principal de un alumno y confirmar que solo queda uno principal.
6. Probar cada nivel financiero y flags de contacto/asistencia/seguimiento.

## Monitor A · privacidad

- `Mis alumnos` muestra A y los compartidos, nunca B si no comparten ámbito.
- No aparecen notas internas, emergencia, fecha de nacimiento cruda, documentos ni acciones administrativas.
- Contacto solo aparece si `ver_contacto=true`.
- `Mis grupos` no muestra Grupo B.
- Reservas/series de B no son consultables.
- Documento privado de A/B no se obtiene por ser monitor.

## Asistencia y seguimiento

- Con `gestionar_asistencia=true`, A puede registrar asistencia únicamente de su grupo/alumno matriculado.
- Con `gestionar_asistencia=false`, la misma operación falla en backend.
- Con `gestionar_seguimiento=true`, A registra seguimiento/graduación solo de sus alumnos.
- Con `false`, falla en backend.

## Finanzas

- `none`: sin filas/importe/recibo.
- `status`: estado/vencimiento; importe/saldo/recibo ocultos.
- `portfolio`: importes/saldo solo de su ámbito.
- `collect`: puede cobrar A; cobro B falla.
- `receipts`: además referencia de recibo disponible.
- Nunca aparece cartera de otro monitor por compartir club.

## Monitor B

Repetir en espejo y confirmar aislamiento A/B.

## Gestor

Confirmar que conserva la visión global histórica permitida y puede reasignar ámbitos sin reconstruir alumnos/grupos.

## Regresión producto

Repetir después Social, Showcase, Comunidad, notificaciones, perfil del Club y login/logout para confirmar que 057 no modifica sus permisos.
