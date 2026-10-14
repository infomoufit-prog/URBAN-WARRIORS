# R270 acumulativo · corrección Netlify y estabilización QA

Este paquete conserva el contenido del ZIP R270 original y añade las correcciones verificadas. No es un parche parcial. No se han cambiado GitHub, Netlify ni Supabase.

## Qué se corrigió

- La prueba antigua del acceso de miembros/familias ahora comprueba el flujo actual «Enviar solicitud al club», ambas opciones, revisión del club y envío al repositorio.
- La prueba de navegación Events comprueba el permiso canónico del rol seleccionado; se ejecutaron casos de administración, coordinación, secretaría, tesorería, monitor, familia y alumno.
- La prueba de archivo/eliminación de Showcase comprueba los avisos actuales y la conservación del histórico. La limpieza de imágenes continúa limitada a la eliminación definitiva confirmada por el servidor.
- Se añadieron 139 mensajes/patrones de respaldo en inglés para el texto nuevo de R270, incluidos PWA, categorías de entradas, conversaciones de Showcase y envío a Instagram.
- Los inventarios de traducción ya no interpretan selectores y fragmentos demostrables de JavaScript como textos de interfaz. No se amplió el baseline ni la excepción del release gate.
- Se añadieron pruebas de estabilización y del flujo sin código al pretest.

## Pruebas ejecutadas

- `npm run release:build`: código de salida 0.
- Release legal gate: PASS.
- 114 suites correctas, 3 incidencias P2 heredadas de traducción, 0 fallos nuevos.
- Las dos suites nuevas ejecutan 1405 comprobaciones de traducción/permisos y 5 comprobaciones del flujo sin código con repositorios simulados.
- Edge en 390 y 1280 px: 10 comprobaciones de formulario correctas; capturas revisadas; sin desbordamiento horizontal. No se enviaron solicitudes reales.
- 388 archivos JavaScript y 944 importaciones locales compatibles con nombres de archivo Linux.
- 655 archivos generados; web, dist y recursos Android idénticos.

El respaldo en inglés para idiomas no españoles sigue la política piloto ya existente en R120. No equivale a 139 traducciones nativas al francés, portugués, italiano, alemán, tailandés y filipino. La suite estricta `npm test` continúa señalando las tres incidencias antiguas; no se presenta como completamente verde. El inventario R79 queda en 275 entradas heredadas, dentro de la lista exacta autorizada anteriormente.

## Actualización manual

1. Descargar los cuatro fragmentos y UNIR_KOMBAX_R270_NETLIFY_QA.cmd en la misma carpeta.
2. Ejecutar el reunificador. Debe terminar con integridad SHA-256 correcta. No extraer cada fragmento por separado.
3. Extraer el ZIP final en una carpeta nueva. El proyecto está directamente en la raíz del ZIP: package.json, netlify.toml, scripts, web, dist, android y supabase.
4. Actualizar manualmente la carpeta del repositorio, conservando su .git y las credenciales locales. Los archivos de este paquete deben estar en la raíz del repositorio, no dentro de una segunda carpeta R270.
5. Netlify: Node 22, comando `npm run release:build`, directorio publicado `dist`. La configuración está en netlify.toml.
6. No modificar el comando para omitir las pruebas. El comando configurado ha sido probado localmente con Node v22.23.3, la misma versión que muestra el error comunicado.

## Límites de la comprobación

La compilación local y las pruebas simuladas no sustituyen el siguiente despliegue real en Netlify ni una prueba autenticada de cada operación de producción. No se ejecutaron pagos, publicaciones reales, aceptación de alumnos ni eliminación de datos de clientes.
Las cuatro funciones Meta/Instagram y sus módulos compartidos se conservan respecto a R270. No se realizó OAuth real ni publicación en Instagram en este cierre. Las verificaciones de Meta/App Review siguen siendo externas a la compilación.
No se compiló APK/AAB. Se conserva build 20178: una nueva subida a Google Play necesitará un versionCode no utilizado.

El informe, registros y capturas se incluyen en `docs/qa/r270-netlify`.
