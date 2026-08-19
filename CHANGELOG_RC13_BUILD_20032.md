# KOMBAX RC13 · build 20032 · Invitaciones por código

- Dos tipos de invitación: Alumno (`ALU-XXXXXXXXXX`) y Equipo (`EQP-XXXXXXXXXX`).
- Código de un solo uso, ligado al email, club y caducidad.
- Secretaría/Coordinación pueden invitar alumnado; solo Gestor puede invitar equipo.
- El rol de equipo queda fijado en la invitación y no puede elevarse durante el registro.
- El código de alumno se integra en `cuenta.registrar` y mantiene la regla de autorregistro 16+.
- Registro público separa invitación de alumno e invitación de equipo.
- Enlace + código copiables desde la app.
- Edge Function `invite-email` preparada para enviar correo mediante Resend.
- Si el proveedor de email aún no está configurado, la invitación se crea y la UI conserva código/enlace para QA.
- Migración 059 + rollback conservador + verify incluidos.
