# Plan de perfiles públicos y suscripciones · siguiente intervención

Fecha: 4 de octubre de 2026. Este documento es un plan; no afirma que sus fases estén implementadas.

## Objetivo
Una cuenta accede a exploración y Mi Espacio. Una persona conserva un perfil social público con varias capacidades verificables. Club, federación y marca representan organizaciones independientes, con sus propios logos, fotografías, publicaciones, permisos y servicios.

## Evidencia del código actual
- `core/personal-space.js` reúne capacidades personales y excluye organizaciones.
- `modules/gateway.js` ya presenta un perfil personal canónico, capacidades personales, clubes y organizaciones en secciones distintas.
- La navegación «organizaciones» actualmente apunta a la sección de clubes; se debe corregir para incluir club, federación y marca de forma consistente.
- `modules/organization-billing.js` ya abre cada suscripción mediante subject_type + subject_id; sus tarjetas muestran plan y estado, pero falta el nombre de la entidad.
- El listado del backend usa actor_id; la siguiente fase debe distinguir quién paga de quién puede administrar cada organización, sin ampliar permisos por compartir una cuenta o un plan.
- «Cerrar sesión» se ha añadido al menú personal en FIX08. Tiene comprobación de navegador móvil y limpia sesión/token incluso desde un contexto club.

## Fases de implementación
1. Auditar y conservar la identidad personal canónica: miembro, competidor, profesional y espectador no deben generar copias del mismo perfil social. Verificar continuidad de publicaciones, red, álbumes y verificaciones. No fusionar registros automáticamente si representan personas diferentes.
2. Unificar el acceso «Mis organizaciones»: distinguir organizaciones que gestiono de clubes a los que pertenezco. Cada organización tendrá «Ver perfil público», «Gestionar» y «Servicios». Conservar su identidad, fotografías y publicaciones independientes.
3. Crear un selector sencillo de contexto: «Mi perfil personal» y organizaciones autorizadas. Mostrar quién publica o vende antes de enviar contenido. El selector cambia el contexto, no la cuenta autenticada ni la propiedad del contenido.
4. Presentar «Mis servicios y suscripciones»: agrupar por nombre y tipo de entidad. Mostrar plan, estado, fin de prueba, renovación y gestión de pago. Mantener independientes suscripciones de club, federación y marca; contratar una no debe activar otra.
5. Conservar servicios puntuales: eventos/ticketing para organizadores verificados y venta Showcase para vendedores autorizados, sin exigir un plan de club. Una inscripción o compra es una operación distinta de una suscripción SaaS; no crear nuevas modalidades ni precios sin catálogo definido.
6. Aplicar los permisos en servidor: propiedad, equipos autorizados, identidad verificada, condición de vendedor y suscripción vigente. Prueba de 30 días con verificación y consentimiento de renovación mediante Stripe, según catálogo existente. Mantener separado el acceso de los cuatro clubes piloto, sus plazas y sus beneficios autorizados.
7. QA: cuenta sin perfil, perfil personal con varias capacidades, club + federación + marca, miembro de otro club, gestor sin propiedad, pagos fallidos, cancelación de un solo plan, cuenta sin suscripción y cierre de sesión. Comprobar aislamiento de contenido y permisos. Usar Stripe de prueba sin cobros reales.

## Criterio de aceptación
Una persona no aparece duplicada por sus capacidades; las organizaciones sí conservan perfiles públicos distintos. Siempre se identifica la entidad activa y a cuál pertenece cada suscripción. Ningún cambio de contexto concede permisos adicionales. El piloto y las publicaciones previas se conservan.

## Moderación pendiente
El usuario confirma que «Retirar» funciona en la APK y acepta ese proceso provisional. «Eliminar» no funciona en su APK y no se considera resuelto. El backend se probó transaccionalmente con sesión Owner válida, sin conservar cambios; falta reproducir y validar el recorrido de esa APK.
