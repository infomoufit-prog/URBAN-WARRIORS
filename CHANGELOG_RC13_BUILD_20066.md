# KOMBAX 2.0 RC13 · build 20066

## QA de invitaciones y solicitud de Club

- Corrige el error `openInvitation is not defined` al elegir “Formo parte del equipo”.
- Alinea el formulario nuevo con el requisito de documento acreditativo existente en Supabase.
- Conserva el borrador y los valores cuando el envío de una solicitud falla después del guardado.
- Muestra mensajes seguros y concretos para documento o campos obligatorios.
- Conserva el error original en consola para que QA pueda identificar la causa sin exponer detalles técnicos en pantalla.

No incluye migraciones ni cambios de permisos, RLS o configuración remota.
