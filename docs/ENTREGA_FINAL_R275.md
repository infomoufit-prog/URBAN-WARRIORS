# R275 acumulativo: conversación natural en Ayuda KOMBAX

## Resultado

La ayuda interpreta primero la consulta. Con autorización y saldo, consulta la IA antes de mostrar una guía, incluso cuando hay una coincidencia directa en el catálogo. «Qué es» explica el concepto; «para qué sirve» explica su utilidad; «cómo hacerlo» solicita el procedimiento. La guía queda como referencia opcional y su apertura no hace otra llamada a IA. Saludos y consultas locales de respaldo no consumen IA.

Se conserva un hilo reciente limitado a cuatro mensajes de hasta 600 caracteres para interpretar seguimientos. Al cambiar de cuenta o identidad se reinicia; al navegar dentro del mismo espacio o cerrar y abrir el panel se conserva. No es memoria entre dispositivos ni una consulta a datos privados del club. Los mensajes del hilo no otorgan permisos.

Se ampliaron quince guías con conceptos y utilidad. La IA usa fuentes filtradas por la identidad, capa y rol autorizados. No puede ejecutar pagos, publicar, aprobar solicitudes ni modificar datos desde esta ayuda.

## Backend desplegado y leído de vuelta

Proyecto Supabase: poggsobhtutbuagjiydc.

- kombax-usage-help: versión 4, ACTIVE, JWT obligatorio.
- kombax-assist-r38: versión 25, ACTIVE, JWT obligatorio.
- Los cinco archivos de cada función se compararon literalmente con el paquete local: idénticos.
- Sin nueva migración ni nuevos secrets. Se conserva el modelo y la contabilidad vigentes.
- Cuentas gratuitas: cinco respuestas de IA completadas al mes por cuenta, compartidas entre sus identidades. Cuentas de pago: permisos, casos y saldo compartido con Assist/Migrations existentes. La prioridad de IA aumenta la frecuencia de uso frente a la versión que respondía primero con una guía, dentro de esos límites.

La migración R274 ya aplicada sigue incluida como histórico. Su versión remota es 20261015214436, aunque el archivo local tiene prefijo 20261015182614. No volver a aplicar automáticamente todas las migraciones históricas.

## Pruebas ejecutadas

- Gate de release: 125 comandos correctos, tres P2 conocidos de traducción, cero fallos nuevos.
- Suite específica R275: 18 comprobaciones correctas.
- Handler de ayuda: 34 comprobaciones correctas con proveedor simulado.
- Ayuda universal R274: 27 comprobaciones correctas.
- Navegación/ayuda R272: 46 comprobaciones correctas; conversación R273: nueve correctas. Estas suites están incluidas en los 125 comandos, no son comandos adicionales.
- Compilación: 663 archivos; web, dist y recursos Android idénticos. Compatibilidad: 395 archivos JavaScript, 964 importaciones locales verificadas para Linux.
- Navegador local con componentes reales y datos/proveedor simulados: definición sin lista de pasos, IA prioritaria aun habiendo guía, seguimiento «¿y eso para qué sirve?» con hilo, apertura de guía sin otra llamada, conservación al navegar, ausencia de saldo, alta sin sesión y respaldo local cuando falla el proveedor. No hubo llamadas externas en esa prueba.
- No se ejecutó una inferencia real con una cuenta del usuario. La naturalidad final del modelo en producción debe revisarse con una consulta real después de actualizar el frontend; las pruebas simuladas validan el flujo y el contrato, no garantizan el texto concreto que genere el modelo.

El gate conserva explícitamente los tres P2 heredados: i18n-r79-full-product-audit.mjs, test-kombax-20130-r79-i18n-phases-6-10.mjs e i18n-runtime-copy-audit.mjs. npm test estricto sigue fallando por ellos; no se ocultan ni se declaran resueltos.

## Advisors y límites de la revisión

Los advisors consultados muestran avisos a revisar; R275 no cambia esquema ni permisos de base de datos. No se afirma que el proyecto esté libre de hallazgos ni que se haya hecho una auditoría global nueva:

- Seguridad: RLS sin políticas (239 INFO), funciones SECURITY DEFINER ejecutables por anon (61 WARN) y authenticated (660 WARN), protección de contraseñas filtradas desactivada (1 WARN).
- Rendimiento: claves foráneas sin índice (259 INFO), índices sin uso (297 INFO), índice duplicado (1 WARN).
- Algunas tablas privadas usan deliberadamente RLS sin políticas y acceso por funciones controladas; cada hallazgo necesita revisión individual. No se abrieron permisos para silenciar avisos.
- Referencias: https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable y https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection .
- No se provocó una consulta real al modelo para obtener logs de inferencia; ACTIVE y la lectura de código no equivalen a una prueba real de respuesta.

## Archivos principales

- web/js/ui/usage-help.js: IA prioritaria, intención, hilo reciente y referencia opcional.
- web/js/core/usage-help-knowledge.js: intención, contexto de seguimiento y filtrado del hilo.
- web/js/core/repositories.js: transporte del hilo solo para especialidad usage.
- web/assets/guides/usage-help-r272.json: conceptos y utilidad.
- web/js/i18n/r272-usage-copy.js: copia nueva y equivalentes ingleses; otras lenguas mantienen su mecanismo de fallback.
- supabase/functions/_shared/usage-help-{guide.ts,knowledge.js,catalog.json}.
- supabase/functions/kombax-usage-help/index.ts y kombax-assist-r38/index.ts.
- scripts/test-natural-help-r275.mjs, pruebas de handler/universal y package.json.
- dist y android/app/src/main/assets/www sincronizados.

## Actualización manual

No se ha hecho commit, push, merge, PR, deploy de Netlify ni publicación de contenido. El backend ya está actualizado. Para obtener IA prioritaria, historial y los nuevos controles, hay que actualizar el frontend con este paquete. El frontend anterior sigue conservando su elección anterior de guía primero.

El ZIP es completo y acumulativo sobre R274, que se conserva intacto. Incluye el proyecto Android y los recursos web; no se ha compilado APK ni AAB. Una nueva AAB necesitará un código de versión no usado.

La entrega incluye cuatro fragmentos, reunificador CMD y SHA-256. La reunificación real y la integridad CRC de todos los archivos se comprueban antes de entregar.

Referencia de diseño para contexto conversacional y almacenamiento: https://developers.openai.com/api/docs/guides/conversation-state . Se transmite un hilo acotado como contexto; no se promete persistencia remota de conversaciones.
