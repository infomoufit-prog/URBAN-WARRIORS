# Plan de implementación · identidades, equipos y servicios

5 de octubre de 2026. Propuesta para autorización previa del usuario. No se ha implementado este plan. Su base es el código acumulativo FIX11 y las decisiones de esta conversación; antes de editar debe comprobarse cualquier cambio posterior en el repositorio.

## 1. Objetivo y alcance

Unificar la experiencia de todos los perfiles con el acabado y la navegación de Mi Club, sin convertir otras identidades en clubes ficticios. Diferenciar presencia pública, acreditación, administración y servicios contratados. Añadir herramientas propias de Marca, Federación y Profesional/Organizador, con equipos de administración limitados por contexto.

El piloto sigue centrado en clubes, alumnos/familias y equipos. No se alterarán silenciosamente sus altas, códigos, cupo de cuatro clubes piloto, beneficios ni autorizaciones. La webapp es la vía principal de alta y comprobación. No se autoriza con este documento un push, despliegue público, AAB, cobro real o envío real de propuestas comerciales.

## 2. Cuenta, identidad y servicio

- Una cuenta corresponde a unas credenciales y puede tener una sola identidad o gestionar varias.
- Es válido usar un correo dedicado a una marca y gestionar únicamente esa marca. No se obliga a crear primero un perfil personal público de espectador.
- Una persona puede utilizar un solo acceso para sus capacidades personales y organizaciones autorizadas. Suscripción, verificación y servicios pertenecen al sujeto correspondiente, no se conceden globalmente a todo el correo.
- Las capacidades personales de la misma persona no crean automáticamente duplicados de su perfil Social. Club, Marca y Federación mantienen perfiles públicos organizativos propios.
- Varias personas pueden gestionar una organización mediante sus propias cuentas invitadas. No comparten contraseña ni adquieren su titularidad automáticamente.
- Un vendedor autorizado es una condición comercial de una identidad; no es otro perfil público.
- Se muestra siempre el contexto activo y se cambia desde Mi Espacio, sin una segunda capa obligatoria de Mi Cuenta ni reintroducir un botón redundante de Cambiar espacio.

## 3. Navegación y experiencia

La entrada general tras acceso o alta conduce a la exploración existente, con sus cuatro áreas y Mi Espacio. Mi Espacio permite crear, seleccionar y gestionar identidades y organizaciones. Sin perfil seleccionado ofrece una invitación clara a crearlo.

Al entrar en una identidad se mantiene una estructura de navegación con acabado premium, inspirada en Mi Club: Inicio, Mi perfil público, Mi actividad, Equipo y permisos, Finanzas cuando correspondan, Plan y servicios, Recursos, Notificaciones y Cerrar sesión. Menú móvil, iconos, estados de carga y navegación hacia atrás coherentes. El perfil público permanece como centro de su presentación; las operaciones privadas se abren dentro de su espacio.

El aspecto premium es común incluso para perfiles gratuitos. Las herramientas que requieren capacidades adicionales muestran qué falta y cómo activarlas. No se muestran como operativas funciones que solo tienen una maqueta o una tarjeta informativa.

## 4. Modelos económicos

### Participación gratuita

Cuenta general, Espectador, Miembro/Familiar y capacidades personales del Competidor. Comprar, pagar entradas o cuotas del club no supone contratar una suscripción personal de KOMBAX. La pertenencia a un equipo tampoco exige que el invitado compre el plan de su organización.

### Profesional gratuito con servicios opcionales

Entrenadores, representantes, árbitros, sanitarios, psicólogos deportivos, psicoterapeutas, otros profesionales, Media/Creador y organizadores/promotores. Presentación y herramientas básicas propias; promoción, campañas avanzadas, Events, ticketing y Commerce mediante capacidades y activaciones correspondientes. No se crea una suscripción obligatoria de organizador.

### Organizaciones con suscripción

Club, Marca y Federación: perfil público separado de la gestión recurrente contratada. Marca tendrá Básico, Premium y Enterprise. Federación tendrá una distinción funcional Básico/Premium que debe reconciliarse con su catálogo actual; Partner no se convierte automáticamente en Premium. El esquema Club existente se preserva mientras no se acuerde una migración comercial explícita.

El catálogo local actual de Marca incluye Commerce desde Brand Start. La propuesta de Marca Básico es diferente; no se resolverá renombrando planes o retirando derechos a suscripciones existentes. Antes de modificar prestaciones se leerá el catálogo vigente del servidor y se documentará la transición.

## 5. Herramientas por identidad

| Identidad | Base útil | Capacidades avanzadas propuestas |
|---|---|---|
| Club | Alumnos, grupos, inscripciones, sesiones, asistencia, comunicaciones y finanzas operativas según rol y plan actual | Promoción, herramientas comerciales, informes y automatizaciones conforme al plan |
| Marca Básico | Catálogo limitado, campañas y colaboraciones básicas, propuestas y registro económico | Premium: catálogo ampliado, e-commerce, Campañas y Embajadores, atribución e informes; Enterprise: mayor escala y controles |
| Federación Básico | Federados, licencias, afiliaciones, equipo, comunicaciones y economía propia | Premium: Centro de Temporada, renovaciones, calendario, actividades, patrocinio e informes avanzados |
| Profesional | Perfil acreditado, experiencia, servicios, disponibilidad y herramientas propias de la especialidad | Captación, promoción, campañas y otros servicios opcionales |
| Organizador/promotor | Preparación de eventos, borradores, programa y colaboradores | Activación de Events, ticketing, QR, Centro de Producción y economía del evento |
| Competidor | Perfil deportivo, trayectoria, competiciones y relaciones autorizadas | Servicios opcionales pertinentes; no se asigna una contabilidad de Club |
| Media/Creador | Perfil y herramientas de contenido conforme a sus capacidades | Campañas, colaboraciones avanzadas y servicios comerciales |
| Miembro/Familiar | Vínculo con club, actividad propia y pagos personales | Sin obligación de suscripción personal; publicación condicionada al vínculo autorizado |
| Espectador | Perfil básico, exploración, guardados, compras y entradas | Servicios opcionales solo cuando tenga una capacidad compatible; no se añade publicación de feed por cambiar el diseño |

## 6. Acreditación profesional obligatoria

Actualización autorizada el 5 de octubre: la verificación general con justificación de la profesión habilita la actividad habitual. No se exige una segunda acreditación a todos los profesionales. Solo los servicios específicos que lo requieran tendrán acreditación adicional por especialidad. Preparar una ficha es distinto de publicar una oferta profesional verificada.

Ampliar el catálogo explícito, actualmente reducido a cinco familias, para incluir Psicólogo deportivo y Psicoterapeuta diferenciados y las demás especialidades que se definan. No asignarles permisos de Médico por compartir un grupo sanitario. La acreditación adicional se vincula a la especialidad y servicio concreto; no se hereda de otro perfil.

Estados: borrador, pendiente, requiere información, aprobado, rechazado y vencido/suspendido cuando proceda. Los documentos son privados; solo la información y acreditaciones autorizadas se presentan públicamente. La automatización de revisión ya autorizada para el piloto debe reservar las dudas a Owner; la legibilidad de un documento no equivale por sí sola a acreditar una actividad. Pagar no sustituye la verificación ni otorga insignias.

El perfil podrá presentar diplomas, autorizaciones, licencias y otra documentación elegida por el titular. La publicación de una copia debe ser explícita y distinguir documento aportado de acreditación validada. Las evidencias privadas de verificación no se convierten automáticamente en documentos públicos.

No se implementa historia clínica ni tratamiento de expedientes sanitarios como parte del perfil profesional.

## 7. Equipos en todos los espacios

Todos los espacios podrán presentar Equipo y permisos. Invitación y delegación efectiva requieren autoridad sobre ese contexto. En perfiles personales, especialmente familiares o menores, las delegaciones se restringen a lo autorizado; no se heredan todas las reglas de un equipo de Club.

- Titular/administrador: invita, revisa y revoca accesos conforme a su autoridad.
- Gestor delegado: opera las funciones expresamente asignadas.
- Comunicación/contenido: publica y gestiona contenido autorizado.
- Finanzas: accede solo a operaciones económicas del contexto concedido.
- Roles específicos: licencias en Federación, catálogo/campañas en Marca, producción/QR en Events.

Las invitaciones se vinculan a correo, contexto, permisos y vencimiento. Una cuenta nueva confirma su correo antes de activar el acceso; una existente acepta con el correo autorizado. Estados y revocación visibles, historial de cambios y notificaciones. No conceder dirección por autoasignación ni al introducir un código general.

La autoría pública y el gestor que realiza una operación se registran por separado: un colaborador puede publicar por una marca sin apropiarse de su identidad o recibir acreditaciones profesionales del titular.

## 8. Finanzas por contexto

Un núcleo compartido distingue presupuesto, cargos, cobros, devoluciones, gastos, comisiones y liquidaciones, con filtros e informes. El dinero de una marca, federación, club, profesional o evento no se mezcla por compartir administrador.

Marca: Showcase y campañas/colaboraciones. Federación: licencias, afiliaciones, servicios y actividades. Profesional: su actividad. Organizador: presupuesto y ejecución del evento. Reutilizar operaciones existentes y añadir lo que falte; no copiar el módulo de Club cambiando solo el título.

Mantener acceso autorizado a historial, justificantes, devoluciones y operaciones pendientes cuando venza un servicio. Recibos e informes administrativos no se presentan como facturación fiscal. Informes con imagen de la entidad y elección de logo en tickets conforme a lo acordado.

## 9. Prueba de 30 días y servicios

Prueba explícita, separada de crear el perfil, con verificación y método de pago cuando corresponda. El checkout muestra plan, prestaciones, precio posterior, fecha y renovación. Los beneficios piloto existentes conservan su circuito excepcional.

Antes de programar contratación se concretarán elegibilidad por plan, límites, condiciones de repetición de prueba y precios. Durante el desarrollo se mantiene bloqueada la contratación pública piloto y se usa Stripe de prueba. No se activa Enterprise ilimitado por inferencia ni se inventan importes o cupos.

Vender requiere autorización de vendedor, e-commerce activo y configuración de cobros. Activar Events no activa ticketing; ampliar catálogo no activa Commerce; contratar un servicio no concede permisos de otra identidad.

## 10. Fases y aceptación

1. **Auditoría base:** comprobar versión y cambios posteriores a FIX11; mapear catálogo, operaciones, capacidades y funciones solo informativas. Registrar el recorrido de Club como referencia de regresión.
2. **Contrato y transición:** definir cuenta/identidad/organización/servicio/equipo, reconciliar catálogos actuales y acordar los límites comerciales que falten antes de activarlos.
3. **Navegación común:** implantar shell y menú contextual; comprobar desktop/móvil, selección, exploración, vuelta atrás y cierre de sesión.
4. **Profesionales y equipos:** especialidades, acreditación, oferta de servicios, invitaciones y delegaciones por contexto. Probar rechazo y revocación, además del recorrido correcto.
5. **Marca:** finanzas, catálogo y campaña desde propuesta hasta resultado; distinguir preparación, publicación, promoción y venta.
6. **Federación:** licencias, relaciones, temporada y finanzas, con límites frente a datos privados de clubes.
7. **Organizador:** producción, publicación, ticketing, QR, devoluciones y resultado económico del evento.
8. **Activaciones:** pruebas de estados en Stripe de prueba, webhook repetido, vencimiento, renovación y pago fallido donde el catálogo esté definido. Comprobar que frontend no puede elevar capacidades.
9. **QA acumulativa:** altas web y confirmación, Club Piloto, alumnos, familias, equipos, sesiones, permisos, publicaciones, Showcase, moderación Owner, recibos e informes. Pruebas de aislamiento entre dos organizaciones y entre titular e invitado; conservar datos existentes.
10. **Entrega:** informe de acciones y pruebas reales, asuntos pendientes y paquete acumulativo en cuatro partes con reunificador verificado. No declarar compilación nativa, entrega de correo real o despliegue público sin haberlos realizado.

La autorización solicitada es para implementar este alcance de código y pruebas. Los límites comerciales pendientes se resolverán antes de su implementación dependiente; no impiden avanzar en navegación, acreditación, permisos e inventario. Publicación, cobros y cambios irreversibles requieren la autorización correspondiente y una entrega concreta revisable.
