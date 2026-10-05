# Perfiles, espacios y servicios · propuesta funcional

5 de octubre de 2026. Análisis del código acumulativo FIX11 y de las decisiones de esta conversación. Documento de propuesta; no constituye una implementación, cambio de precios ni activación de servicios.

## Prioridad del piloto

El recorrido estable de cuenta, club piloto, equipo, alumno y familia es la prioridad. El desarrollo de otras identidades no debe cambiar los códigos de acceso, el límite de cuatro clubes piloto, sus beneficios o los permisos de gestión. Todas las altas se realizarán desde la webapp.

Una cuenta puede gestionar capacidades personales y organizaciones distintas. La navegación compartida no crea cuentas duplicadas, no concede permisos de club y no mezcla los datos de varias organizaciones.

## Situación comprobada en el código

Mi Club tiene una estructura de navegación con sidebar y rutas dependientes del rol. Los perfiles directos usan un hub distinto. Existe una base de operaciones de Marca, Federación, Profesional, Showcase y Events, pero algunos accesos del hub son informativos o dependen de capacidades; no deben presentarse como servicios terminados únicamente porque aparezcan en un menú.

El catálogo local contempla Club/Premium/Enterprise; Brand Start/Growth/Enterprise; Federation/Federation Partner. Brand Start incluye Commerce en ese catálogo: no coincide con el nuevo Marca Básico centrado en catálogo y escaparate. Federation Partner no debe renombrarse como Premium sin definir antes sus prestaciones. Los datos comerciales del servidor prevalecen sobre este catálogo de respaldo; no se fijan aquí precios ni nuevos límites numéricos.

La contratación pública está bloqueada en la configuración del piloto. Esta propuesta no autoriza abrirla ni activar cobros reales.

## Estructura compartida de experiencia

Todos los perfiles tendrán el mismo acabado visual y navegación móvil: Inicio, Mi perfil público, Mi actividad, Finanzas cuando proceda, Plan y servicios, Recursos, Notificaciones y Cerrar sesión. La cabecera mostrará de forma persistente con qué persona u organización se trabaja.

Crear la identidad habilita su espacio y sus funciones gratuitas. El acceso efectivo a una herramienta se calcula por identidad, autorización, verificación, plan o activación, vigencia y límites. Mostrar un bloqueo en frontend no sustituye la comprobación de servidor.

## Club

**Básico propuesto:** gestión de alumnos, inscripciones, disciplinas, grados, grupos, sesiones, asistencia, comunicación interna, equipo y finanzas operativas. El objetivo es administrar el club sin obstáculos artificiales.

**Premium propuesto:** ampliar promoción, Showcase, Commerce, organización de Events, informes y automatizaciones conforme a las prestaciones definitivas del catálogo. Los límites existentes deben preservarse hasta migrar explícitamente al modelo acordado.

**Enterprise:** escala, permisos y volumen avanzados. No afirmar multi-sede o consolidación financiera como funciones terminadas sin comprobar e implementar sus operaciones.

Alumno/familia consultan su actividad y pagos; monitor trabaja sobre sus ámbitos; tesorería gestiona operaciones autorizadas; dirección administra la entidad. Una suscripción del club no concede esas responsabilidades automáticamente.

## Marca

**Perfil gratuito:** identidad pública y navegación. Publicación limitada según verificación y política Social. Presentación pública no equivale a Commerce. La cantidad de contenido o productos gratuitos debe decidirse expresamente: no se traslada automáticamente la capacidad del catálogo de respaldo.

**Marca Básico:** escaparate/catalogación limitada, campañas y colaboraciones con alcance básico, seguimiento de propuestas y registro económico de su actividad. Crear productos, exponerlos y venderlos son capacidades distintas; las nuevas altas de catálogo se habilitan conforme al plan acordado.

**Marca Premium:** catálogo ampliado y e-commerce, Centro de Campañas y Embajadores, coordinación de entregables, resultados medibles, ventas atribuidas y finanzas avanzadas. Autorización de vendedor y cobros configurados siguen siendo requisitos independientes. No existe vendedor gratuito.

**Marca Enterprise:** mayor capacidad, equipo y permisos avanzados; consolidación y automatizaciones donde exista una necesidad real. Prestaciones y límites pendientes de fijar.

**Diferencial Premium:** conectar una campaña con colaboradores del sector y con resultados medibles. Las propuestas requieren destinatario, condiciones y aceptación; no constituyen automáticamente un contrato pagado. La IA prepara y recomienda; el usuario autoriza los envíos. La atribución debe explicar sus límites y diferenciar ventas reales de clics.

**Finanzas:** ventas, cobros, devoluciones, comisiones y liquidaciones cuando tenga Commerce; ingresos y gastos de campañas, colaboraciones y patrocinios según registros válidos. No mezclar dinero cobrado con presupuesto o ingresos previstos.

## Federación

**Perfil gratuito:** presencia institucional, presentación, documentos públicos autorizados y navegación. No otorga acceso a los expedientes privados de los clubes.

**Federación Básico propuesto:** administración de federados y licencias, afiliaciones, calendario propio, comunicaciones, equipo autorizado y gestión financiera operativa de cargos y pagos propios.

**Federación Premium propuesto:** Centro de Temporada Federativa, seguimiento avanzado de renovaciones y vencimientos, planificación de competiciones y formación, campañas institucionales, patrocinadores, informes y automatizaciones. El calendario se conecta con Events; ticketing es una capacidad separada.

**Enterprise:** no se introduce por analogía con Marca. Evaluarlo después si aparecen necesidades de volumen, territorios, delegaciones o integración.

**Finanzas:** licencias, afiliaciones, servicios federativos, actividades y patrocinio. Las finanzas de los clubes afiliados permanecen privadas; cualquier intercambio requiere autorización concreta y alcance definido.

## Profesional · organizador/promotor

Organizador/promotor es una especialidad o capacidad del Profesional, no una segunda cuenta personal. Una promotora con identidad de entidad puede requerir un contexto organizativo distinto, con sus propios gestores y operaciones; su clasificación queda pendiente antes de implementar.

**Base:** perfil verificado según capacidades, preparación de eventos y borradores, agenda, propuestas de colaboración y registros de su actividad profesional.

**Servicios puntuales:** publicación de un evento, ticketing según aforo y Commerce cuando exista actividad de vendedor autorizada. Contratar uno no activa los demás. No imponer suscripción de club ni crear una suscripción de organizador por esta propuesta.

**Herramientas avanzadas:** Centro de Producción del Evento, tareas y responsables, programación, participantes, colaboradores, patrocinios, comunicaciones, entradas, QR, informes y seguimiento económico. Distribuirlas entre capacidades base, activación de evento y complementos avanzados antes de comercializarlas.

**Finanzas:** presupuesto frente a ejecución, entradas, inscripciones, servicios, patrocinio, devoluciones, costes y liquidaciones. Los fondos de terceros requieren reglas explícitas; no asumir distribución automática de dinero.

## Otras identidades

### Modelo económico aclarado

Se distinguen tres grupos, sin convertir el uso profesional en una obligación de suscripción:

1. Participación gratuita: cuenta general, Espectador, Miembro/Familiar y funciones personales del Competidor. Compras, entradas o cuotas del club son pagos por bienes y servicios, no una suscripción personal a KOMBAX. Las capacidades verificadas siguen requiriendo su acreditación.
2. Identidad profesional gratuita con servicios opcionales: entrenadores, representantes, árbitros, psicología deportiva, psicoterapia, otros profesionales sanitarios, Media/Creador y organizadores/promotores. Perfil público y herramientas básicas correspondientes; promoción, campañas avanzadas, Events, ticketing y Commerce se contratan según el servicio utilizado. No se impone una suscripción por querer captar clientes.
3. Organizaciones con gestión SaaS recurrente: Club, Marca y Federación. Perfil público gratuito separado de la gestión incluida en suscripción, prueba o activación compatible. Diferenciación Básico/Premium/Enterprise solo donde esté definida.

Vendedor autorizado es una condición comercial vinculada a una identidad existente, no un nuevo tipo de perfil público. Para vender necesita verificación, servicio activo y configuración de cobros; ni la autorización ni el perfil gratuito habilitan ventas por sí solos.

El catálogo local de especialidades explícitas contiene Entrenador, Representante/Manager, Médico/Sanitario, Árbitro/Juez y Promotor/Organizador. Discovery incluye indicios de otras especialidades, como psicología deportiva, fisioterapia y nutrición, pero eso no prueba que tengan un alta estructurada completa. Psicólogo deportivo y Psicoterapeuta deben incorporarse como especialidades diferenciadas, con información y verificaciones propias, sin asignarles automáticamente permisos de Médico. No se plantea aquí un sistema de historia clínica.

Una herramienta profesional básica debe aportar utilidad sin pago: presentación, servicios, disponibilidad y contactos/propuestas autorizados. Su alcance concreto se comprobará y definirá por especialidad. La monetización se concentra en promoción, ejecución de campañas y servicios operativos avanzados, sin cobrar por comprar ni por acceder a derechos ya adquiridos.

- Profesional de otras especialidades: clientes, agenda, servicios, credenciales, cargos, pagos registrados y gastos; servicios de Events o vendedor solo si están habilitados.
- Competidor: trayectoria, competición, oportunidades, licencias y representación autorizada. Finanzas limitadas a operaciones y actividad propia; no habilitar una contabilidad de club.
- Media/Creador: contenido, colaboraciones y seguimiento de su trabajo. Venta requiere servicio activo y vendedor autorizado.
- Miembro/Familiar: perfil, vínculo confirmado, sesiones, comunicación y sus pagos. Publicación como miembro solo con la vinculación exigida.
- Espectador: presencia básica, exploración, guardados, compras y entradas. No añadir álbum o publicación de feed por el mero hecho de compartir el nuevo diseño.

## Pruebas, suscripciones y conservación de operaciones

Los 30 días de prueba se activan expresamente; crear el perfil no inicia el contador. Aplican requisitos de verificación y método de pago acordados, con información clara de las condiciones posteriores. No están definidos aún todos los planes elegibles ni si habrá una sola prueba por organización; deben resolverse antes del checkout.

Al terminar un servicio se limitan nuevas operaciones conforme al contrato. Historial, justificantes, devoluciones y obligaciones pendientes permanecen accesibles para usuarios autorizados. Mantener esa gestión no convierte a la entidad en vendedor gratuito.

## Secuencia de desarrollo y aceptación

1. Inventario y contrato de capacidades: mapear funciones existentes, informativas y ausentes; acordar prestaciones y límites sin cambiar silenciosamente planes activos.
2. Navegación común: adaptar contexto personal/organizativo sin convertirlo en un club ficticio.
3. Marca: Básico/Premium/Enterprise, finanzas y campaña completa de prueba.
4. Federación: operaciones de temporada y finanzas propias, con aislamiento respecto de clubes.
5. Organizador: recorrido desde borrador hasta cierre del evento y resultado económico.
6. Suscripciones y servicios: ensayos en Stripe de prueba, preservando el bloqueo comercial piloto.
7. QA: regresión de altas web, invitaciones, aprobaciones, familias, sesiones y finanzas del club; pruebas de acceso cruzado, vencimientos, pagos fallidos y operaciones pendientes.
8. Entrega acumulativa: informe que distinga pruebas locales, de servidor y recorridos reales. Sin publicación automática.

Las cifras de catálogo, campañas, equipo, eventos y los precios no se inventan en este documento. Requieren un contrato funcional aprobado antes de convertirse en reglas del servidor y de la interfaz.
