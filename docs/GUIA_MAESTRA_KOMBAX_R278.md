# Guía maestra KOMBAX · R278

Fuente: implementación acumulativa R277 y revisión R278. Este documento describe capacidades y requisitos; el inventario de código no certifica que cada operación se haya probado en producción. Los conocimientos se filtran por identidad y permiso antes de llegar al chatbot.

## Principios de atención

- Responder primero a la pregunta: significado, utilidad, comparación o procedimiento.
- Aprovechar el contexto, aceptar lenguaje natural y errores ortográficos; pedir solo lo imprescindible.
- No afirmar acciones realizadas, verificaciones o datos que no estén confirmados.
- Resolver con guías y fuentes autorizadas; escalar decisiones sensibles o fallos persistentes con una referencia útil.
- Cuenta, identidad, perfil público, membresía, suscripción y activación de un servicio son conceptos distintos.

## Índice

- Inicio y panel del club (`start`)
- Perfil del club y perfil público (`profile`)
- Códigos del club e invitaciones (`access`)
- Solicitudes de inscripción (`enrollments`)
- Alumnos y fichas (`students`)
- Equipo del club, roles y solicitudes (`team`)
- Ámbitos y privacidad de monitores (`scopes`)
- Disciplinas y grados (`catalog`)
- Grupos (`groups`)
- Sesiones y recurrencia (`sessions`)
- Asistencia y check-in (`attendance`)
- Seguimiento (`tracking`)
- Progreso y evaluaciones (`progress`)
- Finanzas, cuotas y cobros (`finance`)
- Recibos y justificantes (`receipts`)
- Avisos de cobro (`reminders`)
- Comunicaciones y avisos (`communications`)
- Eventos (`events`)
- Comunidad del Club (`community`)
- KOMBAX Social (`social`)
- Showcase (`showcase`)
- Material (`material`)
- Archivo documental (`documents`)
- Archivo y papelera (`archive`)
- Centro de notificaciones (`notifications`)
- Configuración, branding y temas (`settings`)
- Instalación, PWA y cartel de descarga (`install`)
- Privacidad, condiciones y eliminación (`privacy`)
- Mi inicio (`member-start`)
- Horarios, sesiones y check-in (`member-schedule`)
- Mis cuotas, pagos y recibos (`member-finance`)
- Comunicaciones del club (`member-comms`)
- Eventos y actividades (`member-events`)
- Material y solicitudes (`member-material`)
- Comunidad del Club (`member-community`)
- KOMBAX Social (`member-social`)
- KOMBAX Showcase (`member-showcase`)
- Mis notificaciones (`member-notifications`)
- Mis solicitudes deportivas (`member-requests`)
- Mi perfil KOMBAX (`member-profile`)
- Instalar KOMBAX (`member-install`)
- Crear una cuenta gratuita (`account-create`)
- Entrar y recuperar la contraseña (`account-login`)
- Seleccionar mi identidad (`identity-choose`)
- Consultar y activar servicios (`service-activate`)
- Editar foto, banner y perfil público (`profile-public`)
- Catálogo y activación como vendedor (`profile-showcase`)
- Eventos y ticketing (`profile-events`)
- Campañas y colaboraciones de marca (`profile-brand`)
- Gestión de federación y licencias (`profile-federation`)
- Verificación y acreditaciones profesionales (`profile-documents`)
- Crear un cargo manual (`charge-create`)
- Registrar un pago o cobro parcial (`payment-record`)
- Crear o cambiar la tarifa de un alumno (`tariff-change`)
- Validar pagos comunicados (`payment-validate`)
- Generar un informe financiero PDF (`finance-report`)
- Preparar una automatización de cuotas (`automation-prepare`)
- Explorar Social e interactuar (`social-explore`)
- Publicar en KOMBAX Social (`social-publish`)
- Editar foto, banner y álbum (`social-media`)
- Explorar productos en Showcase (`showcase-explore`)
- Publicar o retirar un producto (`showcase-publish`)
- Descubrir eventos y consultar entradas (`events-explore`)
- Preparar un evento y su ticketing (`events-create`)
- Consultar datos con Assist (`assist-data`)
- Importar datos con Migrations (`migrations-import`)
- Crear una identidad o perfil público (`identity-create`)

## Inicio y panel del club

Resumen diario, métricas, accesos rápidos y contexto del club.

Contexto: club. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- El contenido del panel cambia según el rol y sus permisos.
- Un Monitor ve únicamente sus ámbitos asignados cuando tiene alcance restringido.

### Procedimiento
1. Comprueba el club activo y tu identidad en la cabecera.
2. Revisa avisos, próximos eventos, sesiones y acciones pendientes.
3. Usa las tarjetas y navegación para entrar directamente en cada área.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de inicio y panel del club, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El contenido del panel cambia según el rol y sus permisos.

**¿Cómo compruebo el resultado en inicio y panel del club?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/dashboard-catalog.js:14`, `web/js/modules/portal.js:86`, `web/js/modules/resource-center.js:101`, `web/js/modules/guides.js:20`, `web/js/modules/consulting.js:12`.

## Perfil del club y perfil público

Logo, portada, información pública, álbum y presencia de tu club en KOMBAX.

Contexto: club. Roles de la guía: direccion, coordinacion. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- La identidad del Club es distinta de la cuenta personal del Gestor.
- El actor real se conserva para auditoría aunque publiques como Club.

### Procedimiento
1. Entra en Mi perfil desde una cuenta de Gestor o Coordinación.
2. Actualiza la información pública, imágenes y datos visibles.
3. Usa “Ver como público” para comprobar cómo lo verá la comunidad.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de perfil del club y perfil público, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. La identidad del Club es distinta de la cuenta personal del Gestor.

**¿Cómo compruebo el resultado en perfil del club y perfil público?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/club-profile.js:37`, `web/js/modules/club-kombax-hub.js:32`, `web/js/modules/public-profile.js:221`, `web/js/modules/club-poster.js:5`.

## Códigos del club e invitaciones

Dos códigos cortos reutilizables: alumnos/familias y equipo.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Los códigos admiten 4 o 5 dígitos y pueden rotarse cuando el club quiera.
- El código de equipo nunca concede permisos sensibles automáticamente: crea una solicitud pendiente.
- El autorregistro de alumno independiente requiere 16 años o más; los menores de 16 se gestionan mediante tutor autorizado.

### Procedimiento
1. Desde Alumnos consulta o cambia el código de alumnos/familias.
2. Desde Equipo consulta o cambia el código de miembros del equipo.
3. Coloca el código de alumnos junto al QR del cartel de descarga.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de códigos del club e invitaciones, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Los códigos admiten 4 o 5 dígitos y pueden rotarse cuando el club quiera.

**¿Cómo compruebo el resultado en códigos del club e invitaciones?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/gateway.js:113`, `web/js/modules/auth-recovery.js:41`.

## Solicitudes de inscripción

Crear una cuenta no confirma por sí solo la pertenencia a un club. Solicitud, aprobación y aceptación son pasos distintos según la vía de alta.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- La solicitud no equivale automáticamente a una membresía activa.
- La información de menores debe seguir el flujo de tutor/club.

### Procedimiento
1. Abre Solicitudes y revisa los datos enviados.
2. Comprueba identidad, contacto y datos deportivos requeridos.
3. Aprueba o rechaza según el procedimiento del club.

### Comprobación y resolución
- Comprueba si la persona ya tiene cuenta antes de crear otra.
- Revisa el club, la modalidad de acceso y el destinatario de la invitación.
- Una solicitud pendiente debe resolverse desde la cuenta con permiso, sin reutilizar códigos de otro club.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de solicitudes de inscripción, ¿qué reviso?**

Comprueba si la persona ya tiene cuenta antes de crear otra. La solicitud no equivale automáticamente a una membresía activa.

**¿Cómo compruebo el resultado en solicitudes de inscripción?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/groups-members.js:30`, `web/js/modules/portal.js:86`.

## Alumnos y fichas

Una cuenta de acceso, una ficha de alumno y una identidad pública no son lo mismo. La ficha pertenece al club; un tutor puede relacionarse con varios hijos sin convertirlos en una sola persona.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, monitor. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Los monitores restringidos solo pueden ver alumnos de sus grupos/cartera asignados.
- Los datos familiares, administrativos y económicos están separados por permisos.

### Procedimiento
1. Busca al alumno por nombre o grupo.
2. Abre su ficha para consultar datos y contexto deportivo.
3. Edita únicamente los campos permitidos por tu rol.

### Comprobación y resolución
- Busca primero la ficha del alumno para evitar duplicados.
- Revisa por separado las disciplinas y grupos asignados; no sustituyas la ficha para añadir otra actividad.
- Comprueba la autorización del tutor y selecciona el hijo correcto antes de modificar sus datos.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de alumnos y fichas, ¿qué reviso?**

Busca primero la ficha del alumno para evitar duplicados. Los monitores restringidos solo pueden ver alumnos de sus grupos/cartera asignados.

**¿Cómo compruebo el resultado en alumnos y fichas?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/groups-members.js:30`, `web/js/modules/portal.js:86`.

## Equipo del club, roles y solicitudes

El titular es responsable de la suscripción y de los accesos del equipo. Se admiten varias personas con el mismo rol; una coordinación no sustituye la propiedad.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- El código de equipo no asigna un rol por sí solo.
- Los permisos dependen del rol y del ámbito asignado.
- La elevación a Coordinación/Gestor permanece protegida por reglas específicas.

### Procedimiento
1. Revisa las solicitudes pendientes de acceso del equipo.
2. Aprueba la persona y asigna el rol operativo correspondiente.
3. Comprueba después sus ámbitos de trabajo si es Monitor.

### Comprobación y resolución
- Distingue una solicitud al equipo de una matrícula de alumno.
- El titular gestiona aprobación, cambio de rol y revocación del equipo.
- Después de revocar, comprueba que el miembro ya no dispone del acceso; no elimines su cuenta global.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de equipo del club, roles y solicitudes, ¿qué reviso?**

Distingue una solicitud al equipo de una matrícula de alumno. El código de equipo no asigna un rol por sí solo.

**¿Cómo compruebo el resultado en equipo del club, roles y solicitudes?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/profile-team.js:9`, `web/js/modules/admin.js:26`.

## Ámbitos y privacidad de monitores

Asigna grupos, alumnos y capacidades concretas a cada monitor.

Contexto: club. Roles de la guía: direccion, coordinacion. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- La relación es muchos-a-muchos: un alumno puede estar en más de un grupo y tener más de un monitor autorizado.
- Un monitor restringido no debe poder consultar alumnos fuera de su ámbito.

### Procedimiento
1. Selecciona un Monitor.
2. Asigna los grupos y/o alumnos que debe gestionar.
3. Define el alcance financiero permitido cuando corresponda.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de ámbitos y privacidad de monitores, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. La relación es muchos-a-muchos: un alumno puede estar en más de un grupo y tener más de un monitor autorizado.

**¿Cómo compruebo el resultado en ámbitos y privacidad de monitores?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/work-scopes.js:11`.

## Disciplinas y grados

Cada disciplina tiene su propio catálogo de grados. Un grado debe interpretarse dentro de la disciplina correspondiente.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- La edición de disciplinas está reservada a roles autorizados.
- Los monitores pueden trabajar con grados cuando su permiso lo permite.

### Procedimiento
1. Crea o revisa las disciplinas activas.
2. Configura los grados/niveles de cada disciplina.
3. Utiliza esta estructura en grupos, alumnos y progreso.

### Comprobación y resolución
- Revisa la disciplina seleccionada antes de editar sus grados.
- Comprueba el nombre, orden y color cuando el formulario los admita.
- No apliques a otra disciplina un grado solo por compartir el mismo color.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de disciplinas y grados, ¿qué reviso?**

Revisa la disciplina seleccionada antes de editar sus grados. La edición de disciplinas está reservada a roles autorizados.

**¿Cómo compruebo el resultado en disciplinas y grados?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/dashboard-catalog.js:14`.

## Grupos

Un alumno puede entrenar en varias disciplinas y en varios grupos. La disciplina y el grupo representan relaciones distintas; el horario no cambia su identidad.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, monitor. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Un alumno puede participar en varios grupos cuando el modelo del club lo requiera.
- El Monitor solo opera sobre grupos asignados si está restringido.

### Procedimiento
1. Crea el grupo con su nombre y disciplina.
2. Añade o revisa los alumnos vinculados.
3. Relaciona el grupo con las sesiones de entrenamiento.

### Comprobación y resolución
- Comprueba que las disciplinas existen en el club.
- Comprueba cada grupo y su disciplina antes de guardar.
- Después, vuelve a abrir la ficha y verifica todas las asignaciones.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de grupos, ¿qué reviso?**

Comprueba que las disciplinas existen en el club. Un alumno puede participar en varios grupos cuando el modelo del club lo requiera.

**¿Cómo compruebo el resultado en grupos?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/groups-members.js:30`.

## Sesiones y recurrencia

Una sesión es una clase o entrenamiento situado en una fecha y horario, asociado al grupo correspondiente. Puede ser puntual o formar parte de una serie recurrente.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, monitor. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Los cambios de una sesión no deben alterar indebidamente toda la serie.
- Los monitores restringidos solo modifican sesiones dentro de sus grupos autorizados.

### Procedimiento
1. Selecciona el grupo y crea la serie o sesión.
2. Define fecha, hora y recurrencia cuando proceda.
3. Registra excepciones, cambios o finalización de series desde la propia sesión.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de sesiones y recurrencia, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Los cambios de una sesión no deben alterar indebidamente toda la serie.

**¿Cómo compruebo el resultado en sesiones y recurrencia?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/training.js:13`, `web/js/modules/private-training.js:8`.

## Asistencia y check-in

Registra presencia/ausencia por sesión y consulta el historial.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, monitor. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- La asistencia está vinculada a sesiones y alumnos reales.
- El historial alimenta seguimiento y métricas del club.

### Procedimiento
1. Abre Asistencia y selecciona la sesión correspondiente.
2. Marca la presencia de los alumnos autorizados.
3. Guarda y revisa el resultado antes de salir.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de asistencia y check-in, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. La asistencia está vinculada a sesiones y alumnos reales.

**¿Cómo compruebo el resultado en asistencia y check-in?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/training.js:13`.

## Seguimiento

Añade observaciones y seguimiento del alumno dentro del ámbito autorizado.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, monitor. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- El seguimiento no debe exponer datos a monitores fuera del ámbito del alumno.
- Utiliza información necesaria y profesional, evitando datos irrelevantes.

### Procedimiento
1. Busca al alumno autorizado.
2. Registra la observación o seguimiento pertinente.
3. Consulta el histórico para mantener continuidad entre sesiones.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de seguimiento, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El seguimiento no debe exponer datos a monitores fuera del ámbito del alumno.

**¿Cómo compruebo el resultado en seguimiento?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/training.js:13`.

## Progreso y evaluaciones

Consulta y actualiza la evolución deportiva, grados y resultados.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, monitor. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- El progreso deportivo es independiente de la información financiera.
- Respeta el alcance de grupos/alumnos del Monitor.

### Procedimiento
1. Entra en Progreso y selecciona alumno/grupo.
2. Revisa el nivel actual y evolución registrada.
3. Actualiza la evaluación cuando tengas permiso.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de progreso y evaluaciones, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El progreso deportivo es independiente de la información financiera.

**¿Cómo compruebo el resultado en progreso y evaluaciones?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/training.js:13`.

## Finanzas, cuotas y cobros

Las finanzas del club reúnen las cuotas, los cargos y los pagos que puedes consultar o gestionar según tu rol. Un importe pendiente y un pago recibido son cosas diferentes.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, economia, monitor, familia, alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Los roles ven distinta profundidad financiera.
- Un Monitor puede tener alcance ninguno/estado/cartera/cobro/recibos según configuración.
- Familias y alumnos solo ven la información económica que les corresponde.

### Procedimiento
1. Filtra por periodo, alumno o estado.
2. Registra o revisa el cobro según tu permiso.
3. Comprueba que el estado final coincide con el movimiento realizado.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de finanzas, cuotas y cobros, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Los roles ven distinta profundidad financiera.

**¿Cómo compruebo el resultado en finanzas, cuotas y cobros?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/finance.js:99`, `web/js/modules/finance-premium.js:60`, `web/js/modules/historical-finance.js:6`, `web/js/modules/finance-context.js:12`, `web/js/modules/finance-guide.js:19`, `web/js/modules/finance-premium-bootstrap.js:1`, `web/js/modules/payments-center.js:52`, `web/js/modules/professional-finance.js:24`.

## Recibos y justificantes

Consulta recibos generados y abre el justificante completo para imprimir o compartir.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, economia, monitor, familia, alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- El recibo debe corresponder a un cobro real y mantener trazabilidad.
- La visibilidad depende del rol y relación con el alumno.

### Procedimiento
1. Localiza el cobro o mensualidad correspondiente.
2. Abre el recibo completo desde la acción disponible.
3. Imprime o conserva el justificante desde la vista preparada.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de recibos y justificantes, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El recibo debe corresponder a un cobro real y mantener trazabilidad.

**¿Cómo compruebo el resultado en recibos y justificantes?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/finance.js:99`, `web/js/modules/finance-premium.js:60`.

## Avisos de cobro

Gestiona recordatorios de mensualidades y pagos pendientes.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, economia. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Los avisos deben partir de información económica vigente.
- Evita duplicar comunicaciones innecesarias.

### Procedimiento
1. Filtra los pagos pendientes.
2. Revisa destinatario y contexto antes de enviar.
3. Registra el aviso y consulta su estado.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de avisos de cobro, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Los avisos deben partir de información económica vigente.

**¿Cómo compruebo el resultado en avisos de cobro?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/comms-material.js:67`, `web/js/modules/finance.js:99`.

## Comunicaciones y avisos

Publica información oficial del club para los destinatarios adecuados.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, comunicacion. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Diferencia comunicaciones oficiales de publicaciones sociales.
- Utiliza los canales internos para información operativa del club.

### Procedimiento
1. Crea la comunicación y define el contenido.
2. Selecciona audiencia o contexto cuando corresponda.
3. Publica y comprueba la notificación resultante.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de comunicaciones y avisos, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Diferencia comunicaciones oficiales de publicaciones sociales.

**¿Cómo compruebo el resultado en comunicaciones y avisos?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/comms-material.js:67`, `web/js/modules/profile-conversations.js:8`.

## Eventos

Crea y gestiona eventos, actividades, competiciones y comunicaciones asociadas.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, monitor. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Los eventos son contenido del club; no sustituyen a las sesiones de entrenamiento.
- Los permisos de gestión varían según rol.

### Procedimiento
1. Crea el evento con fecha y descripción.
2. Configura los datos de participación disponibles.
3. Publica y revisa su visibilidad en el portal.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de eventos, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Los eventos son contenido del club; no sustituyen a las sesiones de entrenamiento.

**¿Cómo compruebo el resultado en eventos?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/events.js:146`, `web/js/modules/kombax-events.js:803`.

## Comunidad del Club

Capa interna del club para publicaciones, imágenes/vídeos y comunicación comunitaria.

Contexto: club. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Es distinta de KOMBAX Social: esta comunidad está vinculada al club.
- Publicar requiere aceptación vigente de las normas.
- Se aplican límites de contenido y ciclo de vida configurados.

### Procedimiento
1. Acepta las Normas de Comunidad del Club si vas a publicar.
2. Crea una publicación con el contenido permitido.
3. Consulta el feed interno y las publicaciones vigentes.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de comunidad del club, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Es distinta de KOMBAX Social: esta comunidad está vinculada al club.

**¿Cómo compruebo el resultado en comunidad del club?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/community.js:106`.

## KOMBAX Social

Red social temática de combate: publicar, Me gusta público, interés privado, comentarios, guardados y perfiles públicos.

Contexto: club. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- KOMBAX Social está dedicado a artes marciales y deportes de contacto; el contenido claramente fuera de temática puede ser retirado por moderación.
- Miembro de club no se convierte automáticamente en Competidor.
- El acceso Social de miembros requiere edad mínima verificada y activación voluntaria.
- Los comentarios pueden estar abiertos, solo verificados o cerrados según la publicación.
- Nombre y avatar del autor son navegables hacia su perfil público.

### Procedimiento
1. Activa una identidad Social elegible y selecciona con quién actúas.
2. Publica únicamente contenido relacionado con artes marciales y deportes de contacto; añade foto/vídeo o contenido del álbum si quieres.
3. Usa el corazón para Me gusta público; Me interesa/No me interesa es una preferencia privada para personalizar tu feed. Comenta, responde, guarda y abre perfiles desde nombre/avatar.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de kombax social, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. KOMBAX Social está dedicado a artes marciales y deportes de contacto; el contenido claramente fuera de temática puede ser retirado por moderación.

**¿Cómo compruebo el resultado en kombax social?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/kombax-social.js:345`, `web/js/modules/social-network.js:17`.

## Showcase

Marketplace y escaparate profesional: productos de vendedores autorizados, servicios de contacto, compras, pedidos y seguimiento.

Contexto: club. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Los productos comerciales pueden usar checkout Stripe y pedidos; el vendedor identificado es quien vende, prepara, entrega y atiende la posventa. KOMBAX proporciona la plataforma tecnológica.
- Los comentarios y corazones pertenecen a Social, no a Showcase.

### Procedimiento
1. Explora fichas publicadas o abre el espacio de tu Club/Marca autorizado.
2. Crea una ficha con imagen, descripción y CTA cuando puedas gestionarlo.
3. Publica, comparte o guarda los elementos de interés.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de showcase, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Los productos comerciales pueden usar checkout Stripe y pedidos; el vendedor identificado es quien vende, prepara, entrega y atiende la posventa. KOMBAX proporciona la plataforma tecnológica.

**¿Cómo compruebo el resultado en showcase?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/showcase.js:83`, `web/js/modules/showcase-compliance.js:4`.

## Material

Gestiona el catálogo/material interno y las solicitudes relacionadas.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, economia, familia, alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- La gestión de material del club es independiente del Showcase público.

### Procedimiento
1. Consulta los materiales disponibles.
2. Gestiona artículos o solicitudes según tu rol.
3. Revisa el estado de cada solicitud.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de material, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. La gestión de material del club es independiente del Showcase público.

**¿Cómo compruebo el resultado en material?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/comms-material.js:67`, `web/js/modules/showcase.js:83`.

## Archivo documental

Guarda y consulta documentos internos autorizados del club.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- El acceso documental está restringido a roles administrativos autorizados.

### Procedimiento
1. Abre Archivo documental.
2. Sube o localiza el archivo correspondiente.
3. Comprueba que solo tenga acceso quien realmente lo necesita.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de archivo documental, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso documental está restringido a roles administrativos autorizados.

**¿Cómo compruebo el resultado en archivo documental?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/documents.js:36`, `web/js/modules/professional-documents.js:6`.

## Archivo y papelera

Consulta elementos antiguos, archivados o candidatos a limpieza.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Los registros económicos/legales no deben borrarse si existe obligación de conservación.

### Procedimiento
1. Entra en Archivo y papelera.
2. Filtra por tipo y antigüedad.
3. Archiva, restaura o limpia solo cuando la acción sea segura.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de archivo y papelera, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Los registros económicos/legales no deben borrarse si existe obligación de conservación.

**¿Cómo compruebo el resultado en archivo y papelera?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/lifecycle.js:43`.

## Centro de notificaciones

Gestiona avisos informativos y acciones pendientes sin perder tareas importantes.

Contexto: club. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- “Marcar todo como leído” no debe ocultar notificaciones que requieren una acción real.
- Las notificaciones push dependen también del permiso del dispositivo.

### Procedimiento
1. Abre Notificaciones y revisa los grupos de avisos.
2. Marca como leídos los informativos que ya hayas revisado.
3. Abre individualmente los avisos que requieren acción.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de centro de notificaciones, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. “Marcar todo como leído” no debe ocultar notificaciones que requieren una acción real.

**¿Cómo compruebo el resultado en centro de notificaciones?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/portal.js:86`.

## Configuración, branding y temas

Datos del club, logo, portada y cuatro temas premium con acentos de neón sutil.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, economia, comunicacion. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Los cuatro temas son Combat Dark Neon, Electric Blue Pro, Gold Luxe y Dojo Heritage Glow.
- El neón se usa como acento, no como fondo saturado.
- El perfil público del club recibe también su theme_id.

### Procedimiento
1. Abre Configuración y revisa los datos del club.
2. Selecciona el tema premium y comprueba la vista previa.
3. Publica la personalización para aplicarla al portal y perfil público.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de configuración, branding y temas, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Los cuatro temas son Combat Dark Neon, Electric Blue Pro, Gold Luxe y Dojo Heritage Glow.

**¿Cómo compruebo el resultado en configuración, branding y temas?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/admin.js:26`.

## Instalación, PWA y cartel de descarga

Instala KOMBAX y utiliza el cartel genérico del club con QR y código de invitación.

Contexto: club. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- El cartel es genérico para cualquier club y no contiene nombres fijos de un tenant.
- El QR debe resolver el club; el código corto valida el canal de alta.

### Procedimiento
1. Abre Instalar app.
2. Instala la PWA desde el navegador compatible o utiliza el canal Android del club.
3. Gestor/Coordinación/Secretaría pueden abrir el cartel genérico y completar QR/código cuando proceda.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de instalación, pwa y cartel de descarga, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El cartel es genérico para cualquier club y no contiene nombres fijos de un tenant.

**¿Cómo compruebo el resultado en instalación, pwa y cartel de descarga?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/pwa-install.js:8`.

## Privacidad, condiciones y eliminación

Consulta textos legales, consentimientos y solicita eliminación de cuenta.

Contexto: club. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Autorización de imagen y normas de comunidad son consentimientos diferenciados.
- Eliminar cuenta no equivale a borrar trazabilidad económica/legal que deba conservarse.

### Procedimiento
1. Baja hasta Condiciones y privacidad en esta misma pantalla.
2. Lee la versión vigente antes de aceptar o retirar un consentimiento.
3. Usa el centro de eliminación si necesitas iniciar el cierre de tu cuenta.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de privacidad, condiciones y eliminación, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Autorización de imagen y normas de comunidad son consentimientos diferenciados.

**¿Cómo compruebo el resultado en privacidad, condiciones y eliminación?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/support-privacy.js:21`, `web/js/modules/account-security.js:4`, `web/js/modules/help-legal.js:90`, `web/js/modules/moderation-notices.js:5`.

## Mi inicio

Tu resumen personal: próximas clases, avisos y accesos principales.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Solo ves información relacionada con tu cuenta y tu club.
- Las funciones administrativas del club no forman parte del perfil Miembro.

### Procedimiento
1. Entra en Inicio al abrir KOMBAX.
2. Revisa tus próximas clases, avisos y situación general.
3. Usa los accesos directos para ir a la función que necesites.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de mi inicio, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Solo ves información relacionada con tu cuenta y tu club.

**¿Cómo compruebo el resultado en mi inicio?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/portal.js:86`.

## Horarios, sesiones y check-in

Consulta tus horarios y próximas sesiones; confirma asistencia cuando esté habilitado.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Solo aparecen grupos y sesiones vinculados a tu ficha.
- Una reserva o check-in no modifica el horario creado por el club.

### Procedimiento
1. Abre Horarios para consultar tus grupos y clases.
2. Revisa la próxima sesión y, si está disponible, confirma o cancela tu asistencia.
3. El día de la clase utiliza Check-in cuando el club lo tenga habilitado.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de horarios, sesiones y check-in, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Solo aparecen grupos y sesiones vinculados a tu ficha.

**¿Cómo compruebo el resultado en horarios, sesiones y check-in?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/portal.js:86`.

## Mis cuotas, pagos y recibos

Mis cuotas muestra la información económica que corresponde a tu ficha o a los hijos que tienes vinculados. Un cargo pendiente es una cantidad por pagar; no confirma que se haya hecho un cobro.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Solo puedes consultar información económica asociada a tu propia ficha.
- Un recibo aparece cuando existe un cobro real registrado por el club.

### Procedimiento
1. Entra en Cuotas.
2. Comprueba el periodo y el estado de cada mensualidad.
3. Abre el recibo o justificante cuando exista un cobro registrado.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de mis cuotas, pagos y recibos, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Solo puedes consultar información económica asociada a tu propia ficha.

**¿Cómo compruebo el resultado en mis cuotas, pagos y recibos?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/portal.js:86`.

## Comunicaciones del club

Lee avisos e información oficial que el club dirige a sus miembros.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Las comunicaciones oficiales son distintas de las publicaciones sociales.
- La visibilidad depende de la audiencia definida por el club.

### Procedimiento
1. Abre Comunicaciones.
2. Revisa los avisos nuevos y su fecha.
3. Consulta el contenido completo cuando necesites más detalle.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de comunicaciones del club, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Las comunicaciones oficiales son distintas de las publicaciones sociales.

**¿Cómo compruebo el resultado en comunicaciones del club?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/comms-material.js:67`.

## Eventos y actividades

Consulta eventos, actividades y competiciones publicadas para tu entorno.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Un evento no sustituye al horario habitual de clases.
- Las acciones disponibles dependen de cómo el club haya configurado el evento.

### Procedimiento
1. Abre Eventos.
2. Consulta fecha, descripción y detalles disponibles.
3. Sigue las indicaciones del club cuando el evento requiera una acción o participación.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de eventos y actividades, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Un evento no sustituye al horario habitual de clases.

**¿Cómo compruebo el resultado en eventos y actividades?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/events.js:146`.

## Material y solicitudes

Consulta material disponible y gestiona tus solicitudes al club.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Material es un servicio interno del club.
- KOMBAX Showcase es un escaparate público diferente y no gestiona pedidos del club.

### Procedimiento
1. Abre Material.
2. Consulta los artículos disponibles y sus variantes cuando existan.
3. Envía una solicitud y revisa posteriormente su estado.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de material y solicitudes, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Material es un servicio interno del club.

**¿Cómo compruebo el resultado en material y solicitudes?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/comms-material.js:67`.

## Comunidad del Club

Participa en el espacio interno de publicaciones de tu propio club.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- La Comunidad del Club es interna y diferente de KOMBAX Social.
- Publicar requiere mantener vigentes las normas y límites de contenido aplicables.

### Procedimiento
1. Lee y acepta las Normas de Comunidad del Club antes de publicar.
2. Consulta el feed interno y crea contenido cuando tu cuenta lo permita.
3. Revisa tus publicaciones y la actividad disponible.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de comunidad del club, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. La Comunidad del Club es interna y diferente de KOMBAX Social.

**¿Cómo compruebo el resultado en comunidad del club?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/community.js:106`.

## KOMBAX Social

Activa, si eres elegible, tu identidad social pública y participa en la comunidad global.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- El acceso de miembros requiere la edad mínima verificada por el club y activación voluntaria.
- Ser Miembro no te convierte automáticamente en Competidor verificado.
- Tu expediente privado del club permanece separado de la identidad pública Social.

### Procedimiento
1. Desde Mi perfil comprueba si puedes activar KOMBAX Social.
2. Acepta sus normas específicas y crea tu identidad pública voluntariamente.
3. En Social puedes publicar, reaccionar, comentar, guardar y abrir perfiles públicos.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de kombax social, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso de miembros requiere la edad mínima verificada por el club y activación voluntaria.

**¿Cómo compruebo el resultado en kombax social?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/kombax-social.js:345`.

## KOMBAX Showcase

Explora productos, servicios y perfiles profesionales publicados en KOMBAX Showcase.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Algunos productos permiten compra y pedido mediante Stripe. Las compras están reservadas a mayores de 18 años; los servicios profesionales siguen siendo de contacto.
- Las funciones de gestión de Showcase pertenecen a perfiles autorizados, no al Miembro.

### Procedimiento
1. Abre KOMBAX Showcase.
2. Explora fichas públicas de clubes, marcas y elementos destacados.
3. Guarda o comparte contenido cuando la ficha ofrezca esa acción.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de kombax showcase, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Algunos productos permiten compra y pedido mediante Stripe. Las compras están reservadas a mayores de 18 años; los servicios profesionales siguen siendo de contacto.

**¿Cómo compruebo el resultado en kombax showcase?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/showcase.js:83`.

## Mis notificaciones

Revisa avisos informativos y tareas que necesitan tu atención.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- “Marcar todo como leído” no elimina las acciones pendientes importantes.
- Las notificaciones push dependen también de los permisos del dispositivo.

### Procedimiento
1. Abre Notificaciones.
2. Marca como leídos los avisos informativos que ya hayas revisado.
3. Abre individualmente cualquier notificación que requiera una acción.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de mis notificaciones, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. “Marcar todo como leído” no elimina las acciones pendientes importantes.

**¿Cómo compruebo el resultado en mis notificaciones?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/portal.js:86`.

## Mis solicitudes deportivas

Consulta o envía solicitudes relacionadas con tu inscripción deportiva.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- La solicitud queda pendiente hasta que el club la revise.
- Enviar una solicitud no modifica por sí solo tu inscripción activa.

### Procedimiento
1. Abre Solicitudes.
2. Revisa tus relaciones deportivas activas y solicitudes anteriores.
3. Envía una nueva solicitud de disciplina/grupo cuando necesites un cambio o alta.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de mis solicitudes deportivas, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. La solicitud queda pendiente hasta que el club la revise.

**¿Cómo compruebo el resultado en mis solicitudes deportivas?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/portal.js:86`.

## Mi perfil KOMBAX

Gestiona tu única identidad pública: banner, avatar, presentación, información deportiva, álbum y actividad Social.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Mi perfil y tu perfil KOMBAX Social son la misma identidad pública; no existe un segundo perfil deportivo visible.
- La foto privada de acceso, documentos, cuotas, asistencia y expediente del club permanecen en una capa privada separada.
- Ser Miembro no equivale a Competidor verificado ni concede una insignia KOMBAX.

### Procedimiento
1. Abre Mi perfil.
2. Si KOMBAX Social aún no está activo, completa la activación voluntaria cuando seas elegible.
3. Edita desde la misma ficha tu banner, avatar, presentación e información deportiva pública.
4. Gestiona tu álbum y comprueba la parte privada del club separada debajo de tu ficha pública.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de mi perfil kombax, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. Mi perfil y tu perfil KOMBAX Social son la misma identidad pública; no existe un segundo perfil deportivo visible.

**¿Cómo compruebo el resultado en mi perfil kombax?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/public-profile.js:221`, `web/js/modules/sports-profile.js:21`.

## Instalar KOMBAX

Instala la aplicación para acceder más rápido desde tu móvil o dispositivo.

Contexto: club. Roles de la guía: alumno. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- La instalación no crea una cuenta nueva ni cambia tus permisos.
- El acceso sigue dependiendo de tu cuenta y del club seleccionado.

### Procedimiento
1. Abre Instalar app.
2. Sigue la opción disponible para tu dispositivo o navegador.
3. Una vez instalada, entra con la misma cuenta de tu club.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de instalar kombax, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. La instalación no crea una cuenta nueva ni cambia tus permisos.

**¿Cómo compruebo el resultado en instalar kombax?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/pwa-install.js:8`.

## Crear una cuenta gratuita

La cuenta gratuita es tu acceso a KOMBAX con un correo y contraseña. La cuenta y el perfil público son cosas diferentes: después puedes crear una identidad o vincularte a un club.

Contexto: public. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Pulsa Acceder a mi cuenta y elige Crear cuenta gratuita.
2. Completa los datos solicitados y las aceptaciones obligatorias.
3. Confirma tu correo cuando se solicite y accede a tu cuenta.
4. Después puedes crear una identidad pública o vincularte a un club.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

**No encuentro la opción de crear una cuenta gratuita, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en crear una cuenta gratuita?**

Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/gateway.js:113`, `web/js/modules/account-birth-date.js:8`, `web/js/modules/platform-legal.js:5`.

## Entrar y recuperar la contraseña

Entrar y recuperar la contraseña

Contexto: public. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre Acceder a mi cuenta.
2. Introduce el correo y tu contraseña.
3. Si no la recuerdas, pulsa He olvidado mi contraseña y sigue el correo de recuperación.
4. No compartas tu contraseña con el asistente.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

**No encuentro la opción de entrar y recuperar la contraseña, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en entrar y recuperar la contraseña?**

Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/gateway.js:113`, `web/js/modules/auth-recovery.js:41`.

## Seleccionar mi identidad

Una cuenta puede administrar identidades personales y organizaciones separadas. Club, Marca y Federación conservan su perfil público y espacio propios.

Contexto: public. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre Seleccionar identidad o Gestionar mi cuenta e identidades.
2. Elige el club, la marca, la federación o tu identidad personal.
3. Comprueba el nombre del espacio antes de realizar una acción.
4. Cada identidad conserva sus permisos, equipo y servicios.

### Comprobación y resolución
- Comprueba la identidad activa antes de publicar o contratar.
- Archivar una identidad administrativamente no cancela una suscripción ni retira automáticamente su contenido público.
- Una capacidad personal adicional no debe generar otra persona duplicada.

**No encuentro la opción de seleccionar mi identidad, ¿qué reviso?**

Comprueba la identidad activa antes de publicar o contratar. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en seleccionar mi identidad?**

Una capacidad personal adicional no debe generar otra persona duplicada.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/gateway.js:113`, `web/js/modules/managed-profile-hub.js:79`, `web/js/modules/kombax-home.js:40`.

## Consultar y activar servicios

El perfil público y un servicio de pago son cosas distintas. Un perfil gratuito no incluye automáticamente venta, ticketing o todas las funciones de gestión.

Contexto: profile. Roles de la guía: todos. Tipos: marca, federacion, profesional, competidor. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Entra en el espacio de la identidad que utilizará el servicio.
2. Para Marca o Federación consulta Plan y servicios; para una activación puntual abre Events o Mi Showcase.
3. Completa la verificación que se solicite para ese servicio.
4. Revisa y confirma las condiciones en su formulario. La contratación pública puede seguir bloqueada durante el piloto.

### Comprobación y resolución
- Consulta el catálogo vigente y la identidad a la que se aplicará.
- La contratación pública nueva de Marca y Federación sigue bloqueada durante el piloto.
- Una prueba de 30 días necesita los requisitos y la confirmación que indique el flujo; no inventes precios ni fechas de renovación.

**No encuentro la opción de consultar y activar servicios, ¿qué reviso?**

Consulta el catálogo vigente y la identidad a la que se aplicará. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en consultar y activar servicios?**

Una prueba de 30 días necesita los requisitos y la confirmación que indique el flujo; no inventes precios ni fechas de renovación.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/plan-services.js:90`, `web/js/modules/organization-billing.js:6`.

## Editar foto, banner y perfil público

Editar foto, banner y perfil público

Contexto: profile. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Entra en la identidad correcta y abre Perfil público.
2. Pulsa Editar y selecciona la foto de perfil o el banner, según corresponda.
3. Guarda y revisa la vista pública.
4. Añadir una foto al álbum es una acción distinta de cambiar la foto principal.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

**No encuentro la opción de editar foto, banner y perfil público, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en editar foto, banner y perfil público?**

Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/public-profile.js:221`, `web/js/modules/profile-administration.js:7`, `web/js/modules/competitor-hub.js:2`, `web/js/modules/professional-hub.js:2`, `web/js/modules/spectator-hub.js:2`, `web/js/modules/fighter-discovery.js:24`, `web/js/modules/kombax-discovery.js:84`.

## Catálogo y activación como vendedor

Catálogo y activación como vendedor

Contexto: profile. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre Mi Showcase desde esta identidad.
2. Revisa la solicitud de vendedor y los requisitos comerciales.
3. Prepara la ficha y su documentación de seguridad cuando corresponda.
4. Publicar, vender y cobrar dependen de la verificación y del servicio activo.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

**No encuentro la opción de catálogo y activación como vendedor, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en catálogo y activación como vendedor?**

Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/showcase.js:83`, `web/js/modules/profile-operations.js:11`.

## Eventos y ticketing

Eventos y ticketing

Contexto: profile. Roles de la guía: todos. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre la gestión de eventos de tu identidad.
2. Prepara el evento, fechas y aforo.
3. Consulta la activación puntual y los requisitos del ticketing.
4. Completa los requisitos comerciales antes de publicar o cobrar entradas.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

**No encuentro la opción de eventos y ticketing, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en eventos y ticketing?**

Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/kombax-events.js:803`, `web/js/modules/professional-operations.js:34`, `web/js/modules/competition-preparation.js:73`, `web/js/modules/kombax-event-visuals.js:17`.

## Campañas y colaboraciones de marca

Campañas y colaboraciones de marca

Contexto: profile. Roles de la guía: todos. Tipos: marca. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. En Mi Marca abre Negocio y catálogo.
2. Elige Campañas o Colaboraciones.
3. Revisa las capacidades del plan y prepara la propuesta.
4. La ayuda no publica campañas ni confirma acuerdos.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

**No encuentro la opción de campañas y colaboraciones de marca, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en campañas y colaboraciones de marca?**

Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/brand-hub.js:2`, `web/js/modules/brand-business.js:55`.

## Gestión de federación y licencias

Gestión de federación y licencias

Contexto: profile. Roles de la guía: todos. Tipos: federacion. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Entra en Mi Federación.
2. Abre Gestión federativa y selecciona Federados, Licencias o Clubes relacionados.
3. Revisa las solicitudes y documentación antes de validarlas.
4. Las decisiones reservadas al titular conservan su autorización.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

**No encuentro la opción de gestión de federación y licencias, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en gestión de federación y licencias?**

Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/federation-hub.js:2`, `web/js/modules/federation-licenses.js:34`.

## Verificación y acreditaciones profesionales

Verificación y acreditaciones profesionales

Contexto: profile. Roles de la guía: todos. Tipos: profesional, competidor. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre el perfil público de la identidad correspondiente.
2. Completa los datos y aporta la documentación que solicite la verificación.
3. Para servicios específicos pueden exigirse acreditaciones adicionales.
4. Subir un documento no concede automáticamente una verificación.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

**No encuentro la opción de verificación y acreditaciones profesionales, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en verificación y acreditaciones profesionales?**

Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/professional-documents.js:6`.

## Crear un cargo manual

Un cargo registra un importe que corresponde pagar. Crearlo no mueve dinero; registrar un pago y ejecutar un cobro bancario son operaciones diferentes.

Contexto: club. Roles de la guía: direccion, secretaria, economia. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre Finanzas y pulsa + Nuevo cargo, si tu rol dispone de esa acción.
2. Escoge categoría y concepto; selecciona los alumnos, un grupo, una disciplina o todos los activos.
3. Indica importe, periodo y vencimiento; añade observaciones si hacen falta.
4. Revisa los destinatarios y el total antes de pulsar Crear cargos.
5. Comprueba el cargo en Cargos. Crear un cargo registra deuda; no ejecuta un cobro bancario.

### Comprobación y resolución
- Revisa alumno o familia destinatarios, concepto, importe y fecha antes de confirmar.
- Si se pierde la conexión, comprueba primero si el cargo ya existe antes de repetirlo.
- Conserva el histórico; no cambies un cargo pagado para corregir una tarifa futura.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de crear un cargo manual, ¿qué reviso?**

Revisa alumno o familia destinatarios, concepto, importe y fecha antes de confirmar. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en crear un cargo manual?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/finance-premium.js:60`, `web/js/modules/finance.js:99`.

## Registrar un pago o cobro parcial

Registrar un pago deja constancia del dinero recibido y de su relación con un cargo. No es lo mismo que crear el cargo ni implica por sí solo un cobro bancario.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, economia. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. En Finanzas, localiza el cargo pendiente del alumno y abre su detalle.
2. Utiliza la acción de cobro o registro de pago que tengas autorizada.
3. Indica importe, fecha y método. Para un pago parcial, registra solo lo recibido.
4. Confirma una sola vez y comprueba el saldo restante y el estado del pago.
5. Si el pago está pendiente de validación, aún no cuenta como cobrado. Revisa Pagos por validar.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de registrar un pago o cobro parcial, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en registrar un pago o cobro parcial?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/finance-premium.js:60`, `web/js/modules/finance.js:99`.

## Crear o cambiar la tarifa de un alumno

Cambiar una tarifa afecta a la configuración que corresponda; no debe confundirse con corregir cargos ya emitidos ni con devolver dinero.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, economia. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. En la vista que muestra Tarifas, pulsa Nueva tarifa o edita la tarifa disponible.
2. Revisa importe, periodicidad y matrícula antes de guardar.
3. Asigna la tarifa correspondiente desde la ficha del alumno cuando esa opción esté disponible.
4. El cambio de tarifa no modifica por sí solo los cargos ya emitidos.
5. Para un cargo erróneo, revisa si puede anularse sin pagos y crea el correcto; conserva los movimientos ya cobrados.

### Comprobación y resolución
- Identifica si quieres cambiar el precio futuro o un cargo concreto.
- Revisa el estado del cargo y los permisos antes de proponer una corrección.
- Si está pagado o conciliado, utiliza el procedimiento autorizado y conserva la trazabilidad.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de crear o cambiar la tarifa de un alumno, ¿qué reviso?**

Identifica si quieres cambiar el precio futuro o un cargo concreto. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en crear o cambiar la tarifa de un alumno?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/finance-premium.js:60`, `web/js/modules/finance.js:99`.

## Validar pagos comunicados

Validar pagos comunicados

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, economia. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre Finanzas y pulsa Pagos por validar.
2. Localiza al alumno y comprueba importe, cargo y justificante cuando exista.
3. Valida solo si el cobro está comprobado; si no corresponde, recházalo indicando el motivo.
4. Comprueba el nuevo estado y el saldo. No registres otra vez el mismo pago.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de validar pagos comunicados, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en validar pagos comunicados?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/finance-premium.js:60`, `web/js/modules/finance.js:99`.

## Generar un informe financiero PDF

Generar un informe financiero PDF

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, economia. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. En Finanzas, abre Informes o pulsa Generar informe.
2. Escoge el tipo de informe y los filtros de periodo, alumno, grupo o disciplina que necesites.
3. Revisa los datos incluidos y genera el informe con tu permiso autorizado.
4. Abre el PDF generado y comprueba periodo, importes y datos del club antes de compartirlo.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de generar un informe financiero pdf, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en generar un informe financiero pdf?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/finance-premium.js:60`, `web/js/modules/finance.js:99`.

## Preparar una automatización de cuotas

Una regla de cuotas puede prepararse, pero no implica que las automatizaciones de cobro estén activas en el piloto.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria, economia. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. En Finanzas, pulsa Nueva automatización.
2. Completa nombre, categoría, concepto, importe, periodicidad, fechas y destinatarios.
3. Guarda la regla en pausa durante el piloto; preparar la regla no cobra al alumno.
4. La generación automática exige comprobaciones y autorización del titular. Las automatizaciones de cobro siguen desactivadas.
5. Para operar ahora, utiliza Nuevo cargo manual y revisa los destinatarios antes de confirmar.

### Comprobación y resolución
- Mantén la regla en pausa durante el piloto.
- Crear cargos manuales no habilita por sí mismo domiciliaciones ni reintentos automáticos.
- No asegures que se cobrará en una fecha si no hay una activación confirmada.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de preparar una automatización de cuotas, ¿qué reviso?**

Mantén la regla en pausa durante el piloto. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en preparar una automatización de cuotas?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/finance-premium.js:60`.

## Explorar Social e interactuar

KOMBAX Social es el espacio para descubrir perfiles y contenido de la comunidad. Explorar y publicar tienen requisitos distintos; crear una cuenta no concede automáticamente permiso para publicar.

Contexto: public. Roles de la guía: según contexto. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre KOMBAX Social desde la navegación.
2. Explora publicaciones y perfiles públicos; inicia sesión para las interacciones que lo requieran.
3. Puedes usar las acciones visibles de comentar, dar me gusta o guardar según tu cuenta.
4. Para publicar necesitas una identidad con autorización. Un perfil espectador no obtiene permiso de publicar.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

**No encuentro la opción de explorar social e interactuar, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en explorar social e interactuar?**

Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/kombax-social.js:345`.

## Publicar en KOMBAX Social

Explorar Social y publicar tienen requisitos distintos. La identidad elegida se conserva; no se cambia a Club o Marca para esquivar un bloqueo de otra identidad.

Contexto: public. Roles de la guía: según contexto. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre KOMBAX Social y comprueba la identidad desde la que vas a publicar.
2. Utiliza Crear publicación si esa identidad tiene publicación habilitada.
3. Completa el contenido y adjunta el material admitido; revisa la vista previa.
4. Publica y comprueba que aparece con el autor correcto.
5. Si está bloqueado, revisa la verificación o la vinculación al club. No cambies de identidad para eludir el bloqueo.

### Comprobación y resolución
- Comprueba qué perfil aparece como autor.
- Un Espectador interactúa pero no obtiene publicación por crear la cuenta.
- Un Miembro necesita una vinculación aprobada al club; el resto de perfiles debe cumplir su validación correspondiente.

**No encuentro la opción de publicar en kombax social, ¿qué reviso?**

Comprueba qué perfil aparece como autor. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en publicar en kombax social?**

Un Miembro necesita una vinculación aprobada al club; el resto de perfiles debe cumplir su validación correspondiente.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/kombax-social.js:345`, `web/js/modules/social-post-management.js:10`, `web/js/modules/instagram-integration.js:12`.

## Editar foto, banner y álbum

Foto de perfil, banner y álbum son destinos distintos. Una imagen subida al álbum no se convierte automáticamente en el avatar.

Contexto: public. Roles de la guía: según contexto. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre el perfil público de la identidad que quieres modificar.
2. Usa el control específico de foto o logo para cambiar la imagen de perfil, y el de banner para la portada.
3. Para añadir fotografías al álbum utiliza la sección Álbum, que es independiente del logo.
4. Para retirar una fotografía propia, usa su acción de eliminar cuando esté disponible y confirma la selección.
5. Comprueba el resultado en ese mismo perfil; los archivos compartidos por otro contenido pueden conservarse mientras sigan en uso.

### Comprobación y resolución
- Selecciona específicamente la acción de foto de perfil o banner.
- Revisa formato y tamaño indicados en el formulario.
- Comprueba el perfil público después de guardar y que no hayas cambiado solo la imagen administrativa.

**No encuentro la opción de editar foto, banner y álbum, ¿qué reviso?**

Selecciona específicamente la acción de foto de perfil o banner. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en editar foto, banner y álbum?**

Comprueba el perfil público después de guardar y que no hayas cambiado solo la imagen administrativa.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/public-profile.js:221`, `web/js/modules/social-post-management.js:10`, `web/js/modules/media-content-center.js:9`.

## Explorar productos en Showcase

KOMBAX Showcase es el catálogo donde puedes explorar productos y servicios de la comunidad. Explorar o comprar no te convierte en vendedor autorizado.

Contexto: public. Roles de la guía: según contexto. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre KOMBAX Showcase; explorar está disponible para las cuentas gratuitas.
2. Utiliza los filtros y la vista de cuadrícula grande, compacta o lista cuando estén disponibles.
3. Abre un producto para revisar imágenes, descripción y vendedor.
4. Comprar, publicar un catálogo y vender son funciones distintas; revisar productos no te convierte en vendedor autorizado.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

**No encuentro la opción de explorar productos en showcase, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en explorar productos en showcase?**

Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/showcase.js:83`, `web/js/modules/showcase-cart.js:19`.

## Publicar o retirar un producto

Explorar y comprar en Showcase no convierte una cuenta en vendedor. Publicar, vender y cobrar tienen sus propios requisitos.

Contexto: public. Roles de la guía: según contexto. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Entra en Mi Showcase de la identidad propietaria del catálogo.
2. Comprueba que la verificación y el servicio correspondiente están habilitados para esa operación.
3. Crea o edita el producto con sus imágenes, precio y disponibilidad; revisa antes de publicar.
4. Para retirarlo utiliza la acción disponible sobre ese producto. La eliminación depende de tus permisos y de sus operaciones asociadas.
5. Un perfil público gratuito no habilita por sí solo la venta ni el cobro.

### Comprobación y resolución
- Comprueba la identidad vendedora seleccionada.
- Preparar una solicitud no sustituye su verificación ni la activación comercial.
- Un permiso de publicación promocional no demuestra que Stripe esté habilitado para cobrar.

**No encuentro la opción de publicar o retirar un producto, ¿qué reviso?**

Comprueba la identidad vendedora seleccionada. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en publicar o retirar un producto?**

Un permiso de publicación promocional no demuestra que Stripe esté habilitado para cobrar.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/showcase.js:83`, `web/js/modules/showcase-compliance.js:4`.

## Descubrir eventos y consultar entradas

KOMBAX Events es el espacio para descubrir eventos, consultar su información y acceder a las opciones disponibles de participación o entradas. Organizar y vender entradas requieren sus propias activaciones.

Contexto: public. Roles de la guía: según contexto. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre KOMBAX Events y busca el evento o seminario.
2. Revisa organizador, lugar, fecha, condiciones y entradas disponibles.
3. Si hay ticketing activo, selecciona la entrada y sigue el proceso de compra mostrado.
4. Conserva la confirmación y consulta tus entradas desde el acceso disponible en tu cuenta.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

**No encuentro la opción de descubrir eventos y consultar entradas, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en descubrir eventos y consultar entradas?**

Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/kombax-events.js:803`.

## Preparar un evento y su ticketing

Crear o preparar un evento, publicarlo, activar ticketing y cobrar entradas son pasos distintos.

Contexto: public. Roles de la guía: según contexto. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Entra en Mis eventos de la identidad organizadora autorizada.
2. Prepara título, descripción, fechas, ubicación e imágenes y revisa la información del organizador.
3. La publicación del evento y el ticketing requieren sus capacidades o activaciones correspondientes.
4. Configura aforo, entradas y el logo del ticket cuando la función esté habilitada; revisa la vista previa.
5. Publicar un evento no activa automáticamente los cobros: comprueba el estado del vendedor u organizador y de Stripe.

### Comprobación y resolución
- Revisa organizador, fechas, aforo y las activaciones que correspondan.
- Selecciona el logo del ticket en el flujo disponible, sin confundirlo con el logo público de la entidad.
- No anuncies venta habilitada hasta que el estado de activación lo confirme.

**No encuentro la opción de preparar un evento y su ticketing, ¿qué reviso?**

Revisa organizador, fechas, aforo y las activaciones que correspondan. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en preparar un evento y su ticketing?**

No anuncies venta habilitada hasta que el estado de activación lo confirme.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/kombax-events.js:803`, `web/js/modules/event-connections.js:67`.

## Consultar datos con Assist

Assist interpreta información autorizada del espacio activo; Ayuda explica la plataforma y Migrations prepara incorporaciones de archivos.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre Administración y selecciona KOMBAX Assist.
2. Pregunta directamente por el dato que necesitas, por ejemplo el saldo de un alumno o los próximos eventos.
3. Assist utiliza el contexto autorizado de tu club; comprueba que estás en el espacio correcto.
4. Para aprender un procedimiento usa ¿Necesitas ayuda?; para importar archivos usa Migrations.
5. Las consultas IA mantienen el cupo y los créditos de tu plan. Una respuesta no equivale a haber ejecutado un cobro o una modificación.

### Comprobación y resolución
- No interpretes datos ausentes como deuda cero.
- No pidas datos bancarios ni secretos por el chat.
- El saldo de IA de pago se comparte con los canales que corresponden al mismo espacio.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de consultar datos con assist, ¿qué reviso?**

No interpretes datos ausentes como deuda cero. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en consultar datos con assist?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/customer-operations.js:316`.

## Importar datos con Migrations

Migrations prepara datos de archivos para revisión; una vista previa no demuestra que ya estén incorporados.

Contexto: club. Roles de la guía: direccion, coordinacion, secretaria. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Abre Administración y selecciona Migrations.
2. Indica qué quieres importar y adjunta el archivo admitido con los datos que puedes gestionar.
3. Revisa la identificación de columnas, posibles duplicados y datos pendientes.
4. Corrige las incidencias y revisa la propuesta antes de confirmar la importación.
5. Comprueba el resultado en el módulo de destino. No envíes contraseñas ni archivos ajenos al trámite.

### Comprobación y resolución
- Comprueba columnas, disciplinas, grupos y registros duplicados antes de confirmar.
- Verifica la entidad y el tipo de dato antes de aplicar una importación.
- Los documentos personales no deben transformarse en fichas del club sin el flujo autorizado.
- Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

**No encuentro la opción de importar datos con migrations, ¿qué reviso?**

Comprueba columnas, disciplinas, grupos y registros duplicados antes de confirmar. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en importar datos con migrations?**

Si el acceso corresponde a un tutor, comprueba el alumno seleccionado y el vínculo autorizado antes de mostrar o cambiar datos.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/customer-operations.js:316`.

## Crear una identidad o perfil público

Una identidad indica desde qué perfil participas o gestionas KOMBAX. Una cuenta puede reunir varias identidades, conservando separados los espacios y permisos correspondientes.

Contexto: public. Roles de la guía: según contexto. Tipos: según contexto. Las restricciones adicionales del backend prevalecen.

### Requisitos
- Revisar contexto y permiso vigente.

### Procedimiento
1. Accede a tu cuenta y abre Crear o gestionar mi perfil o Gestionar mi cuenta e identidades.
2. Elige Añadir capacidad o vinculación y el tipo de perfil que necesitas.
3. Completa la presentación y guarda el borrador; revisa las condiciones y los datos requeridos.
4. Solicita la verificación cuando corresponda. Crear un perfil no activa una suscripción ni la publicación automáticamente.
5. Club, Marca y Federación tienen sus propios perfiles públicos; las capacidades de una persona se gestionan desde su identidad personal.

### Comprobación y resolución
- Comprueba la cuenta, el espacio y la identidad activos.
- Comprueba que tu rol tenga acceso a la opción y revisa los requisitos indicados.
- Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

**No encuentro la opción de crear una identidad o perfil público, ¿qué reviso?**

Comprueba la cuenta, el espacio y la identidad activos. El acceso depende del contexto y los permisos.

**¿Cómo compruebo el resultado en crear una identidad o perfil público?**

Vuelve a abrir el registro después de guardar para confirmar el resultado; un mensaje enviado no demuestra que una operación haya terminado.

Pide ayuda humana si persiste el fallo después de comprobar el contexto o si exige una decisión sensible. Facilita fecha, pantalla y un resumen sin contraseñas, tokens ni datos de menores. No hagas repetir información ya disponible.

Fuentes: `web/js/modules/gateway.js:113`, `web/js/modules/professional-documents.js:6`.

## Casos especializados de atención

### Cuenta gratuita y perfil público

Crear la cuenta permite acceder y explorar. El perfil público representa tu identidad en la comunidad; son dos pasos diferentes.

Guía y permisos de origen: `account-create`.

1. Crea o accede a tu cuenta.
2. Desde la gestión de identidades, elige el tipo de perfil que te corresponde.

Comprobación: No crees otra cuenta solo para añadir una identidad.

Fuente: `web/js/modules/gateway.js:48`.

### Acceder con una cuenta ya creada

Si ya tienes cuenta, utiliza su correo y contraseña. Los datos exclusivos de una cuenta nueva no deben obligarte a duplicarla.

Guía y permisos de origen: `account-login`.

1. Selecciona la opción de cuenta existente.
2. Si no recuerdas la contraseña, utiliza su recuperación.

Comprobación: No compartas la contraseña con el club ni con el chatbot.

Fuente: `web/js/modules/gateway.js:725`.

### Un correo y varias identidades

Club, Marca y Federación son identidades separadas con sus espacios y perfiles públicos propios. La cuenta puede administrarlas juntas.

Guía y permisos de origen: `identity-choose`.

1. Abre la selección de identidad.
2. Comprueba el nombre antes de publicar, editar o activar servicios.

Comprobación: No cambies de identidad para esquivar una limitación.

Fuente: `web/js/modules/managed-profile-hub.js:1`.

### Archivar o eliminar una identidad

Archivar es una organización administrativa reversible. Solicitar la eliminación de una identidad sigue su trámite; no equivale a borrar toda la cuenta.

Guía y permisos de origen: `identity-choose`.

1. Abre la administración de esa identidad.
2. Revisa el alcance antes de archivar o solicitar su eliminación.

Comprobación: El archivo no cancela suscripciones ni retira automáticamente contenido público.

Fuente: `web/js/modules/profile-administration.js:18`.

### Solicitud para entrar a un club

Pedir acceso, recibir aprobación y quedar vinculado al club son estados distintos. Tener una cuenta no confirma la membresía.

Guía y permisos de origen: `enrollments`.

1. Selecciona el club y la vía de solicitud disponible.
2. Comprueba el estado de la solicitud antes de repetirla.

Comprobación: No utilices una solicitud de equipo para entrar como alumno.

Fuente: `web/js/modules/portal.js:89`.

### Una familia con varios hijos

Cada hijo mantiene su propia ficha y relaciones deportivas. El adulto se vincula como familiar o tutor autorizado, sin fusionar las fichas.

Guía y permisos de origen: `students`.

1. Busca o crea por separado la ficha de cada hijo.
2. Comprueba qué hijo tienes seleccionado antes de revisar su actividad o sus cuotas.

Comprobación: No uses la cuenta de un hermano para modificar los datos de otro.

Fuente: `web/js/modules/groups-members.js:13`.

### Varias disciplinas para el mismo alumno

Una misma ficha puede relacionarse con varias disciplinas y grupos. No necesitas duplicar al alumno para cada deporte.

Guía y permisos de origen: `groups`.

1. Abre la ficha del alumno en el club.
2. Añade las relaciones de disciplina y grupo que correspondan.

Comprobación: Vuelve a abrir la ficha para confirmar que se han conservado las relaciones anteriores.

Fuente: `web/js/modules/groups-members.js:21`.

### Grupos de mañana y tarde

El grupo organiza entrenamiento y horario; pertenecer a dos grupos no exige tener dos identidades.

Guía y permisos de origen: `groups`.

1. Revisa la disciplina y los grupos disponibles.
2. Comprueba por separado las asignaciones del alumno.

Comprobación: No sustituyas involuntariamente la asignación anterior al añadir otra.

Fuente: `web/js/modules/groups-members.js:23`.

### Grados y colores por disciplina

Cada disciplina tiene su propia lista de grados. El color o nombre de un grado no demuestra equivalencia entre disciplinas.

Guía y permisos de origen: `catalog`.

1. Selecciona la disciplina.
2. Revisa sus grados y asigna el que corresponda al alumno.

Comprobación: Comprueba la disciplina antes de cambiar un grado.

Fuente: `web/js/modules/dashboard-catalog.js:64`.

### Varios coordinadores y secretarios

Varias personas pueden compartir un rol del equipo. El titular conserva la propiedad y las decisiones reservadas de la cuenta del club.

Guía y permisos de origen: `team`.

1. Gestiona cada solicitud o invitación de forma individual.
2. El titular asigna el rol correspondiente a cada persona.

Comprobación: Compartir el rol no significa compartir contraseñas.

Fuente: `web/js/modules/admin.js:29`.

### Cambiar el rol o revocar a un miembro del equipo

El titular puede gestionar roles y retirar el acceso de un miembro del equipo. Eso no elimina la cuenta global de esa persona.

Guía y permisos de origen: `team`.

1. Abre Equipo desde la administración titular.
2. Selecciona al miembro y revisa el cambio o revocación disponible.

Comprobación: Coordinación no adquiere permiso para cambiar planes o administrar roles del equipo.

Fuente: `web/js/modules/admin.js:5`.

### Permisos del monitor y ámbitos asignados

Un rol y su ámbito son cosas diferentes: un monitor puede estar limitado a ciertos grupos o disciplinas.

Guía y permisos de origen: `scopes`.

1. Revisa la asignación del miembro del equipo.
2. Comprueba sus ámbitos además del nombre del rol.

Comprobación: No amplíes el acceso como solución automática a un error.

Fuente: `web/js/modules/work-scopes.js:11`.

### Sesiones, clases y recurrencia

Una sesión es una actividad programada. La recurrencia prepara repeticiones según el flujo disponible; no es un cobro recurrente.

Guía y permisos de origen: `sessions`.

1. Selecciona el grupo o disciplina y las fechas.
2. Revisa las sesiones creadas antes de repetir el proceso.

Comprobación: Comprueba si ya existe la sesión para evitar duplicados.

Fuente: `web/js/modules/training.js:14`.

### Registrar asistencia al alumno correcto

La asistencia relaciona al alumno con una sesión concreta; no sustituye su matrícula o su asignación al grupo.

Guía y permisos de origen: `attendance`.

1. Abre la sesión correcta.
2. Revisa su lista antes de marcar asistencias.

Comprobación: Comprueba fecha, grupo y alumno si no aparece alguien.

Fuente: `web/js/modules/training.js:51`.

### Varias cuotas o cargos para una familia

Un alumno o familia puede tener cargos por distintos conceptos. Cada cargo conserva su importe, vencimiento y estado.

Guía y permisos de origen: `charge-create`.

1. Revisa los cargos existentes antes de crear otro.
2. Comprueba concepto y destinatarios en Nuevo cargo.

Comprobación: No repitas el cargo si el fallo fue solo de conexión sin revisar primero el listado.

Fuente: `web/js/modules/finance-premium.js:67`.

### Pagos parciales y saldo pendiente

Un cargo y los pagos asociados se revisan por separado. Un estado parcial indica que no todo el importe figura pagado.

Guía y permisos de origen: `payment-record`.

1. Abre el cargo y revisa sus pagos.
2. Registra solo el importe recibido por el método disponible.

Comprobación: No registres como recibido un dinero que todavía no se ha cobrado.

Fuente: `web/js/modules/finance-premium.js:17`.

### Cambiar una tarifa o un cargo ya emitido

La tarifa configura condiciones económicas; un cargo emitido ya tiene su propio historial. Cambiar una no corrige automáticamente el otro.

Guía y permisos de origen: `tariff-change`.

1. Identifica si el cambio es para próximas cuotas o para un cargo existente.
2. Revisa el estado y las acciones autorizadas del cargo.

Comprobación: Un cargo pagado requiere conservar la trazabilidad; no borres el pago para ocultar una corrección.

Fuente: `web/js/modules/finance-premium.js:22`.

### Antigüedad del alumno y cobros anteriores

La antigüedad deportiva o de alta y los movimientos históricos son datos distintos. Registrar un histórico no ejecuta un cobro nuevo.

Guía y permisos de origen: `finance`.

1. Revisa las fechas y los conceptos históricos.
2. Comprueba si se trata de deuda pendiente o de un pago ya recibido.

Comprobación: No dupliques un movimiento que ya está registrado en el periodo actual.

Fuente: `web/js/modules/historical-finance.js:6`.

### Recibos y logo del club

El recibo debe corresponder al movimiento y al club correctos. La imagen del recibo no sustituye la comprobación de que el pago exista.

Guía y permisos de origen: `receipts`.

1. Revisa el cargo y su pago asociado.
2. Genera el recibo desde el flujo del club.

Comprobación: Comprueba el documento generado antes de enviarlo a la familia.

Fuente: `web/js/modules/finance-premium.js:93`.

### Una automatización no equivale a cobrar

Preparar una regla y tener cobros automáticos activos son cosas diferentes. Las automatizaciones de cobro del piloto permanecen desactivadas.

Guía y permisos de origen: `automation-prepare`.

1. Prepara y revisa la regla en pausa.
2. Utiliza los cargos manuales autorizados para la operativa actual.

Comprobación: No prometas una domiciliación automática por haber guardado una regla.

Fuente: `web/js/modules/finance-premium.js:94`.

### Explorar Social sin tener perfil público

Puedes explorar con tu cuenta. El perfil público te presenta ante la comunidad; si no lo tienes, se ofrece su creación sin impedir seguir explorando.

Guía y permisos de origen: `social-explore`.

1. Explora el contenido disponible.
2. Usa Crear mi perfil público cuando quieras completar tu presencia.

Comprobación: Crear un perfil no habilita automáticamente publicar.

Fuente: `web/js/modules/kombax-social.js:27`.

### Publicar como club o como persona

La publicación pertenece a la identidad seleccionada. El Club tiene su perfil propio y no debe confundirse con la identidad personal del administrador.

Guía y permisos de origen: `social-publish`.

1. Comprueba el autor visible en el formulario.
2. Publica solo si esa identidad tiene la capacidad habilitada.

Comprobación: No se debe cambiar automáticamente a otra identidad para saltar un bloqueo.

Fuente: `web/js/modules/kombax-social.js:8`.

### El Espectador y el Miembro en Social

El Espectador puede interactuar según los permisos disponibles. Para publicar como Miembro se necesita la vinculación aprobada al club.

Guía y permisos de origen: `social-publish`.

1. Selecciona tu perfil público.
2. Comprueba la vinculación o verificación que indique el formulario.

Comprobación: Tener una cuenta gratuita no concede por sí solo publicación.

Fuente: `web/js/modules/kombax-social.js:9`.

### Foto de perfil, banner o foto del álbum

Avatar, portada y álbum son imágenes con destinos distintos. Subir una imagen al álbum no cambia por sí solo la foto de perfil.

Guía y permisos de origen: `social-media`.

1. Elige la acción específica de editar foto o banner.
2. Guarda y comprueba la vista pública del perfil correcto.

Comprobación: La imagen del espacio administrativo puede ser distinta de la del perfil público.

Fuente: `web/js/modules/public-profile.js:32`.

### Eliminar una imagen del álbum propio

La capacidad de eliminar se comprueba sobre el contenido y el perfil autorizado. Retirar una publicación no equivale necesariamente a borrar el archivo asociado.

Guía y permisos de origen: `social-media`.

1. Abre el contenido desde su perfil o álbum.
2. Utiliza la acción de gestión que corresponda y revisa el resultado.

Comprobación: No afirmes que un archivo se ha eliminado definitivamente hasta que el sistema lo confirme.

Fuente: `web/js/modules/social-post-management.js:24`.

### Vistas compacta, grande y lista

Las vistas permiten comparar más productos o ver más detalle. Cambiar la vista no cambia el producto ni concede permiso de edición.

Guía y permisos de origen: `showcase-explore`.

1. Utiliza el selector de vista del catálogo.
2. Combínalo con búsqueda y categorías.

Comprobación: Si falta una imagen, revisa la ficha del producto; no es un permiso de vendedor.

Fuente: `web/js/modules/showcase.js:1`.

### Preparar una solicitud de vendedor

La solicitud puede prepararse antes de tener venta habilitada. La autorización de vendedor y la activación comercial siguen siendo necesarias para vender y cobrar.

Guía y permisos de origen: `showcase-publish`.

1. Abre el trámite desde la identidad correcta.
2. Completa los requisitos y revisa el estado de la solicitud.

Comprobación: Explorar Showcase no es un plan de vendedor gratuito.

Fuente: `web/js/modules/showcase-compliance.js:36`.

### Dos marcas y dos tiendas separadas

Cada tienda debe abrirse con el contexto de la entidad seleccionada. No debe usarse por defecto la primera marca de la cuenta.

Guía y permisos de origen: `showcase-publish`.

1. Selecciona la Marca o Club.
2. Comprueba qué entidad figura en Mi Showcase antes de editar.

Comprobación: No muevas productos entre identidades para sortear una activación pendiente.

Fuente: `web/js/modules/showcase.js:23`.

### Carrito, pedidos y consultas

Guardar un producto, consultar al vendedor y realizar un pedido son acciones diferentes. Un carrito no confirma que el pago haya terminado.

Guía y permisos de origen: `showcase-explore`.

1. Revisa producto, vendedor y condiciones.
2. Comprueba el estado final del pedido o pago en su flujo.

Comprobación: No repitas una compra si no sabes si la operación anterior se completó.

Fuente: `web/js/modules/showcase-cart.js:6`.

### Descubrir eventos y comprar entradas

La ficha del evento muestra la información publicada y las opciones disponibles. Ver el evento no significa tener una inscripción o entrada confirmada.

Guía y permisos de origen: `events-explore`.

1. Revisa fecha, lugar y condiciones.
2. Usa el flujo de entrada o inscripción que esté habilitado.

Comprobación: Comprueba el estado final antes de considerar confirmada la asistencia.

Fuente: `web/js/modules/kombax-events.js:11`.

### Organizador profesional sin suscripción de club

La organización de eventos puede apoyarse en activaciones puntuales autorizadas. No debe exigirse una suscripción de club a todo organizador por defecto.

Guía y permisos de origen: `events-create`.

1. Usa la identidad profesional verificada que corresponda.
2. Revisa los servicios de evento y ticketing disponibles para activación.

Comprobación: Crear un borrador no activa venta de entradas.

Fuente: `web/js/modules/professional-operations.js:21`.

### Logo y presentación del ticket

La presentación del ticket se revisa en su propio flujo. No debe confundirse con el logo del perfil público del organizador.

Guía y permisos de origen: `events-create`.

1. Revisa la configuración de ticketing.
2. Comprueba el ticket generado antes de distribuirlo.

Comprobación: No publiques datos de acceso o códigos de una entrada en Social.

Fuente: `web/js/modules/kombax-events.js:111`.

### Acreditaciones profesionales y visibilidad

La verificación general y una acreditación para un servicio concreto pueden ser requisitos distintos. Un documento subido no queda automáticamente validado.

Guía y permisos de origen: `profile-documents`.

1. Completa la profesión y los documentos que correspondan.
2. Revisa qué información se hace pública antes de mostrarla.

Comprobación: No publiques documentos personales completos si contienen datos que deben permanecer privados.

Fuente: `web/js/modules/professional-documents.js:6`.

### Competidor: disponibilidad y descubrimiento

El perfil del competidor reúne su información deportiva y sus herramientas. La aparición verificada y las capacidades dependen del estado autorizado.

Guía y permisos de origen: `profile-public`.

1. Revisa la identidad Competidor seleccionada.
2. Completa su información pública y comprueba la disponibilidad que muestre el perfil.

Comprobación: Las excepciones de piloto no deben extenderse a cualquier cuenta nueva.

Fuente: `web/js/modules/competitor-hub.js:2`.

### Marca: campañas y colaboraciones

Las campañas y propuestas se gestionan desde la Marca activa y sus capacidades habilitadas. Descubrir colaboradores no autoriza usar cualquier dato privado.

Guía y permisos de origen: `profile-brand`.

1. Revisa campañas, descubrimiento y propuestas de la marca.
2. Usa únicamente los contactos públicos habilitados y las autorizaciones de colaboración.

Comprobación: El perfil público gratuito no equivale a un servicio comercial activado.

Fuente: `web/js/modules/brand-business.js:9`.

### Federación: clubes, federados y licencias

La Federación tiene su espacio e información propios. La licencia requiere su ámbito, estado y validación; no se deduce de una insignia social.

Guía y permisos de origen: `profile-federation`.

1. Revisa el contexto de Federación.
2. Consulta el expediente o solicitud que corresponda con tu rol autorizado.

Comprobación: No confirmes vigencia o aprobación de una licencia sin el dato verificado.

Fuente: `web/js/modules/federation-licenses.js:9`.

### Conectar Instagram y compartir contenido

Compartir un enlace y publicar mediante una conexión oficial son vías distintas. La conexión depende de la cuenta profesional y los permisos que Meta autorice.

Guía y permisos de origen: `social-publish`.

1. Abre la conexión de Instagram desde la identidad correcta.
2. Completa el consentimiento oficial y comprueba el estado de conexión.

Comprobación: No envíes claves ni tokens por el chat. Una publicación real necesita autorización del usuario.

Fuente: `web/js/modules/instagram-integration.js:5`.

### Desconectar Instagram y eliminar datos de conexión

Desconectar la cuenta y solicitar la eliminación de datos de la integración son operaciones distintas. No equivalen a borrar la cuenta de KOMBAX.

Guía y permisos de origen: `social-publish`.

1. Utiliza la opción de desconexión o el procedimiento de privacidad correspondiente.
2. Comprueba el resultado antes de intentar publicar de nuevo.

Comprobación: No se deben seguir utilizando permisos de una conexión revocada.

Fuente: `web/js/modules/instagram-integration.js:38`.

### Diferencia entre Ayuda, Assist y Migrations

Ayuda explica la plataforma. Assist interpreta datos autorizados del espacio. Migrations prepara la incorporación de archivos para revisión.

Guía y permisos de origen: `assist-data`.

1. Elige el canal según lo que necesitas.
2. Indica el objetivo con lenguaje natural, sin copiar secretos.

Comprobación: El contexto disponible y los permisos limitan lo que puede responder cada canal.

Fuente: `web/js/modules/customer-operations.js:6`.

### Créditos y límites compartidos de IA

Las cuentas gratuitas tienen el límite de ayuda IA establecido. En los espacios de pago se aplican el saldo y los límites compartidos que autorice el plan.

Guía y permisos de origen: `assist-data`.

1. Consulta el saldo disponible en tu espacio.
2. Las guías siguen siendo una alternativa cuando no procede usar IA.

Comprobación: No prometas consultas ilimitadas ni cambies al contexto de otra entidad para consumir su saldo.

Fuente: `web/js/modules/customer-operations.js:41`.

### Vista previa, duplicados y confirmación de importación

Una extracción o vista previa prepara los datos. La importación solo se considera aplicada cuando el flujo autorizado confirma su resultado.

Guía y permisos de origen: `migrations-import`.

1. Revisa los campos, filas y avisos de duplicados.
2. Comprueba disciplinas y grupos antes de confirmar.

Comprobación: No importes fichas de menores en un club distinto ni interpretes todo documento como un listado de alumnos.

Fuente: `web/js/modules/customer-operations.js:10`.

### Archivar documentos y recuperar

La documentación tiene su ámbito de acceso y su ciclo de vida. Archivar no implica necesariamente eliminar el archivo de almacenamiento.

Guía y permisos de origen: `documents`.

1. Selecciona el documento correcto.
2. Revisa la acción y el estado resultante.

Comprobación: No borres historial financiero o legal para ocultar un movimiento.

Fuente: `web/js/modules/documents.js:12`.

### Guías, consultoría y recursos

Las guías proporcionan información de uso. La consultoría y la formación pueden tener sus propios requisitos o activaciones.

Guía y permisos de origen: `start`.

1. Abre Recursos KOMBAX.
2. Revisa la guía del tema antes de solicitar una revisión personalizada.

Comprobación: No inventes una tarifa automática de consultoría ni una activación contractual.

Fuente: `web/js/modules/resource-center.js:7`.

### PWA, actualización y conexión

La instalación facilita acceder a la webapp. No garantiza que una operación que necesita servidor funcione sin conexión.

Guía y permisos de origen: `install`.

1. Usa la instalación disponible en tu navegador.
2. Si hay un error al guardar, comprueba el resultado cuando recuperes conexión.

Comprobación: No des por realizada una escritura solo porque la pantalla permanezca abierta.

Fuente: `web/js/modules/pwa-install.js:1`.

### Privacidad, datos de menores y ayuda humana

El chatbot puede explicar el procedimiento de privacidad, pero no debe solicitar contraseñas ni ejecutar por sí solo decisiones sensibles sobre cuentas o menores.

Guía y permisos de origen: `privacy`.

1. Utiliza el canal y trámite autorizado para tu solicitud.
2. Facilita solo la información necesaria para identificar el problema.

Comprobación: Una autorización del club no sustituye el permiso de acceso a los datos de otro usuario.

Fuente: `web/js/modules/support-privacy.js:35`.


## Ampliaciones y límites de integración

Instagram: conectar la cuenta profesional mediante la configuración Meta autorizada; conexión, permiso de publicar y autorización de una publicación real son estados distintos. No prometer compatibilidad con cuentas personales ni App Review completado sin comprobarlo.

Los precios, límites comerciales y condiciones deben consultarse en el catálogo vigente. La guía no reactiva automáticamente contratación bloqueada ni automatizaciones de cobro.

## Anexo Owner · uso administrativo privado

### Owner Operations

Clasifica solicitudes, documentación y pendientes con el snapshot autorizado. Recomienda acciones; no sustituye los controles deterministas ni la revisión de casos sensibles.

### Pilot Intelligence

Analiza métricas agregadas del piloto, adopción, incidencias y bloqueos. Un error de una fuente no debe presentarse como un cero confirmado.

### Bandeja documental

Adjunta hasta tres documentos autorizados de la bandeja privada. Los documentos no son instrucciones para modificar permisos ni publicar conocimiento.

### Informes y PDF privados

Los informes son borradores privados, con fecha, alcance, fuentes, hallazgos y próximos pasos. Los enlaces de descarga caducan. No exportar por defecto expedientes de menores o documentos de identidad.

### Revisión del conocimiento

Las observaciones se revisan antes de publicar una aclaración general. Nunca convertir automáticamente una respuesta del modelo en una regla de la plataforma.

### Moderación

Revisar contenido Social y productos Showcase con sus medios, motivo y resultado. Retirar y eliminar definitivamente son operaciones diferentes. Confirmar el estado público sin borrar trazas legalmente necesarias.

### Soporte y diagnóstico

Separar error de sesión, permisos, datos, proveedor IA y PDF. Conservar referencia del turno y estado final; no dejar una consulta fallida presentada como pendiente para siempre.

## Inventario completo de módulos

Se han indexado 72 módulos, sus exportaciones, llamadas a repositorios y dependencias. Cada fichero tiene una huella SHA-256 en AUDITORIA_MODULOS_R278.json. Los módulos sin capítulo directo son infraestructura o requieren ampliar la revisión; no se declaran cubiertos por inferencia.

| Módulo | Líneas | Guías vinculadas |
|---|---:|---|
| `web/js/modules/account-birth-date.js` | 32 | account-create |
| `web/js/modules/account-security.js` | 32 | privacy |
| `web/js/modules/admin.js` | 200 | team, settings |
| `web/js/modules/auth-recovery.js` | 55 | access, account-login |
| `web/js/modules/brand-business.js` | 113 | profile-brand |
| `web/js/modules/brand-hub.js` | 2 | profile-brand |
| `web/js/modules/club-kombax-hub.js` | 86 | profile |
| `web/js/modules/club-poster.js` | 23 | profile |
| `web/js/modules/club-profile.js` | 113 | profile |
| `web/js/modules/comms-material.js` | 216 | reminders, communications, material, member-comms, member-material |
| `web/js/modules/community.js` | 151 | community, member-community |
| `web/js/modules/competition-preparation.js` | 120 | profile-events |
| `web/js/modules/competitor-hub.js` | 2 | profile-public |
| `web/js/modules/consulting.js` | 21 | start |
| `web/js/modules/customer-operations.js` | 556 | assist-data, migrations-import |
| `web/js/modules/dashboard-catalog.js` | 82 | start, catalog |
| `web/js/modules/documents.js` | 76 | documents |
| `web/js/modules/event-connections.js` | 105 | events-create |
| `web/js/modules/events.js` | 164 | events, member-events |
| `web/js/modules/federation-hub.js` | 2 | profile-federation |
| `web/js/modules/federation-licenses.js` | 188 | profile-federation |
| `web/js/modules/fighter-discovery.js` | 47 | profile-public |
| `web/js/modules/finance-context.js` | 37 | finance |
| `web/js/modules/finance-guide.js` | 22 | finance |
| `web/js/modules/finance-premium-bootstrap.js` | 39 | finance |
| `web/js/modules/finance-premium.js` | 223 | finance, receipts, charge-create, payment-record, tariff-change, payment-validate, finance-report, automation-prepare |
| `web/js/modules/finance.js` | 229 | finance, receipts, reminders, charge-create, payment-record, tariff-change, payment-validate, finance-report |
| `web/js/modules/gateway.js` | 939 | access, account-create, account-login, identity-choose, identity-create |
| `web/js/modules/groups-members.js` | 139 | enrollments, students, groups |
| `web/js/modules/guides.js` | 38 | start |
| `web/js/modules/help-legal.js` | 133 | privacy |
| `web/js/modules/historical-finance.js` | 29 | finance |
| `web/js/modules/instagram-integration.js` | 64 | social-publish |
| `web/js/modules/kombax-discovery.js` | 111 | profile-public |
| `web/js/modules/kombax-event-visuals.js` | 54 | profile-events |
| `web/js/modules/kombax-events.js` | 1534 | events, profile-events, events-explore, events-create |
| `web/js/modules/kombax-home.js` | 69 | identity-choose |
| `web/js/modules/kombax-social.js` | 752 | social, member-social, social-explore, social-publish |
| `web/js/modules/lifecycle.js` | 46 | archive |
| `web/js/modules/managed-profile-hub.js` | 170 | identity-choose |
| `web/js/modules/media-content-center.js` | 36 | social-media |
| `web/js/modules/moderation-notices.js` | 11 | privacy |
| `web/js/modules/organization-billing.js` | 28 | service-activate |
| `web/js/modules/owner-content-moderation.js` | 64 | Sin capítulo directo; revisar inventario |
| `web/js/modules/payments-center.js` | 118 | finance |
| `web/js/modules/plan-services.js` | 160 | service-activate |
| `web/js/modules/platform-admin-access.js` | 68 | Sin capítulo directo; revisar inventario |
| `web/js/modules/platform-admin.js` | 468 | Sin capítulo directo; revisar inventario |
| `web/js/modules/platform-legal.js` | 33 | account-create |
| `web/js/modules/portal.js` | 197 | start, enrollments, students, notifications, member-start, member-schedule, member-finance, member-notifications, member-requests |
| `web/js/modules/private-training.js` | 14 | sessions |
| `web/js/modules/professional-documents.js` | 27 | documents, profile-documents, identity-create |
| `web/js/modules/professional-finance.js` | 51 | finance |
| `web/js/modules/professional-hub.js` | 2 | profile-public |
| `web/js/modules/professional-operations.js` | 94 | profile-events |
| `web/js/modules/profile-administration.js` | 63 | profile-public |
| `web/js/modules/profile-conversations.js` | 23 | communications |
| `web/js/modules/profile-operations.js` | 48 | profile-showcase |
| `web/js/modules/profile-team.js` | 51 | team |
| `web/js/modules/public-profile.js` | 357 | profile, member-profile, profile-public, social-media |
| `web/js/modules/pwa-install.js` | 85 | install, member-install |
| `web/js/modules/resource-center.js` | 145 | start |
| `web/js/modules/showcase-cart.js` | 72 | showcase-explore |
| `web/js/modules/showcase-compliance.js` | 50 | showcase, showcase-publish |
| `web/js/modules/showcase.js` | 671 | showcase, material, member-showcase, profile-showcase, showcase-explore, showcase-publish |
| `web/js/modules/social-network.js` | 75 | social |
| `web/js/modules/social-post-management.js` | 64 | social-publish, social-media |
| `web/js/modules/spectator-hub.js` | 2 | profile-public |
| `web/js/modules/sports-profile.js` | 102 | member-profile |
| `web/js/modules/support-privacy.js` | 75 | privacy |
| `web/js/modules/training.js` | 99 | sessions, attendance, tracking, progress |
| `web/js/modules/work-scopes.js` | 53 | scopes |
