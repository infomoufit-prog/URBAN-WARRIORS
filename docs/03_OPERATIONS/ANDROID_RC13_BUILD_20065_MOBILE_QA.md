# Android QA · KOMBAX RC13 build 20065

## Instalación
Generar APK release signed desde `/android` con el mismo JKS utilizado en 20064. No crear un keystore nuevo.

## Checklist prioritario

### Equipo
- [ ] Entrar como Gestor de la app.
- [ ] Abrir Mi Club → Administración → Equipo.
- [ ] Bryan alumno no aparece como miembro del equipo.
- [ ] Sheila alumna no aparece como miembro del equipo.
- [ ] Dirección/Gestor sí aparece.
- [ ] `Invitar al equipo` está visible.

### Invitaciones de equipo
- [ ] Elegir Monitor y comprobar que la invitación dice Monitor.
- [ ] Elegir Secretaría y comprobar el texto.
- [ ] Elegir Economía/Tesorería y comprobar el texto.
- [ ] Elegir Comunicación y comprobar el texto.
- [ ] Como Gestor, Coordinación está disponible.
- [ ] Compartir invitación funciona cuando Android ofrece Share Sheet.
- [ ] Copiar invitación funciona.
- [ ] Copiar solo código funciona.
- [ ] El receptor ve el rol solicitado.
- [ ] Enviar solicitud no concede permisos todavía.
- [ ] La solicitud aparece al Gestor con `Rol solicitado`.
- [ ] Aprobar preselecciona el rol solicitado.
- [ ] El Gestor puede cambiar el rol antes de aprobar.
- [ ] Tras aprobar, el usuario aparece en Equipo.

### Alumno que también será equipo
- [ ] Un alumno ya existente puede solicitar ser Monitor.
- [ ] Tras aprobar Monitor, sigue existiendo en Alumnos.
- [ ] También aparece en Equipo como Monitor.

### Invitaciones de alumnos/familias
- [ ] Abrir Alumnos.
- [ ] `Invitar alumno / familia` está visible.
- [ ] `Nuevo alumno` sigue disponible como alta manual separada.
- [ ] Compartir invitación funciona.
- [ ] Copiar invitación funciona.
- [ ] Copiar solo código funciona.
- [ ] El enlace lleva al flujo de alumnos/familias.
- [ ] Un alta mediante invitación continúa su workflow de revisión normal.

### Regresión
- [ ] Social y chat siguen funcionando con backend 107.
- [ ] Showcase y chat por producto siguen funcionando.
- [ ] Barra inferior continúa equilibrada.
- [ ] No aparecen errores técnicos al usuario.
- [ ] Cerrar/abrir sesión conserva el comportamiento correcto.
