# R280 · 17 de octubre de 2026

## Incidencia Netlify corregida

El test de fuentes de R278 guardaba SHA-256 de bytes sin normalizar. `dashboard-catalog.js` tenía 82 secuencias CRLF. La huella coincidía en Windows y dejaba de coincidir con los mismos contenidos al pasar a LF, reproduciendo la clase de fallo del registro de Netlify.

Los generadores y el test usan ahora la misma normalización limitada CRLF → LF. No se recortan espacios, no se ignoran cambios de código y no se elimina la comprobación. Se generaron de nuevo las huellas de documentación e inventarios.

Prueba aislada en copias con formato LF y CRLF: 1.302 comprobaciones correctas en ambas. La copia con contenido modificado en dashboard-catalog fue rechazada expresamente. Es una simulación de formatos de checkout en Windows, no una ejecución de Netlify ni de un sistema operativo Linux real.

## Mejoras solo de backend

- Seguimiento de preguntas cortas: «y después», «ya lo hice», «dónde está» y «no veo el botón».
- Cambio explícito de tema sin quedar atrapado en la tarea anterior.
- Sinónimos para mensualidades, abonos parciales, escaparate, matrículas y cinturones, entre otros.
- Recuperación de temas distintos antes de repetir variantes de una misma guía; contexto limitado a 7.000 caracteres y los permisos heredados intactos.
- Ayuda diferencia un diagnóstico posible de una causa confirmada y no asegura haber inspeccionado una cuenta o navegado por pantallas.
- Assist prioriza el dato disponible y distingue información ausente de un cero. No cambia de entidad ni ejecuta acciones por una referencia del usuario.
- Migrations mantiene el JSON, las referencias de filas y la confirmación de importación. Solicita conjuntamente los datos esenciales que falten y no vuelve a pedir los datos conocidos.

Se mantienen los modelos, la contabilidad de consumo, las cuotas vigentes, idempotencia, permisos y la desactivación de almacenamiento de conversaciones por el proveedor. No se ha habilitado aprendizaje automático sin revisión de fuentes.

Supabase: `kombax-assist-r38` versión 35 y `kombax-usage-help` versión 12 activas, con JWT, y sus nueve archivos por función comprobados mediante lectura posterior. Assist y Migrations comparten la primera función. Owner no se ha modificado en R280.

## Verificación

- Cadena de entrega: 134 grupos correctos, tres incidencias de traducción conocidas, cero fallos nuevos.
- Compatibilidad: 398 archivos JavaScript, 968 importaciones locales; web/dist/Android idénticos.
- Frontend: los 2.001 archivos de web, dist y recursos Android conservan exactamente los bytes de R279.
- 26 comprobaciones nuevas de diálogo de backend; regresiones existentes de autorización, aislamiento, cuotas, reintentos y contratos de agentes correctas.
- Pruebas de controladores con proveedor simulado. No se ha realizado una nueva inferencia autenticada real en este pase ni se afirma que todas las respuestas del modelo estén verificadas.
- La consulta agregada de logs tras el despliegue no devolvió eventos coincidentes; no demuestra una conversación real ni una validación de inferencia.
- Sin cambios de esquema, RLS, credenciales, tarifas o configuración de proveedores.

Persisten los límites documentados de R278: las tres incidencias de traducción y la comprobación pendiente de un nuevo PDF real de marketing con sesión Owner válida. No se ha publicado contenido, ejecutado cobros ni aprobado usuarios reales.

## Entrega

Acumulativo completo sobre R279 conservado. No se ha actualizado GitHub ni desplegado Netlify. Para corregir el despliegue fallido deben actualizarse los scripts y artefactos incluidos y reintentarse manualmente. Las mejoras de agentes ya están activas en Supabase y no exigen modificar la interfaz.

ZIP final: `KOMBAX_R280_BACKEND_Y_NETLIFY_ACUMULATIVO.zip`. Cuatro fragmentos descargables y reunificador con prueba real de reconstrucción, SHA-256 y CRC.
