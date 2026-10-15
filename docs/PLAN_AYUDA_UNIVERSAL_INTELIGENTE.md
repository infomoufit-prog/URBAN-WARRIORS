# Siguiente fase: ayuda universal con selección automática de fuentes

Actualizado al cierre R274. Los resultados y límites de las pruebas están en `INFORME_AYUDA_R274.md`.

## Funcionamiento esperado

1. Una sola conversación de ayuda para todas las cuentas, sin mensajes técnicos ni botones para elegir entre guía e IA.
2. Respuestas locales para saludos, preguntas cubiertas y tutoriales. Recuperación de errores de escritura ya disponible.
3. Evaluar relevancia y ambigüedad: una coincidencia débil no basta para responder con una guía que no corresponde.
4. Si falta información, consultar IA automáticamente con fuentes de KOMBAX: guías, catálogo revisado de funciones y rutas, requisitos y capacidades. El modelo interpreta fuentes; no inventa respuestas cuando faltan.
5. Para preguntas sobre datos concretos, consultar únicamente lecturas autorizadas por el usuario, identidad y rol. No dar acceso general al contenido de la base ni a todos los clubes. Las cuentas gratuitas solo acceden a sus datos correspondientes.
6. Abrir o señalar rutas permitidas y conservar el hilo de ayuda mientras se navega. El tutorial no ejecuta acciones administrativas.
7. Si faltan datos o no se puede consultar el servicio, explicar la situación y ofrecer un siguiente paso; no prometer una respuesta factual universal.

## Presupuesto

Política aprobada e implementada: cinco consultas IA completadas al mes por cuenta gratuita, compartidas entre identidades. Este cupo es específico de ayuda y separado de las asistencias pagadas, con límite global de protección. Las cuentas de pago conservan su cartera compartida de Ayuda, Assist y Migrations y muestran su saldo mensual en un detalle plegado.

Usuarios anónimos mantienen guías locales; no se ha abierto inferencia anónima. El código de ayuda gratuita está desplegado y exige sesión, reserva y medición. La QA de inferencia se ejecutó con proveedor simulado, sin facturación real.

## Situación comprobada

El frontend incluye ayuda universal, tutorial, comprensión de erratas y selección por capas. El backend de pago es `kombax-assist-r38` v24; la ayuda gratuita usa `kombax-usage-help` v3. Ambos filtran fuentes según contexto autorizado. Ayuda no consulta datos operativos privados: esa lectura corresponde a Assist y sus permisos existentes. No se ha concedido acceso general a la base.

## Comprobaciones necesarias

- Respuesta correcta a preguntas cubiertas, ambiguas, con erratas y fuera del conocimiento disponible.
- Cuenta gratuita puede consultar solo hasta su límite de ayuda; concurrencia y reintentos no duplican consumo.
- Cuenta pagada conserva su presupuesto y autorizaciones existentes.
- Alumno/familia no obtiene datos de otra ficha o club; documentos privados no se convierten en fuentes públicas.
- Cambio de identidad revalida acceso; la IA no decide permisos.
- Fallo del proveedor y saldo agotado mantienen guías, conversación y salida comprensible.
- No ejecutar pagos, publicaciones, invitaciones o aprobaciones como efecto de una pregunta de ayuda.

La propuesta de barra lateral sigue pendiente de revisión por el usuario.
