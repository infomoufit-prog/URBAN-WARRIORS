# Urban Warriors 1.5.2 — auditoría de integridad operativa

## Principio de esta entrega

Esta revisión deja de considerar los tests estáticos como una certificación de producción. Los tests locales validan sintaxis, contratos frontend↔RPC y construcción; la aceptación del backend se hace con `app_autotest_operativo_v152` directamente sobre el Supabase real antes de gastar otro deploy de Netlify.

## Correcciones de guardado

- Grupos y todos sus horarios se guardan mediante una sola RPC transaccional. Se validan campos incompletos, rangos horarios, solapes, disciplina, plazas y reducción de aforo.
- Alta/edición directa de alumnos corregida para el modelo multideporte/multigrupo. La matrícula se identifica por alumno + disciplina + grupo y no desactiva otras matrículas.
- Se cierran duplicados históricos de la misma matrícula antes de crear índices únicos activos.
- Graduaciones compatibles con varias matrículas de una misma disciplina.
- Publicaciones: publicación + creación de notificación se realizan en la misma transacción. Hay idempotencia para audiencia/rol y `notificada_en`.
- Imágenes de publicaciones/material: si falla el guardado en DB se borra la subida nueva; si una edición con nueva imagen se guarda, se intenta borrar la imagen sustituida.
- Material y variantes usan RPC de servidor; pedidos conservan trazabilidad y notificación.
- Check-in + asistencia son atómicos en servidor; no queda un acceso sin asistencia por un fallo RLS intermedio.
- Seguimiento y documentos pasan por RPC. Los documentos borran el objeto de Storage si falla el registro de metadatos.
- Justificantes de pago incorporan policy de borrado compensatorio si la subida se realiza pero falla la transacción de pago.
- Cobros: se bloquea sobrepago, duplicación de pago pendiente y validación que supere el saldo. Los avisos quedan detenidos solo cuando la cuota queda realmente pagada; una parcial mantiene el saldo operativo.
- Perfil propio usa RPC explícita.
- Baja de matrícula actúa sobre una sola matrícula, sin afectar otros deportes/grupos.
- Los errores de mutación aparecen dentro del formulario con el texto real devuelto por Supabase.
- Tras guardar correctamente, el formulario se cierra, se actualiza la ruta y los datos se recargan desde Supabase.

## Pruebas locales ejecutadas

- `node --check web/js/app.js`
- `node --check web/js/data-store.js`
- `node --check web/js/push.js`
- `npm test`
- `npm run build`

El conjunto incluye 40 contratos frontend↔RPC y 29 comprobaciones específicas de integridad 1.5.2, además de las suites anteriores.

## Prueba real antes de desplegar

1. Aplicar `012_operational_integrity_v152.sql` en Supabase.
2. Ejecutar `PRUEBA_REAL_BACKEND_V152.sql`.
3. No subir la 1.5.2 a GitHub/Netlify hasta que el resultado incluya `"ok": true`.

El autotest crea datos temporales y recorre: disciplina, grado, dos grupos, dos horarios, alumno, multigrupo, baja de una matrícula, graduación, sesión, check-in, asistencia, publicación y notificación, material, variante, pedido, seguimiento, preinscripción rechazada/aprobada, cuota, comunicación de pago, validación, cobro administrativo, lectura de notificación y documento. En caso de error la llamada se revierte; en caso correcto hace limpieza explícita.

## Límites que no se deben ocultar

- SQL puede verificar buckets y policies de Storage, pero la subida binaria desde el navegador se valida en la prueba final de web tras el único deploy previsto.
- Firebase Cloud Messaging real requiere las credenciales del proyecto Firebase; no se puede certificar entrega push real antes de configurarlas.
- Una APK release firmada requiere `google-services.json` y el keystore privado. Es una puerta de aceptación posterior, no una función fingida como completada.
