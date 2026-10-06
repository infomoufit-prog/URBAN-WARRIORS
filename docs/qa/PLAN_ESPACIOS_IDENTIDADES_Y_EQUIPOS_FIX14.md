# Plan acumulativo FIX14 · espacios, identidades y equipos

Fecha: 6 de octubre de 2026.

## Cierre de implementación

Plan histórico ejecutado. Las tres migraciones FIX14 están aplicadas y la validación final ha terminado: 96 suites aprobadas, tres P2 heredados y cero fallos nuevos. Incluye grados por disciplina y decisiones definitivas reservadas a administración titular, también en clubes piloto. El alcance y los límites comprobados constan en AUDITORIA_ACUMULATIVA_FIX14.md. No se ha desplegado producción ni generado una APK/AAB.

## Estado histórico al redactar el plan

La base de trabajo es el código acumulativo de FIX13. Hay cambios preliminares locales para presentación administrativa privada, archivo de tarjetas en Mi Espacio y acceso al trámite de vendedor. Todavía no se ha aplicado la nueva migración a Supabase ni se ha ejecutado la validación de FIX14. Ninguno de estos cambios constituye una entrega certificada. No se ha desplegado FIX14 en Netlify ni se ha compilado una APK o AAB nueva.

La referencia visual es la navegación actual de Mi Club: identidad, colores LED de Social/Events/Showcase/Recursos, menú lateral y cierre de sesión. La referencia funcional del inicio es el panel de Mi Club, adaptado a la actividad de cada identidad.

## 1. Inventario y cierre del alcance

- Registrar archivos y migraciones modificados respecto a FIX13 y conservar todos los cambios acumulativos.
- Revisar el flujo real de acceso general, acceso de club, selección de identidad, Mi Espacio, servicios y permisos de equipo.
- Contrastar las funciones y restricciones de la base de datos con los formularios y el comportamiento de la webapp.
- Comprobar las causas antes de cambiar reglas. La inspección inicial encontró que los índices de miembros del club no reservan una única plaza por rol: la unicidad corresponde a club, persona y rol.
- Mantener el alta piloto, sus plazas y las finanzas autorizadas; mantener las automatizaciones de cobro recurrente desactivadas.

Resultado: inventario de problemas confirmados, cambios necesarios y dependencias. No modificar el Club existente para imitar los otros espacios; usarlo como referencia y protegerlo con regresión.

## 2. Modelo de cuenta, identidad y contexto activo

La cuenta de correo y contraseña autentica a una persona. Las identidades y organizaciones gestionadas tienen sus propios datos, equipo, verificación y servicios.

- Con varias identidades: la cuenta permite seleccionarlas claramente.
- Con una sola identidad o un único club accesible: facilitar entrada directa a su espacio, conservando un acceso explícito a la gestión de cuenta y creación de identidades.
- Con ninguna identidad: conservar exploración y las acciones de creación o vinculación que correspondan.
- Evitar redirecciones circulares o entradas automáticas cuando haya una solicitud pendiente, condiciones por aceptar, datos obligatorios pendientes o contexto de soporte Owner.
- Mantener separados el espacio administrativo y el perfil público social. Las organizaciones no se fusionan con el perfil personal.
- Transportar el identificador de la identidad seleccionada a Showcase, servicios y demás herramientas. No escoger silenciosamente la primera marca de la cuenta.

Resultado: matriz de destinos para cero, una y varias identidades, incluidos miembros, tutores y equipos de club.

## 3. Equipos y repetición de funciones

- Permitir varias personas con Coordinación, Secretaría u otro mismo rol en un club.
- Revisar invitación, solicitud por código, aprobación, aceptación y representación en el panel.
- Verificar también varios administradores, editores o responsables de comunicación en Marca, Federación, Profesional y Media según sus modelos actuales.
- Revisar las funciones acumuladas de una persona cuando el modelo ya las contempla; no crear cuentas ni fichas duplicadas para asignarlas.
- Conservar la asignación a una persona y entidad concretas, la expiración de invitaciones, la revocación y los permisos mínimos.
- Conceder Coordinación requiere la autoridad actual del Gestor. Repetir funciones no transfiere propiedad ni acceso a otras organizaciones.
- Mostrar quién tiene cada función y eliminar cualquier texto o representación que sugiera una sola plaza por rol.

Resultado: comprobación de cuatro coordinadores y varios secretarios en el mismo club, y varios miembros con el mismo rol administrativo en otras identidades. Verificar que cambiar una persona no revoca a las demás.

## 4. Mi Espacio como gestión de la cuenta

- Presentar identidades y clubes accesibles con nombres, imágenes y estado reconocibles.
- Añadir búsqueda por nombre y tipo, con vistas de activos, archivados y todos.
- Destacar las tareas principales: abrir espacio, gestionar identidad, crear o vincular identidad y activar servicios.
- Situar las herramientas completas de Marca y Federación dentro de sus espacios, evitando una colección de herramientas de negocio en el acceso general.
- Mantener claramente visibles ajustes de cuenta y cerrar sesión.

Resultado: selector y gestión de identidades simples, con los destinos correctos.

## 5. Personalización administrativa

- Mostrar foto o logo y banner en el espacio de gestión de cada identidad, con el nombre y tipo de entidad.
- Reutilizar la imagen pública como presentación inicial cuando corresponda y no exista personalización administrativa.
- Permitir una presentación administrativa independiente: cambiarla no cambia sin aviso el perfil público social.
- Guardar estas imágenes privadas con permisos por identidad. Validar tipo de archivo, tamaño, propiedad y acceso del equipo.
- Actualizar cabecera, logo de la barra lateral y panel tras guardar.
- Añadir un acceso separado para ver o gestionar el perfil público social.
- Conservar el aspecto LED y navegación premium también en los roles de equipo de Club.

Resultado: presentación coherente en escritorio y móvil y permisos efectivos de edición.

## 6. Inicio operativo de cada identidad

Cada espacio tendrá cabecera, resumen de actividad, acciones pendientes y áreas destacadas. Los datos procederán de consultas autorizadas; un fallo o un dato no disponible no se mostrará como cero.

| Identidad | Resumen y acciones principales |
| --- | --- |
| Club | Conservar el panel existente: socios, inscripciones, acciones pendientes, clases y ocupación, con permisos por rol. |
| Marca | Campañas activas y borradores, colaboraciones y propuestas, catálogo/tienda cuando proceda, equipo y acceso a estadísticas y finanzas. |
| Federación | Federados, solicitudes de licencias, vencimientos, clubes relacionados, equipo y actividad institucional. |
| Profesional | Servicios y experiencia, acreditaciones, clientes y sesiones cuando estén disponibles para esa especialidad y rol. |
| Organizador/promotor | Actividad profesional con foco en eventos, producción, entradas y activaciones puntuales. |
| Media/creador | Contenido, presencia pública, actividad y acceso a servicios autorizados. |
| Competidor | Identidad deportiva y herramientas actuales, sin convertirlo en un profesional automáticamente. |
| Espectador/miembro/familiar | Su navegación y funciones gratuitas o de membresía, sin conceder capacidades comerciales o de publicación no autorizadas. |

No crear cifras simuladas, nuevos derechos comerciales ni indicadores que la aplicación no pueda calcular. Los informes completos permanecen en sus herramientas especializadas.

## 7. Activación de servicios y vendedor

- Separar explorar Showcase, preparar la solicitud de vendedor, obtener verificación y tener e-commerce operativo.
- Desde Mi Espacio y Mi Marca permitir llegar al trámite para esa identidad, aunque todavía no pueda publicar o cobrar.
- Permitir preparar datos comerciales; enviar para revisión cuando se cumpla la verificación base requerida.
- Abrir Mi Showcase de la entidad seleccionada, con la navegación de tienda que ya existe para Club.
- Conservar requisitos de vendedor, políticas, Stripe y servicio comercial para venta y pagos.
- No existe vendedor gratuito. Mostrar la diferencia entre perfil público, catálogo y Commerce.
- Conservar el catálogo comercial vigente y la contratación pública nueva de Marca/Federación bloqueada durante el piloto, conforme a la decisión previa.
- Conservar activaciones puntuales de eventos, ticketing y servicios donde ya estén autorizadas.

Resultado: solicitud accesible y útil, sin permitir ventas, publicaciones o cobros por el mero hecho de abrir el panel.

## 8. Archivo y solicitud de eliminación de identidad

- Ofrecer gestión individual de la identidad, especialmente para perfiles ficticios de prueba.
- Archivo reversible en Mi Espacio: aparta la tarjeta habitual y permite encontrarla en Archivados. Explicar que no oculta el perfil público ni cancela suscripciones.
- Solicitud de eliminación: usar el procedimiento existente para esa identidad, sin solicitar por error la eliminación de toda la cuenta.
- Mostrar solicitudes pendientes y permitir cancelarlas en los estados previstos.
- Reservar archivo y solicitud de eliminación al propietario autorizado; comprobar restricciones desde servidor.
- Conservar historial comercial y obligaciones de retención aplicables. No ejecutar borrados indiscriminados o cancelaciones automáticas.

Resultado: gestionar un perfil ficticio sin afectar otros perfiles, organizaciones o servicios.

## 9. Backend y compatibilidad

- Crear migraciones versionadas antes de escribirlas, probarlas en entorno aislado y aplicar únicamente cambios revisados.
- Proteger tablas, RPC e imágenes administrativas mediante autenticación, permisos por identidad y RLS.
- Comprobar que miembros revocados, otros clubes, otros equipos y usuarios anónimos no pueden leer o modificar datos privados.
- Revisar reintentos, doble pulsación, concurrencia de solicitudes y transacciones.
- Comprobar el funcionamiento del cliente actual y documentar qué mejoras necesitan desplegar el nuevo frontend.
- No realizar despliegue de producción, push a GitHub ni publicación en Google Play como parte de esta entrega de código.

Resultado: migraciones reproducibles, permisos verificados y estado de aplicación documentado.

## 10. QA y regresión acumulativa

Pruebas obligatorias antes de declarar la entrega preparada:

1. Alta e invitación de varios coordinadores/secretarios; aceptación, aprobación y revocación independientes.
2. Varios miembros con el mismo rol en Marca, Federación, Profesional y Media.
3. Acceso con cero, una o varias identidades; cuenta frente a espacio de entidad; no redirecciones circulares.
4. Foto/logo y banner administrativos: subida válida, archivo inválido, límite, actualización y aislamiento del perfil público.
5. Resúmenes reales de Marca/Federación/Profesional, ausencia de datos, errores de consulta y permisos limitados.
6. Selección de la marca correcta cuando una cuenta gestiona varias; borrador de vendedor y bloqueo de ventas sin autorización.
7. Buscar, archivar, recuperar y solicitar eliminación de una sola identidad; rechazo de terceros no autorizados.
8. Regresión de clubes piloto, miembros, tutores con varios hijos, múltiples disciplinas/grupos, cargos manuales y varios pagos por alumno.
9. Regresión de Social/Showcase, moderación, servicios, verificación y navegación premium.
10. Pruebas visuales y de interacción en escritorio y móvil, menú lateral, foco, regreso y cierre de sesión.
11. Compilación web para Netlify; rutas e importaciones compatibles con Linux; sincronización de recursos Android.
12. Ejecutar la puerta de regresión acumulativa. Distinguir incidencias heredadas documentadas de errores nuevos; no alterar la línea base para ocultar fallos.

Diferenciar evidencia de pruebas reales en Supabase, pruebas aisladas y pruebas de navegador con datos simulados. No afirmar que se probaron cobros reales, dispositivos físicos o publicación en tiendas si no ocurrió.

## 11. Entrega acumulativa

- Generar una nueva revisión acumulativa conservando FIX13 intacto.
- Incluir código, migraciones, documentación de uso y reporte de pruebas con resultados y limitaciones.
- Preparar un ZIP dividido en cuatro fragmentos y su reunificador para Windows.
- Reconstruir el ZIP, verificar SHA-256, integridad y presencia de archivos de compilación/despliegue.
- Excluir claves privadas, credenciales, cachés y artefactos que no se hayan construido.
- Indicar qué está aplicado a Supabase, qué requiere despliegue web y qué requiere recompilar Android.
- Google Play requiere un versionCode no utilizado: conservar la referencia de base 20178 no permite reutilizar ese código en una nueva AAB.

## Criterio de cierre

Solo se marcará cada fase completada cuando exista comprobación. La entrega deberá permitir revisar los cambios y sus pruebas. No se prometerá ausencia absoluta de errores en toda la aplicación: se detallarán los recorridos probados, las incidencias pendientes y los requisitos externos.
