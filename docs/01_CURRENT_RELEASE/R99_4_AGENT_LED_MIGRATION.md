# R99.4 · KOMBAX Migrations: incorporación dirigida por el agente

## Recorrido del usuario

1. En Mi Club, abre KOMBAX Migrations, inicia o continúa un caso y sube CSV, Excel, PDF o imágenes.
2. El agente analiza los archivos, identifica alumnos, cuotas y pagos, y muestra las fichas detectadas en el mismo caso. Los lotes pendientes se analizan tras la carga; se puede añadir más documentación al caso.
3. La pantalla plantea preguntas concretas cuando falta un dato necesario, por ejemplo disciplina, grupo y horario del alumno, relación entre cuota y alumno, o importe del pago. Las respuestas inequívocas dadas en el chat se aplican a la ficha correspondiente. También se indican campos opcionales que conviene completar o verificar después.
4. El usuario revisa las fichas y pulsa «Sí, incorporar estos datos». Un diálogo final detalla cuántos alumnos, cuotas y pagos se incorporarán. Solo el botón «Sí, incorporar» de ese diálogo ejecuta la operación.
5. El resultado indica creados y duplicados omitidos, y ofrece accesos a Alumnos y Finanzas para verificar. Los alumnos quedan en prealta, las cuotas pendientes con avisos pausados y los pagos pendientes de validación humana.

## Protección y límites

- El agente no incorpora nada por un mensaje de chat, aunque el usuario escriba «sí» en él. Se exige el diálogo visible de confirmación.
- No se inventan los datos pendientes. El usuario puede completar un campo en la ficha o responder en el chat; las correcciones inequívocas se vinculan por la referencia de origen.
- Las correcciones de la vista previa se conservan durante la sesión del navegador. Conviene terminar o verificar la migración antes de cerrar esa sesión.
- La incorporación directa actual está habilitada en Club para usuarios con permisos de gestión. En Federación y Marca se mantiene el análisis y la revisión humana; no se presenta como incorporada una ficha que no ha entrado en el sistema.
- Máximo de 200 filas seleccionadas por operación. Los documentos mantienen sus límites existentes por archivo y plan.
- La base de datos comprueba la pertenencia del caso, el rol, las referencias de origen, los campos obligatorios y duplicados. La solicitud usa un identificador único para evitar repeticiones involuntarias.

## Verificación de esta versión

- Caso sintético MOUFIT `KMX-2026-473488`: 6 alumnos, 2 cuotas y 1 pago detectados. Se mostró una pregunta por el grupo de Carla Prueba.
- El agente recibió la respuesta «Muay Thai adultos grupo tarde», la aplicó a la ficha correcta y habilitó el paso de autorización. No incorporó datos al responder por chat.
- Se abrió el diálogo final con el recuento 6/2/1 y se canceló, sin ejecutar una nueva incorporación.
- Una corrección manual del grupo se conservó al recargar y reabrir el caso en la misma sesión del navegador.
- La función `kombax-assist-r38` versión 13 quedó activa con la respuesta estructurada `field_updates`.
