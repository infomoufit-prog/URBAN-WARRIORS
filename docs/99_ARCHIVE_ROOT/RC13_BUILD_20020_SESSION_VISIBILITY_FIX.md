# RC13 build 20020 · Corrección de visibilidad y confirmación de próxima sesión

## Hallazgo en validación real

El 15/08/2026, el dashboard del alumno mostraba `Próxima clase 18/08/2026 · 20:00`, pero la pantalla `Horarios y asistencia` no mostraba esa sesión al abrirse porque la nueva vista semanal iniciaba correctamente en la semana natural 10–16/08 y la clase pertenecía a la semana siguiente 17–23/08.

No era pérdida de datos ni fallo de Supabase: era una inconsistencia de UX introducida por el filtro semanal del build 20019.

## Corrección

- `Horarios y asistencia` mantiene siempre una tarjeta `Próxima sesión` fuera del filtro semanal.
- Esa tarjeta permite confirmar/cancelar asistencia aunque la sesión pertenezca a la semana siguiente.
- El check-in permanece limitado al día de la sesión.
- El dashboard `Próxima actividad` permite confirmar/cancelar asistencia directamente.
- La lista semanal sigue limitada a la semana elegida y mantiene próxima primero / pasadas detrás.

## Seguridad y backend

No se modifica Supabase ni ninguna migración 031–036. Se reutilizan las operaciones gobernadas ya existentes `sesion.reserva.confirmar` y `sesion.reserva.cancelar`.

## Versión

El cambio incrementa `versionCode` de 20019 a 20020 para mantener trazabilidad entre paquetes.
