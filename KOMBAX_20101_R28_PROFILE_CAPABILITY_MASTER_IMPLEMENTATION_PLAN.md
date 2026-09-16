# KOMBAX 20.101 · Plan Maestro R28 · Transcripción Markdown para packaging

> Esta transcripción Markdown se ha generado desde el PDF maestro adjunto exclusivamente para conservar una fuente de texto dentro del ZIP. El PDF original incluido en este paquete es la fuente normativa.

                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES




    KOMBAX 20.101 - PLAN MAESTRO DE
IMPLEMENTACION DE PERFILES, CAPACIDADES Y
              ENTORNOS
               Documento de planificación previa - NO autoriza implementación
            Base funcional y de código: KOMBAX 20.101 R27 · Support Email Frontend
 SHA-256 de la base R27: b1093f46d4dae4dbcba0da9c9a3b5d5596d42b255e9d531638fc3774c82146c2
                               Fecha de planificación: 30/08/2026
                Estado: PLAN PREVIO / PENDIENTE DE AUTORIZACIÓN DEL OWNER



                                       0. Propósito y regla de autorización

 Este documento define, antes de modificar código o backend, la arquitectura funcional y técnica para
que KOMBAX deje cerrado su modelo general de perfiles. La ejecución se realizará únicamente después
                                      de autorización expresa.

                            El plan incorpora los perfiles y entornos siguientes:

                                 •    Cuenta KOMBAX / identidad de cuenta.
  •    Perfil Miembro / Alumno.
  •    Perfil Competidor.
  •    Perfil Club y entorno Mi Club.
  •    Perfil Federación y futuro entorno Mi Federación.
  •    Perfil Marca y futuro entorno Mi Marca.
  •    Perfil Profesional, con especializaciones internas.
  •    Perfil Espectador.

Decisión expresa: el Competidor, incluso si compite profesionalmente, NO forma parte del Perfil
Profesional. El Competidor mantiene su propia identidad deportiva y su propia evolución futura de
plan/capacidades.

El Perfil Profesional agrupará a profesionales que prestan servicios o ejercen funciones dentro del
ecosistema: entrenador autónomo, representante/manager, médico o sanitario deportivo, árbitro/juez,
promotor/organizador y otras especialidades futuras compatibles.

Este plan no pretende rehacer KOMBAX. Debe reutilizar la arquitectura existente de identidad,
perfiles_kombax_directos, perfiles sociales, gestores, entitlements, RLS, moderación, soporte
autorizado, Events, Showcase y Finanzas.




1. Principios no negociables
  1.   NO ROMPER NADA QUE YA FUNCIONE. Mi Club, Social, Showcase, Events, Auth, Finanzas
       Club, soporte, moderación y Android deben conservar sus flujos actuales salvo cambios
       explícitamente descritos.

                      Página 1 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  2.    Una cuenta puede tener varias identidades. No se crearán cuentas separadas para cada
        actividad del mismo usuario.
  3.    Tipo de perfil, permisos y plan son conceptos distintos. “Qué soy” no debe confundirse con
        “qué puedo hacer” ni con “qué pago”.
  4.    Capacidades antes que condicionales dispersos. Se evitarán cadenas de if perfil === ...
        distribuidas por la aplicación.
  5.    Privacidad por defecto. Una Federación no obtiene acceso a datos privados de un club por
        estar afiliado. Un representante no obtiene acceso a datos de un competidor sin relación
        aceptada. Un médico no obtiene acceso sanitario por el mero hecho de ser médico.
  6.    Aislamiento multiclub intacto. La evolución de perfiles no puede debilitar RLS ni el contexto
        club_id existente.
  7.    Sin perfiles falsos para reutilizar módulos. Un entrenador autónomo no se convertirá
        internamente en “club de una persona” solo para usar Finanzas.
  8.    Reutilizar motores y componentes cuando el dominio coincida. UI, matemáticas, informes,
        media, soporte, notificaciones y auditoría se reutilizan; almacenamiento y permisos solo se
        comparten cuando las semánticas son realmente equivalentes.
  9.    Competidor Profesional excluido de Profesional. Cualquier capacidad premium futura del
        competidor se añade al Perfil Competidor.
  10.   Funciones Pro separadas del núcleo. Primero se cierra el perfil básico y sus funciones
        esenciales. Las ventajas Pro se superponen después mediante entitlements/planes.
  11.   Toda nueva función se clasifica previamente como GLOBAL, DE TIPO DE PERFIL, DE
        SUBTIPO PROFESIONAL o DE PLAN.
  12.   No se hará deploy de Netlify ni push a GitHub sin autorización expresa.
  13.   No se incrementará versionCode de Android durante la fase de arquitectura salvo
        decisión específica de publicación.
  14.   No se declarará PASS, aplicado, firmado o desplegado sin evidencia física.




2. Auditoría del estado R27 que condiciona el diseño

2.1 Lo que ya existe y debe reutilizarse
R27 ya contiene una arquitectura de identidad suficientemente buena para evolucionar sin sustituirla:

  •     perfiles_kombax_directos admite actualmente a nivel de esquema: competidor, marca,
        federacion, espectador y profesional.
  •     El frontend muestra Club, Competidor, Marca y Federación como tipos habilitados; Profesional
        y Espectador están deliberadamente deshabilitados.
  •     La mutación principal de perfiles verificados actualmente abre solo Competidor, Marca y
        Federación, por lo que Profesional y Espectador necesitan activación controlada en
        gateway/RPC, no una tabla nueva de identidad.
  •     Existe kombax_perfil_gestores con roles owner, admin, editor, comunicacion para perfiles
        directos.
  •     Existe kombax_entitlements y un catálogo kombax_capacidades.
  •     Existen capacidades actuales para Competidor, Marca, Federación, Social, Showcase y Events.




                      Página 2 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •    Existen planes actuales de perfil directo: competidor_premium, federacion_institucional y
       marca_profesional.
  •    Miembro es una identidad distinta: nace de membresía de club y su perfil Social, no de
       perfiles_kombax_directos.
  •    Club es también un dominio distinto: la gestión privada depende de clubes, membresías, roles,
       RLS y el entorno Mi Club. No debe migrarse artificialmente a perfil directo.
  •    R26/R27 ya generalizan Privacidad y soporte para cuenta, club y perfil directo.

2.2 Estado real del backend observado durante la planificación
En el backend principal el constraint de perfiles_kombax_directos.tipo ya incluye Profesional y
Espectador. Actualmente existen perfiles directos de los tipos Competidor y Federación; no hay todavía
perfiles Profesional ni Espectador activos en datos reales.

Esto permite una estrategia aditiva: abrir tipos ya contemplados, añadir especialización/capacidades y
construir entornos, en lugar de reemplazar la identidad central.

2.3 Deuda actual que no debe confundirse con esta fase
  •    Advisors de seguridad y rendimiento mantienen advertencias históricas.
  •    Existen índices sin uso y FK sin índice que deben tratarse por evidencia de consulta, no
       indiscriminadamente.
  •    La navegación de Events continúa en estabilización visual/fluidez, pero no forma parte del
       rediseño de perfiles salvo su integración por capacidades.
  •    El agente IA de soporte por correo todavía no está conectado; la infraestructura de autorización
       temporal sí existe.




3. Modelo objetivo: cuenta, identidad, capacidad y plan

3.1 Jerarquía conceptual
CUENTA KOMBAX
│
├── identidad personal / seguridad / legal / soporte
│
├── Perfil Miembro (derivado de una membresía de club)
│
├── Perfil Competidor
│
├── Perfil Profesional
│ ├── Entrenador autónomo
│ ├── Representante / Manager
│ ├── Médico / Sanitario deportivo
│ ├── Árbitro / Juez
│ ├── Promotor / Organizador
│ └── Otra especialidad aprobada
│


                      Página 3 · Documento de planificación previa · Pendiente de autorización
                                                          KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


├── Perfil Federación
│
├── Perfil Marca
│
├── Perfil Espectador
│
└── acceso a uno o varios Clubes mediante membresías
   └── entorno Mi Club según rol

3.2 Cuatro dimensiones separadas
A. Tipo de identidad

Responde a qué representa el perfil: Competidor, Federación, Marca, Profesional, Espectador,
Miembro o Club.

B. Subtipo profesional

Solo aplica a Perfil Profesional. Responde a qué actividad profesional ejerce.

C. Capacidades

Responde a qué operaciones puede realizar realmente. Ejemplos: events.public.organize,
finance.manage, represented.manage.

D. Plan / entitlement

Responde a por qué tiene una capacidad y durante cuánto tiempo: base, suscripción, promoción,
piloto, autorización manual, partner, etc.

Un entrenador que deje de pagar un futuro plan Pro seguirá siendo Entrenador; simplemente perderá
las capacidades Pro.




4. Capa GLOBAL aplicable a todos los perfiles
Las siguientes funciones deben ser transversales y deben formar parte de la matriz de QA de todos los
perfiles compatibles:

  •    Autenticación y sesión.
  •    Seguridad de cuenta.
  •    Recuperación/cambio de contraseña.
  •    Privacidad.
  •    Soporte y correo soporte@kombax.es.
  •    Autorizaciones temporales de soporte, cuando el perfil sea gestionable.
  •    Auditoría de acciones sensibles.
  •    Notificaciones globales.
  •    Aceptaciones legales de plataforma.
  •    Moderación de contenido público aplicable.
  •    Reporte/bloqueo cuando el módulo lo permita.

                        Página 4 · Documento de planificación previa · Pendiente de autorización
                                                          KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •    Gestión de avatar/banner/media según permisos.
  •    Eliminación/cierre del perfil conforme a su dominio.
  •    Cambio de identidad activa en los módulos compartidos.

Estas funciones no deberán reimplementarse por cada tipo; se reutiliza la infraestructura común y se
parametriza el subject.




5. Perfil Club y entorno Mi Club

5.1 Naturaleza
Club sigue siendo un tenant privado de gestión, no un simple perfil Social. El perfil público del club y
la gestión privada están relacionados, pero no son el mismo dominio.

5.2 Creación
  1.   Solicitud “Soy un club”.
  2.   Datos de identidad/representación.
  3.   Evidencias privadas de existencia y legitimidad.
  4.   Revisión KOMBAX.
  5.   Alta/activación del club.
  6.   Creación o asociación del gestor inicial.
  7.   Asignación de plan/piloto.
  8.   Habilitación de identidad pública y capacidades autorizadas.

5.3 Roles privados del club
Se mantiene el modelo actual de Dirección/Gestor, Coordinación, Secretaría, Economía/Tesorería,
Comunicación, Monitor, Familia y Alumno, con scopes internos cuando proceda.

5.4 Capacidades núcleo
  •    Gestión de alumnos/socios.
  •    Equipo y permisos internos.
  •    Grupos, disciplinas y sesiones.
  •    Asistencia y seguimiento.
  •    Finanzas Club.
  •    Documentos.
  •    Material.
  •    Comunicaciones.
  •    Comunidad interna.
  •    Eventos internos.
  •    Events públicos si el plan/capacidad lo permite.
  •    Social y Showcase según identidad/plan.
  •    Privacidad y soporte.

5.5 Fronteras
  •    Un club nunca obtiene datos privados de otro club.

                        Página 5 · Documento de planificación previa · Pendiente de autorización
                                                           KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •    Una federación afiliada no hereda acceso al área privada.
  •    El contenido público del club sí puede aparecer en Social, Showcase y Events.

5.6 Navegación
Se conserva Mi Club como entorno principal para quien está operando dentro de un club. No se
sustituirá por un hub genérico que empeore la experiencia ya validada.




6. Perfil Miembro / Alumno

6.1 Naturaleza
Miembro no es un perfil directo genérico. Se deriva de una relación real con un club y conserva
separación entre:

  •    Datos administrativos privados del club.
  •    Identidad pública opcional de KOMBAX Social.

6.2 Creación
  •    16+ puede crear su cuenta y solicitar/realizar alta según el flujo permitido.
  •    Menores de 16 entran mediante club/tutor según las reglas vigentes.
  •    La activación pública en Social se rige por edad y verificación del club.
  •    El perfil de Miembro no debe existir públicamente solo porque exista una ficha administrativa
       de alumno.

6.3 Funciones privadas
Según relación y edad:

  •    Ver datos propios permitidos.
  •    Sesiones/horarios.
  •    Asistencia propia cuando aplique.
  •    Cuotas/deudas/pagos propios y recibos según plan del club.
  •    Documentos propios autorizados.
  •    Notificaciones.
  •    Comunidad del club.

6.4 Funciones públicas
Cuando Social esté habilitado:

  •    Perfil Miembro.
  •    Publicaciones conforme a reglas.
  •    Mi red privada.
  •    Guardados/interacciones.
  •    Afiliación al club cuando corresponda.

6.5 Restricciones
  •    No gestiona datos globales del club por ser miembro.

                         Página 6 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •    No obtiene finanzas administrativas.
  •    Menores quedan sujetos a controles específicos de contacto, consentimiento y publicación.




7. Perfil Competidor

7.1 Decisión estructural
Competidor es una identidad deportiva propia. No se moverá a Profesional aunque la persona viva
profesionalmente de competir.

7.2 Creación
Dos caminos:

Competidor independiente

Crea su Perfil Competidor desde Mis perfiles.

Evolución desde Miembro

Puede seleccionar su identidad Miembro existente para conservar continuidad de Social, publicaciones
y Mi red, evitando duplicar una persona pública.

7.3 Verificación
  •    Puede existir en borrador/pendiente.
  •    La insignia y capacidades sensibles dependen de verificación.
  •    La verificación no debe convertir automáticamente al usuario en administrador de clubes ni
       federaciones.

7.4 Capacidades base previstas
  •    Gestión de perfil deportivo.
  •    Trayectoria declarada.
  •    Participación en Events.
  •    Fight Cards públicas.
  •    Social.
  •    Guardados/interés en Events.
  •    Contacto profesional sujeto a reglas.
  •    Showcase como consumidor.

7.5 Funciones futuras de Competidor Pro
Quedan fuera de este plan de activación básica: media kit avanzado, sponsors, analítica ampliada,
oportunidades premium, dossier profesional, herramientas económicas específicas u otras ventajas
comerciales. Se añadirán al Perfil Competidor mediante plan/entitlements.




                      Página 7 · Documento de planificación previa · Pendiente de autorización
                                                           KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES



8. Perfil Federación y entorno Mi Federación

8.1 Naturaleza
Federación debe convertirse en un entorno administrativo propio, no en un “Mi Club” renombrado.

8.2 Creación
  1.   Crear identidad Federación.
  2.   Introducir datos institucionales.
  3.   Aportar evidencia privada.
  4.   Solicitar verificación.
  5.   Revisión KOMBAX.
  6.   Activación de gestores.
  7.   Asignación de plan institucional.
  8.   Habilitación de capacidades.

8.3 Gestores
Se reutiliza kombax_perfil_gestores para owner/admin/editor/comunicación. En una fase posterior
podrán añadirse roles federativos específicos si las capacidades genéricas no bastan.

8.4 Entorno Mi Federación - módulos núcleo
  •    Resumen institucional.
  •    Perfil público.
  •    Clubes afiliados/relacionados.
  •    Calendario federativo.
  •    Events públicos.
  •    Gestión de organizadores/avales/colaboradores.
  •    Fight Cards/resultados oficiales cuando se habiliten.
  •    Documentos/reglamentos públicos.
  •    Comunicaciones institucionales.
  •    Social.
  •    Privacidad y soporte.
  •    Gestores/permisos de la Federación.

8.5 Regla crítica de afiliación
La relación Federación → Club no concede acceso a:

  •    alumnos;
  •    finanzas privadas;
  •    documentos privados;
  •    comunidad interna;
  •    teléfonos/correos internos;
  •    asistencia;
  •    datos de menores.




                         Página 8 · Documento de planificación previa · Pendiente de autorización
                                                         KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


Las federaciones solo reciben datos públicos, datos federativos propios o información que el club
comparta mediante un flujo explícito futuro.

8.6 Capacidades ya existentes que se reutilizarán
El catálogo actual ya contiene conceptos como:

  •    federation.clubs.directory
  •    federation.calendar.publish
  •    federation.documents.publish
  •    federation.results.official
  •    events.public.organize
  •    events.public.partners.manage
  •    events.public.fights.manage

El plan debe conectar UI y permisos con estas capacidades en lugar de crear otras equivalentes sin
necesidad.




9. Perfil Marca y entorno Mi Marca

9.1 Naturaleza
Entidad corporativa/comercial dentro de KOMBAX, separada de Club y Profesional.

9.2 Creación
  •    Identidad de Marca.
  •    Datos corporativos y contacto.
  •    Evidencia de representación.
  •    Verificación.
  •    Gestores.
  •    Activación de plan/capacidades.

9.3 Núcleo
  •    Perfil corporativo.
  •    Showcase.
  •    Social.
  •    Productos/servicios informativos.
  •    Contactos vinculados a productos.
  •    Privacidad y soporte.
  •    Gestión de equipo/gestores del perfil.

9.4 Futuro Pro
Analítica, campañas, oportunidades, mayor capacidad Showcase, herramientas comerciales y
patrocinios se mantienen como capa de plan, no como cambio de identidad.




                       Página 9 · Documento de planificación previa · Pendiente de autorización
                                                          KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES



10. Perfil Profesional: arquitectura general

10.1 Qué es
Perfil Profesional representa a una persona que presta servicios, ejerce una función técnica o
profesional, o actúa como intermediario dentro del ecosistema de deportes de contacto.

No representa a un Competidor por competir profesionalmente.

10.2 Subtipos iniciales
  1.   Entrenador autónomo
  2.   Representante / Manager
  3.   Médico / Sanitario deportivo
  4.   Árbitro / Juez
  5.   Promotor / Organizador
  6.   Otra especialidad controlada por catálogo, no texto libre ilimitado

10.3 Subtipo principal y secundarios
Se recomienda permitir:

  •    un subtipo principal obligatorio;
  •    especialidades secundarias opcionales verificables;
  •    capacidades derivadas del subtipo y de su verificación.

Ejemplo: una persona puede ser Entrenador como actividad principal y Árbitro como secundaria, pero
cada capacidad sensible depende de su estado y autorización.

10.4 Requisito de edad
Activación autónoma de Profesional: 18+. Motivo: representación, servicios, finanzas administrativas,
verificación profesional y potencial gestión contractual. No se deben mezclar estas funciones con el
régimen de Miembro menor.

10.5 Verificación
El perfil puede prepararse como borrador, pero las capacidades sensibles requieren verificación. La
verificación deberá poder ser:

  •    identidad profesional general;
  •    especialidad concreta;
  •    acreditación/credencial concreta cuando aplique.

No todas las especialidades requieren la misma evidencia.




11. Profesional - Entrenador autónomo

11.1 Entorno
Mi actividad o Mi actividad profesional.

                        Página 10 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES



11.2 Núcleo funcional
  •    Perfil público profesional.
  •    Especialidades/disciplinas.
  •    Clientes/deportistas propios.
  •    Agenda/sesiones profesionales.
  •    Tarifas/servicios.
  •    Seguimiento operativo no clínico.
  •    Social.
  •    Showcase de servicios cuando corresponda.
  •    Events: participación/organización de seminarios según capacidad.
  •    Finanzas profesionales básicas.
  •    Privacidad y soporte.

11.3 Límite respecto a un Club
Un entrenador autónomo no tiene automáticamente:

  •    Comunidad de Club.
  •    equipo de club;
  •    alumnos de un club;
  •    finanzas de un club;
  •    documentos de club.

Si también es monitor/gestor de un Club, accede a esas funciones desde su membresía de Club, no
desde su Perfil Profesional.




12. Profesional - Representante / Manager

12.1 Núcleo
  •    Perfil profesional.
  •    Representados.
  •    Solicitudes de representación.
  •    Calendario/oportunidades.
  •    Notas administrativas.
  •    Comisiones/honorarios en Finanzas Profesionales.
  •    Events y contactos profesionales.
  •    Social.
  •    Privacidad y soporte.

12.2 Relación con competidores
Debe ser una relación explícita y auditable:

Manager solicita representar → Competidor acepta → se crea delegación → se asignan
permisos concretos

El representante no puede autoproclamarse representante de un competidor.

                      Página 11 · Documento de planificación previa · Pendiente de autorización
                                                         KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES



12.3 Permisos delegables propuestos
Separar como mínimo:

  •    ver calendario público/compartido;
  •    gestionar oportunidades;
  •    gestionar determinadas solicitudes de Events;
  •    editar ciertos campos profesionales autorizados;
  •    gestionar documentos de representación específicos;
  •    nunca recibir credenciales de cuenta del competidor.

La edición de identidad, eliminación, seguridad, datos sensibles o cambios de verificación no se
delegan por defecto.




13. Profesional - Médico / Sanitario deportivo

13.1 Núcleo
  •    Perfil profesional.
  •    Especialidad.
  •    Acreditaciones/verificación.
  •    Disponibilidad.
  •    Servicios.
  •    Asignaciones a Events cuando proceda.
  •    Finanzas profesionales básicas.
  •    Social/Showcase de servicios dentro de las políticas aplicables.
  •    Privacidad y soporte.

13.2 Exclusión crítica
No se implementa en esta fase un expediente sanitario. Ser médico no concede acceso a:

  •    información médica de alumnos;
  •    lesiones;
  •    consentimientos sanitarios;
  •    documentos privados de menores;
  •    datos de salud.

Cualquier módulo de salud futuro requerirá diseño específico de categoría especial de datos, base
jurídica, consentimiento/roles, cifrado, auditoría y minimización.




14. Profesional - Árbitro / Juez

14.1 Núcleo
  •    Perfil profesional.


                       Página 12 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •    Disciplinas.
  •    acreditaciones;
  •    disponibilidad;
  •    asignaciones a Events;
  •    historial de actuaciones;
  •    notificaciones;
  •    Finanzas profesionales básicas para honorarios/gastos;
  •    Social;
  •    Privacidad y soporte.

14.2 Permisos de Events
Un árbitro no obtiene derecho a modificar un evento completo. Solo puede recibir capacidades
delegadas para el evento concreto: acta, resultado, estado de combate u otras funciones definidas.




15. Profesional - Promotor / Organizador

15.1 Núcleo
  •    Perfil profesional.
  •    Events públicos.
  •    organizadores/partners;
  •    Fight Cards cuando corresponda;
  •    contactos;
  •    servicios;
  •    Finanzas profesionales básicas;
  •    Social/Showcase;
  •    Privacidad y soporte.

15.2 Límite económico
KOMBAX no procesa dinero ni ticketing en esta fase. Las finanzas registran actividad administrativa;
no se debe presentar como pasarela de cobro ni liquidación bancaria.




16. Perfil Espectador

16.1 Objetivo
Identidad ligera para una persona que quiere consumir KOMBAX sin gestionar un club, competir ni
ejercer actividad profesional.

16.2 Alta
  •    Requiere cuenta KOMBAX.
  •    Para autorregistro autónomo se mantiene la regla general de 16+.


                      Página 13 · Documento de planificación previa · Pendiente de autorización
                                                               KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •     No requiere verificación profesional.
  •     Debe poder crearse con onboarding mínimo.

16.3 Capacidades iniciales
  •     Leer Social.
  •     Explorar perfiles públicos.
  •     Leer Events.
  •     Marcar “Me interesa”.
  •     Guardar/seguir avisos de Events.
  •     Consultar resultados y Fight Cards públicas.
  •     Explorar Showcase.
  •     Guardar contenido/productos cuando aplique.
  •     Gestionar notificaciones.
  •     Privacidad/soporte.

16.4 Restricciones iniciales recomendadas
  •     No publicar contenido público por defecto.
  •     No crear Events.
  •     No publicar Showcase.
  •     No gestionar terceros.
  •     No tener Finanzas.
  •     No recibir insignia de verificación.

La publicación social de Espectador, si se desea más adelante, se tratará como capacidad separada
después de observar el piloto.

16.5 Visibilidad
El perfil Espectador debe poder operar como identidad de consumo sin convertirse necesariamente en
una ficha pública indexada. La visibilidad pública, si se habilita, será una decisión explícita y separada.




17. Matriz funcional resumida
Dominio          Club              Miembro        Competidor      Federación      Marca           Profesional     Espectador


Seguridad/
Privacidad/      Sí                Sí             Sí              Sí              Sí              Sí              Sí
Soporte

                                                                                                                  No por
Perfil público   Sí                Opcional       Sí              Sí              Sí              Sí
                                                                                                                  defecto

                                   Según
Social leer      Sí                               Sí              Sí              Sí              Sí              Sí
                                   activación

Social           Según
                                   Según reglas   Sí              Sí              Sí              Sí verificado   No inicial
publicar         identidad

Showcase         Plan/                            Futuro/                                         Servicios si
                                   No                             Futuro          Sí                              No
publicar         capacidad                        capacidad                                       aplica


                             Página 14 · Documento de planificación previa · Pendiente de autorización
                                                                KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES



Dominio        Club            Miembro            Competidor          Federación        Marca          Profesional     Espectador

Events leer    Sí              Sí                 Sí                  Sí                Sí             Sí              Sí

                                                                                                       Por
Events         Plan/
                               No                 No base             Sí/capacidad      No base        subtipo/capac   No
organizar      capacidad
                                                                                                       idad

Events         Club/                                                                                   Según
                               Sí según flujo     Sí                  Gestión           No base                        No
participar     deportista                                                                              subtipo

                                                  Solo si             Solo si           Solo si        Solo si         Solo si
                               Acceso según
Mi Club        Sí                                 además              además            además         además          además
                               rol
                                                  pertenece           pertenece         pertenece      pertenece       pertenece

Finanzas                       Solo su
               Sí                                 No                  No                No             No              No
Club                           estado

Finanzas                                          No en esta
               No              No                                     No                No             Sí              No
Profesional                                       fase

Clubes
               No              No                 No                  Sí                No             No              No
afiliados

Representado
               No              No                 No                  No                No             Solo Manager    No
s

                                                                                                       Entrenador/
Clientes
               No              No                 No                  No                No             otros           No
propios
                                                                                                       autorizados

Moderación
               No por perfil   No                 No                  No                No             No              No
plataforma


Nota: las funciones de plataforma Owner/Moderador son roles globales separados del tipo de perfil.




18. Matriz de creación y verificación
                                                                                     Edad mínima
Perfil                  Cómo nace                      Verificación                                           Multi-gestor
                                                                                     autónoma


Club                    Solicitud de entidad           Obligatoria                   Responsable adulto       Sí, equipo club

                        Alta/membresía del             Edad/relación por club        16+ autorregistro;       No como identidad
Miembro
                        club                           para Social                   menores vía club/tutor   personal

                        Perfil directo o               Para
                                                                                     16+ cuenta; revisar      Propietario; delegación
Competidor              continuidad desde              badge/capacidades
                                                                                     capacidades sensibles    limitada futura
                        Miembro                        sensibles

Federación              Perfil directo                 Obligatoria                   Responsable adulto       Sí

Marca                   Perfil directo                 Obligatoria                   Responsable adulto       Sí

                                                       Obligatoria para                                       Limitado según
Profesional             Perfil directo + subtipo                                     18+
                                                       capacidades sensibles                                  naturaleza

Espectador              Perfil ligero de cuenta        No                            16+                      No


                         Página 15 · Documento de planificación previa · Pendiente de autorización
                                                         KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES




19. Modelo de capacidades objetivo

19.1 Mantener y reutilizar capacidades existentes
Se mantendrán las capacidades ya presentes en kombax_capacidades cuando coincidan con el
dominio.

19.2 Nuevas familias propuestas
Nombres finales se validarán antes de migrar. Propuesta conceptual:

Perfil/identidad
  •       profile.direct.manage
  •       profile.public.manage
  •       profile.media.manage
  •       profile.settings.manage

Profesional común
  •       professional.profile.manage
  •       professional.services.manage
  •       professional.schedule.manage
  •       professional.finance.manage
  •       professional.finance.reports

Entrenador
  •       professional.clients.manage
  •       professional.sessions.manage
  •       professional.training.notes.manage

Representante
  •       professional.represented.manage
  •       professional.delegations.manage
  •       professional.opportunities.manage

Médico
  •       professional.credentials.medical
  •       events.medical.assignments.read

No se crea aún health.records.read ni equivalente.

Árbitro
  •       professional.credentials.official
  •       events.official.assignments.read
  •       events.official.results.submit


                       Página 16 · Documento de planificación previa · Pendiente de autorización
                                                       KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


Promotor
  •    events.public.organize
  •    events.public.partners.manage
  •    events.public.fights.manage

Espectador
  •    social.read
  •    events.public.read
  •    events.public.engage

19.3 Resolución efectiva
El frontend no debe decidir permisos basándose solo en el nombre del perfil. Debe recibir un conjunto
efectivo de capacidades del backend.

capacidades efectivas =
  capacidades base por tipo
+ capacidades base por subtipo
+ capacidades por plan
+ autorizaciones/delegaciones activas
- suspensiones/restricciones/moderación

Las capacidades sensibles deben comprobarse también en el backend al mutar.




20. Tipo de perfil ≠ Plan

20.1 Regla
No crear “Entrenador Pro” como tipo. Crear:

Tipo: Profesional
Subtipo: Entrenador
Plan: Base / Pro

Igualmente:

Tipo: Competidor
Plan: gratuito / premium futuro

20.2 Estado actual a preservar
Ya existen planes de Competidor, Federación y Marca en la capa de capacidades. La evolución debe
mantener compatibilidad y no borrar entitlements existentes.

20.3 Club
El modelo actual de Club Básico/Premium puede seguir siendo la fuente de verdad del tenant Club. Se
creará un adaptador de resolución para que la UI pueda consultar capacidades homogéneamente sin
migrar a la fuerza todas las finanzas/roles de Club al modelo de perfiles directos.


                     Página 17 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES




21. Navegación y experiencia por perfil

21.1 Objetivo
La aplicación debe seguir sintiéndose como una sola KOMBAX, pero cada identidad gestionada debe
tener un entorno relevante.

21.2 Entornos
Club

Mi Club - se conserva.

Federación

Mi Federación - nuevo shell específico.

Marca

Mi Marca - shell de identidad comercial.

Profesional

Mi actividad - shell profesional, con módulos según subtipo.

Competidor

Mi perfil de Competidor - gestión deportiva individual.

Espectador

Mi perfil - configuración, guardados, intereses y privacidad.

Miembro

Accede a Mi Club según su relación y a su identidad pública Social cuando esté activada.

21.3 Navegación global compartida
Social, Showcase, Events, mensajes/notificaciones y acceso a perfiles se mantienen como servicios
comunes. El menú no debe duplicar todas las áreas por cada identidad.

21.4 Cambio de identidad
La selección “Actuar como” existente debe ampliarse de forma coherente:

  •     solo mostrar identidades que el usuario puede usar;
  •     mostrar claramente el tipo;
  •     conservar contexto al cambiar;
  •     no mezclar permisos entre perfiles;
  •     limpiar caches de sujeto cuando cambie la identidad para evitar contaminación visual.




                      Página 18 · Documento de planificación previa · Pendiente de autorización
                                                       KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES



22. Arquitectura del Perfil Profesional en backend

22.1 Reutilizar perfiles_kombax_directos
No se crea una tabla de identidad paralela para Profesional. tipo='profesional' ya está permitido por
el esquema.

22.2 Extensión normalizada propuesta
Crear una extensión 1:1 del perfil profesional para datos propios del dominio y una relación de
especialidades:

perfiles_kombax_directos
    1
    │
    1
kombax_professional_profiles
    │
    ├── principal_specialty
    └── specialties[] / tabla relacional

Se recomienda catálogo normalizado de especialidades para permitir traducción, validación,
capacidades y expansión futura.

22.3 Campos mínimos
  •    perfil_directo_id
  •    especialidad principal
  •    estado profesional
  •    ciudad/ámbito de servicio opcional
  •    modalidad de servicio opcional
  •    visibilidad
  •    datos de acreditación solo mediante tablas/documentos privados cuando sean necesarios

Evitar introducir DNI, documentación sanitaria o credenciales sensibles en columnas públicas.




23. Representación y delegaciones
Se propone una tabla de delegaciones específica y auditable en lugar de usar únicamente “gestores del
perfil” para relaciones de representación deportiva.

Concepto:

professional_delegations
- professional_profile_id
- target_profile_id
- relation_type
- status: requested/accepted/rejected/revoked/expired
- permissions[]

                     Página 19 · Documento de planificación previa · Pendiente de autorización
                                                           KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


- requested_by
- accepted_by
- starts_at
- expires_at

Reglas:

  •       Solo relación aceptada da permisos.
  •       Revocación inmediata.
  •       Nunca compartir credenciales.
  •       Permisos mínimos.
  •       Audit trail.
  •       El owner KOMBAX mantiene facultades globales separadas y auditadas.




24. Finanzas Profesionales - diseño sin romper Finanzas Club

24.1 Problema arquitectónico
Finanzas Club está profundamente ligado a club_id, socios, grupos, cuotas y roles de club. Convertir un
Profesional en un “club ficticio” para reutilizar esas tablas sería incorrecto y crearía deuda grave.

24.2 Solución recomendada
Crear una capa común de interfaz financiera, no duplicar toda la aplicación.

UI/Math/Reports comunes
    │
    ├── Adapter Club Finance → tablas/RPC actuales
    └── Adapter Professional Finance → dominio profesional

Se comparten:

  •       KPIs;
  •       cálculo de generado/cobrado/pendiente;
  •       gráficos;
  •       filtros;
  •       estados;
  •       exportación/informes;
  •       componentes visuales;
  •       semántica de cargo/pago/pendiente;
  •       notificaciones.

Se separan las relaciones de negocio:

  •       Club: alumno, grupo, cuota, matrícula.
  •       Profesional: cliente, servicio, sesión, honorario/comisión.

24.3 Entidades profesionales mínimas
  •       Clientes/contactos profesionales.


                         Página 20 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •    Servicios/tarifas.
  •    Cargos.
  •    Pagos registrados.
  •    Gastos opcionales.
  •    Informes.
  •    Para Manager: honorarios/comisiones vinculables a representado.
  •    Para Árbitro/Médico: honorarios vinculables a asignación/evento.

24.4 Terminología legal
KOMBAX seguirá sin procesar dinero. No se llamará “factura fiscal” a un documento si no existe un
módulo fiscal que cumpla los requisitos correspondientes. Se usarán términos administrativos como
cargo, pago registrado, recibo/comprobante interno e informe, según proceda.

24.5 RLS
Finanzas Profesionales deben quedar aisladas por professional_profile_id/subject y solo accesibles al
owner o gestores con capacidad financiera explícita. No se mezclan con club_id.




25. Integración con KOMBAX Social

25.1 Identidad pública
  •    Club: identidad pública actual.
  •    Miembro: identidad opcional derivada del club.
  •    Competidor: identidad pública propia.
  •    Federación: identidad pública institucional.
  •    Marca: identidad corporativa.
  •    Profesional: identidad profesional.
  •    Espectador: no pública por defecto.

25.2 Publicación
La capacidad social.publish debe determinar quién puede publicar. No basta con ser direct_profile.

25.3 Contacto
Las reglas de contacto deben seguir aplicando edad, bloqueo, moderación y elegibilidad. Para
Profesional se podrán añadir motivos específicos sin crear otro sistema de mensajería.




26. Integración con Showcase
Showcase se mantendrá como sistema único por proveedor/identidad.

  •    Marca: productos y servicios autorizados.
  •    Club: material/servicios según plan.


                      Página 21 · Documento de planificación previa · Pendiente de autorización
                                                       KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •    Profesional: servicios profesionales, cuando su subtipo lo permita.
  •    Competidor: consumo; publicación futura solo si se decide como capacidad propia.
  •    Federación: consumo y posibles publicaciones institucionales futuras, no asumidas.
  •    Espectador/Miembro: consumo.

Las conversaciones siguen vinculadas al elemento concreto.




27. Integración con Events

27.1 Descubrimiento
Todos los perfiles compatibles pueden leer Events públicos.

27.2 Organización
Depende de capacidad, no de tipo bruto:

  •    Club Premium: organizar.
  •    Federación: organizar.
  •    Promotor/Organizador Profesional: organizar si tiene capacidad.
  •    Entrenador: seminarios/eventos solo si se le concede capacidad.
  •    Competidor: no organiza por defecto.
  •    Espectador: no.

27.3 Participación
Competidor, Miembro/deportista y determinados Profesionales pueden participar o ser asignados
según el rol del evento.

27.4 Oficialidad
Árbitros/médicos reciben permisos del evento concreto, no administración global.




28. Privacidad y soporte en todos los perfiles
R26/R27 ya establecen una base transversal. La nueva arquitectura debe mantener:

  •    soporte@kombax.es visible.
  •    Centro de Privacidad y soporte.
  •    Autorización temporal por sujeto.
  •    Alcance limitado.
  •    Revocación.
  •    Auditoría.
  •    Agente de soporte IA sin acceso global automático.
  •    Owner humano con potestad global independiente y auditada.



                     Página 22 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


Cada nuevo shell (Mi Federación, Mi Marca, Mi actividad, Mi Competidor, Espectador) debe incluir un
acceso consistente al mismo centro, no una copia.




29. Verificación y credenciales

29.1 Niveles conceptuales
Separar:

  1.   Cuenta verificada por email/auth.
  2.   Identidad profesional/institucional verificada por KOMBAX.
  3.   Credencial/especialidad verificada.
  4.   Capacidad habilitada.

Una insignia global no debe implicar todas las acreditaciones posibles.

29.2 Profesional
  •    Entrenador: evidencia profesional/de actividad.
  •    Representante: identidad/actividad; la relación con competidores siempre requiere aceptación
       aparte.
  •    Médico: acreditación específica si se muestra como sanitario verificado.
  •    Árbitro: acreditación/federación/entidad si se presenta como oficial verificado.
  •    Promotor: evidencia de actividad/organización.

Documentos de verificación deben seguir siendo privados.




30. Diseño de base de datos propuesto
Los números concretos de migración se confirmarán justo antes de ejecutar. R27 termina actualmente
en la serie 195, por lo que se espera comenzar alrededor de 196.

Migración A - Perfil/capability foundation
Objetivos:

  •    catálogo de especialidades profesionales;
  •    extensión de Perfil Profesional;
  •    reglas de integridad;
  •    capacidades base nuevas;
  •    índices solo para rutas de consulta previstas;
  •    RLS.

Migración B - Mutation/read RPC
  •    abrir profesional y espectador con reglas diferentes;
  •    impedir que Espectador use flujo de verificación profesional innecesario;
  •    mantener Competidor/Marca/Federación existentes;

                      Página 23 · Documento de planificación previa · Pendiente de autorización
                                                         KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •    age gates;
  •    resolución de capacidades;
  •    lectura de “mi hub” por perfil.

Migración C - Delegaciones profesionales
  •    representación/relaciones aceptadas;
  •    permisos;
  •    auditoría;
  •    expiración/revocación.

Migración D - Finanzas Profesionales
Solo después de estabilizar Perfil Profesional:

  •    subject profesional;
  •    clientes;
  •    servicios;
  •    cargos/pagos;
  •    RLS;
  •    RPC;
  •    auditoría;
  •    notificaciones.

Ninguna migración deberá borrar datos ni alterar destructivamente las tablas financieras Club.




31. RLS y seguridad

31.1 Perfil directo
Solo owner/gestor autorizado puede administrar la identidad.

31.2 Profesional
  •    propietario gestiona perfil;
  •    gestores secundarios solo según rol/capacidad;
  •    documentos de verificación no son públicos;
  •    datos financieros no son públicos;
  •    delegaciones solo visibles para participantes/administración autorizada.

31.3 Federación
La pertenencia/afiliación de un club no debe crear política RLS que permita leer tablas privadas del
club.

31.4 Espectador
No obtiene permisos de escritura privilegiada por el mero hecho de existir.




                       Página 24 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES



31.5 Test obligatorio de bypass
Todos los RPC SECURITY DEFINER nuevos deberán:

  •    fijar search_path;
  •    validar auth.uid();
  •    validar subject/perfil;
  •    validar capacidad sensible;
  •    no aceptar IDs de sujeto sin comprobar ownership;
  •    no confiar en datos de frontend.




32. Frontend - arquitectura propuesta

32.1 Archivos existentes previsiblemente afectados
  •    web/js/modules/gateway.js
  •    web/js/core/identity-context.js
  •    web/js/core/repositories.js
  •    router/entrada principal que gestione Mis perfiles
  •    web/js/modules/support-privacy.js
  •    web/js/modules/public-profile.js
  •    web/js/modules/kombax-social.js
  •    web/js/modules/showcase.js
  •    web/js/modules/kombax-events.js
  •    CSS de gateway/perfiles/hubs
  •    web/index.html
  •    web/service-worker.js por cache busting

32.2 Nuevos módulos recomendados
Nombres orientativos:

  •    profile-registry.js - definición única de tipos/subtipos y labels.
  •    capability-resolver.js - cliente de capacidades efectivas.
  •    managed-profile-hub.js - shell común.
  •    federation-hub.js
  •    professional-hub.js
  •    competitor-hub.js
  •    brand-hub.js
  •    spectator-hub.js
  •    professional-finance.js en la fase financiera.

La lógica de tipo se concentra en registry/hub y no se replica en toda la app.




                      Página 25 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES



32.3 Patrón de composición
ManagedProfileHub
 ├── header identidad
 ├── status/verificación
 ├── navegación por capacidades
 ├── privacidad/soporte global
 └── módulos permitidos




33. Backend - repositorios y RPC
El repositorio frontend deberá exponer interfaces de dominio, por ejemplo:

  •    profiles.mine()
  •    profiles.capabilities(profileId)
  •    profiles.professionalDetails(profileId)
  •    profiles.saveProfessional(...)
  •    profiles.delegations(...)
  •    profiles.federationWorkspace(...)
  •    profiles.spectatorState(...)

No realizar SELECT directo a tablas sensibles si el patrón actual usa RPC seguro.




34. Secuencia de ejecución recomendada
No recomiendo una única revisión gigantesca. La implementación debe ser secuencial para conservar
capacidad de rollback y atribuir regresiones.

R28 - PROFILE & CAPABILITY FOUNDATION
Objetivo: cerrar taxonomía, capability resolver, abrir Profesional/Espectador de forma segura y
mantener perfiles existentes.

Incluye:

  •    catálogo de tipos/subtipos;
  •    backend de Profesional/Espectador;
  •    age gates;
  •    capability resolver;
  •    onboarding básico;
  •    Perfil Profesional básico;
  •    Perfil Espectador básico;
  •    actualización de Mis perfiles;
  •    soporte/privacidad transversal;
  •    pruebas multiperfil.

                      Página 26 · Documento de planificación previa · Pendiente de autorización
                                                          KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


No incluye Finanzas Profesionales todavía.

Gate de cierre: creación/lectura/edición/aislamiento de todos los perfiles básicos, sin regresión
Club/Social/Showcase/Events.

R29 - MANAGED PROFILE HUBS
Objetivo: diferenciar claramente los entornos sin duplicar la app.

Incluye:

  •    Mi Federación;
  •    Mi Marca;
  •    Mi actividad;
  •    Mi Competidor;
  •    Mi perfil Espectador;
  •    navegación por capacidades;
  •    gestores de perfil;
  •    pruebas responsive y cambio de identidad.

R30 - PROFESSIONAL RELATIONS & BASIC OPERATIONS
Incluye:

  •    subtipo Entrenador: clientes/sesiones básicas;
  •    Manager: representados/delegaciones;
  •    Médico: credenciales/disponibilidad sin salud clínica;
  •    Árbitro: acreditaciones/asignaciones;
  •    Promotor: herramientas Events autorizadas;
  •    permisos por relación.

R31 - PROFESSIONAL BASIC FINANCE
Incluye:

  •    adapter financiero común;
  •    clientes/servicios/cargos/pagos;
  •    informes básicos;
  •    notificaciones;
  •    aislamiento financiero;
  •    no cobro in-app;
  •    no facturación fiscal automática.

R32 - PROFILE MATRIX HARDENING / PILOT RC
Incluye:

  •    matriz E2E completa;
  •    auditoría RLS;
  •    advisors;
  •    performance;
  •    Android/PWA/desktop;


                        Página 27 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •    regresión global;
  •    documentación final;
  •    decisión de qué funciones se reservan a planes Pro.

Esta secuencia puede compactarse solo si las puertas de QA demuestran que el riesgo es bajo; por
defecto se mantendrá separada.




35. Plan de QA exhaustivo

35.1 Matriz de cuentas
Crear identidades QA controladas:

  •    Cuenta A: Dirección Club A + Competidor.
  •    Cuenta B: Miembro Club A.
  •    Cuenta C: Federación.
  •    Cuenta D: Marca.
  •    Cuenta E: Profesional Entrenador.
  •    Cuenta F: Profesional Manager.
  •    Cuenta G: Profesional Médico.
  •    Cuenta H: Profesional Árbitro.
  •    Cuenta I: Profesional Promotor.
  •    Cuenta J: Espectador.
  •    Cuenta K: miembro de Club B para pruebas cross-tenant.

Datos QA deben crearse de forma idempotente o en transacciones con rollback cuando sea posible.

35.2 Pruebas de creación
Para cada perfil:

  •    crear;
  •    guardar borrador;
  •    reabrir;
  •    completar;
  •    solicitar verificación si aplica;
  •    cancelar/retirar;
  •    editar autorizado;
  •    impedir edición no autorizada;
  •    comprobar persistencia.

35.3 Pruebas de identidad activa
  •    cambiar de Club a Competidor;
  •    Competidor a Profesional;
  •    Profesional a Federación si gestiona ambas;
  •    garantizar que menú/capacidades cambian;
  •    comprobar que no quedan datos visuales del sujeto anterior;

                      Página 28 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •    recargar app y confirmar identidad esperada.

35.4 Pruebas de RLS
Club A vs Club B

Cero acceso cruzado a privados.

Federación vs Club afiliado

Federación ve solo lo público/expresamente compartido.

Manager vs Competidor

Sin aceptación: 0 permisos.
Con aceptación: solo permisos delegados.
Tras revocar: 0 permisos.

Profesional vs otros Profesionales

Cero lectura de clientes/finanzas ajenas.

Espectador

Cero endpoints administrativos.

35.5 Edad
  •    Profesional menor de 18: bloqueado.
  •    Espectador autorregistrado bajo 16: bloqueado según regla de cuenta.
  •    Miembro 14+ con edad verificada: Social conforme a regla existente.
  •    contacto con menores: mantener restricciones existentes.

35.6 Verificación
  •    perfil no verificado no recibe badge;
  •    no obtiene capacidades sensibles por error;
  •    cambio a verificado activa solo capacidades previstas;
  •    suspensión retira capacidades sin borrar historial.

35.7 Social
  •    publicación solo con capacidad;
  •    lectura Espectador;
  •    identidad correcta del autor;
  •    no exposición de datos privados;
  •    moderación intacta.

35.8 Showcase
  •    Marca publica;
  •    Profesional autorizado publica servicios;
  •    Espectador no publica;
  •    hilo por elemento se mantiene.



                      Página 29 · Documento de planificación previa · Pendiente de autorización
                                                            KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES



35.9 Events
  •     Federación organiza;
  •     Promotor autorizado organiza;
  •     Árbitro solo actúa en asignación;
  •     Competidor participa;
  •     Espectador solo consume/interés;
  •     Club conserva flujo existente.

35.10 Soporte
En todos los perfiles:

  •     correo visible;
  •     privacidad/soporte abre;
  •     subject correcto;
  •     autorización no afecta otro perfil;
  •     revocación funciona;
  •     agent claim sigue reservado;
  •     Owner mantiene control global.




36. QA de Finanzas Profesionales
Cuando se implemente R31:

  •     Profesional A no ve Profesional B.
  •     Profesional no ve Finanzas Club salvo que también tenga rol de Club y cambie al contexto
        correspondiente.
  •     Club no ve Finanzas Profesional.
  •     cargo no es recibo.
  •     pago completo puede generar comprobante interno según diseño.
  •     recurrentes no duplican periodo.
  •     reportes filtran por subject.
  •     notificaciones no cruzan subject.
  •     no se generan documentos llamados factura fiscal sin módulo fiscal específico.




37. Rendimiento y escala

37.1 Objetivo inicial
La fase debe ser suficiente para piloto de múltiples perfiles y 10 clubes sin introducir consultas N+1,
listados ilimitados ni joins globales evitables.

37.2 Reglas
  •     paginación en directorios;


                          Página 30 · Documento de planificación previa · Pendiente de autorización
                                                       KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •    cache acotada por subject;
  •    invalidación al cambiar identidad;
  •    índices basados en queries reales;
  •    no cargar managers/delegaciones/documentos/finanzas si el módulo no está abierto;
  •    lazy loading de hubs secundarios;
  •    no precargar todas las identidades de toda la plataforma.

37.3 Advisors
Tras cada migración real:

  •    Security Advisor.
  •    Performance Advisor.
  •    clasificar findings nuevos vs heredados.
  •    corregir findings introducidos por la revisión o justificar evidencia.




38. Seed y datos existentes

38.1 Preservación
No se ejecutará:

  •    DELETE masivo;
  •    TRUNCATE;
  •    recreación destructiva de perfiles;
  •    reasignación de owners sin evidencia;
  •    conversión automática de tipos existentes.

38.2 Datos actuales
Competidor y Federación existentes deben sobrevivir sin cambios semánticos.

38.3 Idempotencia
Seeds QA deben usar slugs/identificadores dedicados y nunca colisionar con Urban Warriors o datos de
pilotos reales.




39. Migración y rollback

39.1 Estrategia
  •    migraciones aditivas;
  •    constraints nuevas después de rellenar defaults seguros;
  •    no renombrar RPC usada por frontend sin fallback controlado;
  •    migraciones compensatorias si un cambio live requiere corrección;
  •    preservar historial.


                     Página 31 · Documento de planificación previa · Pendiente de autorización
                                                           KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES



39.2 Rollback funcional
Cada fase debe definir qué se desactiva sin borrar datos. Profesional/Espectador deben poder quedar
detrás de feature flag o entitlement de apertura si una regresión exige congelarlos.




40. Android, PWA y desktop
Cada fase frontend debe cerrar:

  •    npm test completo;
  •    build;
  •    paridad web = dist = android/assets/www;
  •    Service Worker/cache version;
  •    package Android com.urbanwarriors.app intacto;
  •    Firebase intacto;
  •    manifest intacto salvo cambio justificado;
  •    preflight Android;
  •    firma solo si existen propiedades locales y se decide generar release;
  •    no afirmar APK/AAB signed sin evidencia.

Pruebas visuales mínimas:

  •    360x800;
  •    390/412 móvil moderno;
  •    tablet 768/820;
  •    desktop 1280+;
  •    Android WebView real antes de certificar la revisión final.




41. Archivos de documentación que deben acompañar cada ZIP
El ZIP final de cada revisión derivada de este plan debe contener:

  •    este Plan Maestro PDF;
  •    este Plan Maestro en fuente Markdown;
  •    plan específico de la revisión;
  •    changelog;
  •    QA validation;
  •    backend state;
  •    migration list;
  •    test results;
  •    parity report;
  •    Android preflight;
  •    continuity status;
  •    packaging certification;


                         Página 32 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  •    SHA-256 del ZIP.

Este documento debe permanecer dentro de todos los ZIP derivados durante la implantación del
modelo de perfiles para conservar la historia de decisiones.




42. Riesgos principales y mitigación

Riesgo 1 - romper Mi Club intentando generalizar todo
Mitigación: Mi Club sigue siendo un dominio especial; el hub genérico se usa para perfiles directos.

Riesgo 2 - fuga de datos Federación → Club
Mitigación: afiliación no crea RLS privada; pruebas cross-tenant obligatorias.

Riesgo 3 - Profesional convertido en falso Club
Mitigación: finanzas profesionales con subject propio y adapter común, nunca club_id ficticio.

Riesgo 4 - duplicar Competidor y Profesional
Mitigación: Competidor nunca es subtipo Profesional.

Riesgo 5 - permisos basados solo en frontend
Mitigación: capacidades sensibles validadas en RPC/RLS.

Riesgo 6 - Especialidades profesionales con privilegios excesivos
Mitigación: subtype define elegibilidad, no concede automáticamente acceso sensible.

Riesgo 7 - Médico interpretado como acceso sanitario
Mitigación: sin expediente médico en esta fase.

Riesgo 8 - Manager accediendo sin consentimiento
Mitigación: delegación solicitada/aceptada/revocable.

Riesgo 9 - Espectador aumentando superficie de abuso
Mitigación: perfil privado/no publicador por defecto; solo consumo e interacción limitada.

Riesgo 10 - demasiadas funciones en una sola revisión
Mitigación: R28-R32 secuencial con gates.

Riesgo 11 - entitlements inconsistentes
Mitigación: resolver efectivo backend + pruebas por perfil/plan.




                      Página 33 · Documento de planificación previa · Pendiente de autorización
                                                        KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES



Riesgo 12 - caches mezclando sujetos
Mitigación: cache keys con subject + invalidación al cambiar identidad.




43. Criterios de cierre de R28
R28 no se considerará cerrada hasta que:

  1.    Profesional pueda crearse de forma válida 18+.
  2.    Espectador pueda crearse según age gate.
  3.    Competidor/Marca/Federación existentes sigan funcionando.
  4.    Club/Miembro no sufran migración destructiva.
  5.    Subtipo Profesional persista y valide catálogo.
  6.    Capacidades efectivas se resuelvan desde backend.
  7.    RLS impida accesos entre sujetos.
  8.    Gateway y Mis perfiles muestren la taxonomía correcta.
  9.    Competidor Profesional no aparezca como subtype.
  10.   Privacidad/soporte funcione en Profesional/Espectador.
  11.   Tests dedicados pasen.
  12.   Regresión global pase.
  13.   Build/paridad pase.
  14.   Advisors sean ejecutados y clasificados.
  15.   No queden datos QA inesperados.
  16.   ZIP autocontenido incluya este documento.




44. Criterios de cierre de R29
  •     Mi Federación claramente distinto de Mi Club.
  •     Mi Marca funcional.
  •     Mi actividad funcional.
  •     Mi Competidor funcional.
  •     Mi perfil Espectador funcional.
  •     Menús derivados de capacidades.
  •     Cambio de identidad sin contaminación.
  •     responsive validado.




45. Criterios de cierre de R30
  •     Entrenador puede gestionar solo sus clientes/agenda base.
  •     Manager solo accede a representados con consentimiento.
  •     Médico tiene credenciales/servicios pero no salud clínica.
  •     Árbitro tiene asignaciones limitadas.

                      Página 34 · Documento de planificación previa · Pendiente de autorización
                                                       KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


 •   Promotor integra Events por capacidades.
 •   todas las relaciones son revocables y auditables.




46. Criterios de cierre de R31
 •   Finanzas Profesionales aisladas.
 •   no fake club.
 •   no regresión Finanzas Club.
 •   cargos/pagos/reportes básicos correctos.
 •   notificaciones correctas.
 •   multitenant profesional validado.




47. Criterios de cierre R32 / Pilot RC
 •   matriz completa de perfiles PASS.
 •   matriz cross-tenant PASS.
 •   pruebas Android reales.
 •   pruebas PWA/desktop.
 •   10 clubes compatibles sin cambio arquitectónico.
 •   Profesional/Espectador estabilizados.
 •   Federación usable como entorno distinto.
 •   documentación completa.
 •   decisión explícita de funciones Pro posterior.




48. Fuera de alcance de este plan base
 •   Competidor incluido dentro de Profesional: expresamente prohibido por decisión de producto.
 •   Procesamiento de pagos.
 •   Pasarela bancaria.
 •   Facturación fiscal completa.
 •   Expediente sanitario.
 •   Historia clínica.
 •   E-prescripción.
 •   Contratos legales automatizados entre Manager y Competidor.
 •   Marketplace de contratación.
 •   Publicación social libre del Espectador.
 •   Funciones Pro finales y precios definitivos.
 •   IA de soporte conectada al correo: infraestructura de acceso existe, integración se planifica
     aparte.
 •   Deploy Netlify/GitHub sin autorización.




                     Página 35 · Documento de planificación previa · Pendiente de autorización
                                                         KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES



49. Decisiones de producto congeladas por este documento
  1.    Perfil Profesional se habilitará.
  2.    Perfil Espectador se habilitará.
  3.    Competidor sigue siendo un perfil independiente.
  4.    No existe subtipo “Competidor Profesional” dentro de Profesional.
  5.    Entrenador autónomo pertenece a Profesional.
  6.    Representante/Manager pertenece a Profesional.
  7.    Médico/Sanitario pertenece a Profesional.
  8.    Árbitro/Juez pertenece a Profesional.
  9.    Promotor/Organizador pertenece a Profesional.
  10.   Profesional puede tener especialidad principal y secundarias.
  11.   Profesional autónomo requiere 18+.
  12.   Espectador se mantiene inicialmente como consumidor y no publicador.
  13.   Federación tendrá entorno Mi Federación distinto de Mi Club.
  14.   Marca tendrá entorno Mi Marca.
  15.   Profesional tendrá entorno Mi actividad.
  16.   Competidor tendrá su entorno propio.
  17.   Club conserva Mi Club.
  18.   Miembro conserva su naturaleza vinculada al Club.
  19.   soporte/privacidad es GLOBAL.
  20.   las capacidades, no el tipo por sí solo, gobiernan las operaciones sensibles.
  21.   las funciones Pro se añadirán después mediante entitlements/planes.
  22.   Finanzas Profesionales no se implementarán fingiendo club_id.
  23.   Una Federación no ve los datos privados de sus clubes afiliados.
  24.   Un Manager requiere aceptación del representado.
  25.   Un Médico no recibe acceso a salud por su tipo de perfil.




50. Protocolo de ejecución tras autorización
Una vez autorizado este plan, antes de tocar código se realizará para la revisión concreta:

  1.    Confirmación física del ZIP base y SHA.
  2.    Extracción limpia.
  3.    Inventario exacto de archivos afectados.
  4.    Lectura de migraciones más recientes y número siguiente disponible.
  5.    Snapshot de constraints/RPC/capabilities actuales.
  6.    Plan específico de revisión derivado de este Plan Maestro.
  7.    Implementación aditiva.
  8.    Migraciones reales solo cuando corresponda.
  9.    Tests unitarios/dedicados.
  10.   E2E backend.
  11.   RLS cross-subject.
  12.   Advisors.

                       Página 36 · Documento de planificación previa · Pendiente de autorización
                                                           KOMBAX 20.101 · PLAN MAESTRO R28 · PERFILES Y CAPACIDADES


  13.   Regresión completa histórica.
  14.   Build/paridad.
  15.   Android preflight.
  16.   QA visual.
  17.   Limpieza de seeds QA.
  18.   Packaging autocontenido.
  19.   SHA-256.
  20.   Informe final en estados IMPLEMENTADO / VALIDADO / PENDIENTE / NO MODIFICADO.




51. Autorización pendiente
No se ha realizado ninguna modificación de código ni de Supabase como consecuencia de este
Plan Maestro.

La siguiente acción requiere una autorización explícita del Owner para iniciar la fase R28 PROFILE &
CAPABILITY FOUNDATION o para modificar la secuencia propuesta.




                         Página 37 · Documento de planificación previa · Pendiente de autorización
