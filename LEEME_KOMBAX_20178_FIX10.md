# KOMBAX 20178 · FIX10 acumulativo

Incluye FIX09 y corrige el formulario Owner y la actualización de tarjetas públicas Social/Showcase. No se ha hecho push, despliegue Netlify ni compilación de APK/AAB.

## Lo que se verificó realmente

- En Supabase había 9 publicaciones activas, 2 ocultas y 1 retirada; 5 productos publicados. No había publicaciones activas con bloqueo de moderación.
- Las consultas principales ya filtraban estado activo/publicado. La prueba autenticada transaccional de ambos feeds devolvió cero contenidos retirados. No se ha demostrado que el feed del servidor estuviera filtrando mal.
- La eliminación Owner funcionó sobre una publicación en una transacción de la base real; se provocó un rollback y se comprobaron los recuentos originales. No se conservó ningún borrado de prueba.
- Los registros consultados no mostraban nuevas llamadas fallidas de eliminación Owner. No permiten identificar por sí solos el motivo exacto del fallo de la APK.

## Correcciones

- Confirmación Owner normalizada: « eliminar » y «ELIMINAR» representan la misma confirmación explícita; otro texto no permite borrar. Se mantiene motivo y sesión Owner válida.
- Las fichas antiguas que quedaron marcadas como eliminadas pero conservan su fila vuelven a ofrecer «Eliminar» para completar el borrado. Los pedidos/reseñas/historial protegido siguen conservándose conforme a FIX09.
- Las listas públicas Social y Showcase añaden la exclusión expresa de bloqueos hidden/deleted, además de su filtro de estado.
- Las tarjetas abiertas se revalidan al entrar, al recuperar foco, al volver de segundo plano y cada 15 segundos con la ventana visible. Las tarjetas retiradas desaparecen de la pantalla. Se detiene la revisión al navegar; un fallo de red no elimina tarjetas por error.
- El panel de administración conserva la posibilidad de consultar contenido retirado: una lista de moderación no es el feed público.
- Se mantiene la limpieza de archivos del servidor de FIX09. No se ha realizado un borrado masivo de publicaciones.

## Activación y QA

Migración kombax_public_content_visibility_r119 aplicada a Supabase, versión 20261004124421. El backend está activo. No volver a aplicar esa migración al mismo proyecto.

Base aislada: 64 comprobaciones acumulativas de permisos, retirada, eliminación, pedidos, álbumes, referencias compartidas y visibilidad. Chrome con datos controlados: normalización y envío del formulario Owner en Social/Showcase, eliminación de tarjetas al cambiar estado, conservación durante fallo de red y cancelación al navegar; sin errores de página.

La nueva actualización de tarjetas y el formulario están en el frontend de este ZIP. Requieren desplegarlo en web; la APK instalada necesita una compilación que los incluya. No se ha probado esa APK ni se declara su fallo definitivamente resuelto. El código de Android sigue en 20178: si ya fue usado en Play, la próxima AAB debe tener un versionCode superior.

El detalle de regresión e incidencias figura en COMPROBACION_QA_FIX10.json. Persisten los P2 históricos de traducción; no se declara la suite estricta completamente limpia. El siguiente plan de perfiles y suscripciones continúa como plan, no como desarrollo completado.

## Reunir el proyecto

Coloca las cuatro partes FIX10 y UNIR_KOMBAX_20178_FIX10.cmd en la misma carpeta, ejecuta el CMD y extrae el ZIP después de su comprobación de integridad. No mezcles FIX09 y FIX10. Conserva tu .git, credenciales y firma local al revisar y trasladar cambios al checkout. El paquete no incluye claves privadas ni binarios APK/AAB.
