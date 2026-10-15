# Ayuda por capas y créditos compartidos · R274

## Implementado

- Ayuda visible en todas las cuentas; guías, saludos y tutoriales locales sin inferencia.
- Sin registro: orientación general y registro/acceso. Sin identidad: no se entregan procedimientos administrativos de otra identidad.
- Guías filtradas por identidad activa, rol, verificación y derecho de pago. Informes y preparación de automatizaciones requieren la capa Premium. El filtrado de fuentes se aplica también en servidor.
- Un competidor verificado conserva la orientación de publicación Social sin exigirle una suscripción. La guía no concede permisos de publicación: los servicios siguen validándolos.
- Ayuda con IA de pago utiliza el mismo caso MANAGEMENT, reserva, consumo y cartera de Assist/Migrations. No se han cambiado precios, asignaciones ni automatizaciones financieras.
- Detalle plegado con créditos disponibles, asignación mensual y aviso de saldo compartido del espacio. Valores obtenidos de la cartera existente.
- Cuenta gratuita: cinco respuestas IA completadas por mes natural en Europe/Madrid, compartidas entre sus identidades. Guías y fallos del proveedor no consumen ese cupo. Sin inferencia anónima.
- Reservas bloqueadas por cuenta para impedir duplicados concurrentes; reintento completado devuelve respuesta guardada. Límite global conservador de protección. No se envían historiales, archivos ni datos operativos privados al proveedor desde esta ayuda.
- Estética más despejada, respuestas completas, detalles secundarios plegados, Enter para enviar, indicador de preparación y tutorial paso a paso. Hilo conservado durante navegación; cambia de contexto al cambiar cuenta/identidad.

## Supabase aplicado

Migración local: `20261015182614_universal_help_free_quota_r274.sql`, nombre remoto `universal_help_free_quota_r274`, versión aplicada `20261015214436`. Ya está aplicada: no volver a ejecutarla ni interpretar la diferencia de fecha local/remota como una migración pendiente.

Funciones activas: `kombax-usage-help` v3 y `kombax-assist-r38` v24, ambas con verificación JWT y comprobación de sesión/autorización en el código. Reutilizan los secrets existentes, no necesitan secretos nuevos.

Tabla privada con RLS, sin lectura directa autenticada ni anónima. El cierre de consumos solo está concedido a service_role. Los resolutores públicos protegidos son SECURITY DEFINER para consultar el esquema privado; comprueban auth.uid y el ámbito solicitado. No hay concesión a anon.

## Verificación

- Regresión acumulativa: 123 comandos correctos, tres P2 heredados de traducción, cero fallos nuevos; registro `outputs/R274_RELEASE_BUILD.log`.
- Después se hicieron dos ajustes puntuales: encaje móvil y orientación Social del competidor gratuito verificado. Se repitieron las cuatro suites afectadas: 114 comprobaciones correctas (27 + 46 + 9 + 32), el control legal, build y compatibilidad.
- Build: 663 archivos idénticos entre web, dist y recursos Android. Compatibilidad: 395 JS y 964 importaciones locales Linux.
- SQL real, dentro de transacciones deshechas: cinco reservas completadas, sexta rechazada, saldo cero; club ajeno produce contexto genérico; duplicado en curso bloqueado; respuesta completada reutilizada; pregunta distinta con mismo identificador rechazada; fallo libera cupo. Sin consumos persistidos por estas pruebas.
- Proveedor de IA simulado: autenticación, cuota, reintentos, fallos, contabilidad, aislamiento de fuentes, modelo y salida limitados. No se ejecutó inferencia real facturable para esta QA.
- Navegador con datos ficticios: escritorio y móvil de 390×844, guías de cuotas, Enter, créditos plegados y ayuda inicial. Se detectó un pequeño desbordamiento horizontal y se corrigió en CSS.
- Vista del competidor: renderizador real `renderCompetitorHub`, menú real `managedNavigationHtml`, todas las hojas de estilo de la aplicación y datos de ejemplo aislados. Confirmados Social rosa, Events cian, Showcase dorado y Recursos azul. Esta prueba visual no valida una sesión ni capacidades de una cuenta real.
- Ajuste posterior solicitado al revisar la vista previa: Perfil público y productos comunes primero; herramientas propias debajo de Recursos, plegadas. Aplicado al componente compartido de identidades directas. «Explorar Showcase» abre el catálogo general; el vendedor conserva su centro de gestión por identidad. Suite de navegación ampliada: 120/120, build y compatibilidad repetidos. El lanzador de ayuda se aparta mientras se abre el menú móvil, conservando el hilo.

## Límites y pendientes

- Los tres P2 de traducción siguen abiertos; no se ha afirmado que npm test estricto pase.
- Los advisors mantienen advertencias previas sobre funciones SECURITY DEFINER y protección de contraseñas. La tabla privada nueva aparece como RLS sin política de cliente, intencionadamente sin acceso directo. No se declara el proyecto libre de advertencias.
- La ayuda explica procedimientos con fuentes; no hace pagos, publicaciones, verificaciones ni aprobaciones. Assist sigue siendo el canal de lectura operativa autorizada. No se ha creado un agente con acceso indiscriminado a la base.
- Las guías publicadas son documentación de producto, no contienen datos privados; la selección de lo mostrado por el chat se ajusta a cada capa. No son una medida de protección de datos por sí mismas.
- La propuesta de nuevo agrupamiento del menú de Club está en `PROPUESTA_MENU_CLUB_R273.md`; no se ha aplicado otra reorganización sin revisar esa propuesta.
- Sin push, commit, merge, PR, deploy de Netlify ni publicación Play. La nueva interfaz necesitará el paquete frontend actualizado. No se ha compilado APK/AAB.

## Revisión local

Aplicación real actualizada: http://127.0.0.1:4189/ (requiere sesión para una identidad real).

Vista previa visual del competidor: http://127.0.0.1:4191/__competidor (datos ficticios, sin operaciones reales).
