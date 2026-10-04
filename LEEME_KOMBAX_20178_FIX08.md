# KOMBAX 20178 · R118 · FIX08 acumulativo

Incluye FIX07 y las reparaciones posteriores. No se ha hecho push a GitHub ni despliegue Netlify ni subida de APK/AAB.

## Cambios
- «Cerrar sesión» visible en la barra lateral personal; elimina sesión y token sin depender del cambio de club.
- Finanzas y recibos nuevos toman el logo actual del perfil público del club, con respaldo al logo del club si está vacío. Los informes históricos existentes no se reescriben.
- Los generadores PDF aceptan PNG/JPEG/WebP por sus bytes reales; se limita tamaño, origen y tiempo de descarga. Orígenes adicionales requieren configurar KOMBAX_DOCUMENT_IMAGE_HOSTS en el servidor.
- Los informes Events normales y por fechas toman la identidad del organizador. Las entradas conservan su selección de logos: no se impone el logo del organizador. Se mantiene el selector existente de entidades/partners; no se ha añadido un nuevo formulario de subida de logos exclusivos para entradas.
- Mensajes del backend distinguen sesión Owner requerida y confirmación ELIMINAR. No se rebajan permisos.
- Se adjunta el plan siguiente para perfiles públicos y suscripciones. Sus fases todavía no están implementadas.

## Supabase aplicado
20261004105535 owner_delete_session_notice; 20261004114011 document_identity_logos; 20261004114421 document_range_logo.
finance-report versión 10 y kombax-report-r77 versión 4 publicados con JWT obligatorio. No vuelvas a aplicar manualmente estas migraciones al mismo proyecto.

## QA realizada y límites
- 36 comprobaciones de moderación en base aislada.
- 9 comprobaciones de identidad de logos, respaldo, aislamiento por club, permisos y conservación de snapshots.
- 20 comprobaciones en Chrome, sin errores de página, incluyendo menú móvil y limpieza de sesión/token. Son pruebas con datos controlados, no una APK instalada.
- Dos muestras creadas con los generadores PDF reales y logo WebP; renderizadas e inspeccionadas visualmente.
- Comprobación Deno de ambos generadores completada.
- No se crearon eventos ni recibos reales: clubes 3 y eventos 3 conservados en el servidor.
- Falta verificar generación PDF autenticada completa en el servidor con datos reales; el empaquetado de WASM en el entorno remoto no se da por probado mediante la prueba local.
- El usuario confirma que Retirar funciona en su APK. Eliminar permanece pendiente; no se declara corregido en la APK.
- No se generaron APK/AAB nuevas. Si Play ya ha usado 20178, la próxima AAB necesita un versionCode superior; no reutilices ese código para otra subida.
- Se conservan los tres P2 de traducciones previamente documentados. La comprobación estricta completa no se declara sin incidencias.

- Regresión acumulativa: 78 suites aprobadas, 3 P2 conocidos y 0 fallos nuevos. Compatibilidad Linux: 364 JavaScript y 855 imports; web/dist/Android idénticos.

## Uso del paquete
Coloca las cuatro partes .001 a .004 y UNIR_KOMBAX_20178_FIX08.cmd en una carpeta y ejecuta el archivo CMD. Comprueba la integridad, extrae el ZIP y revisa los cambios antes de reemplazar archivos en tu checkout. Conserva su carpeta .git y tus configuraciones privadas. El paquete excluye credenciales y archivos de firma. El cierre de sesión requiere actualizar el frontend; para la APK, compilar e instalar una versión que incluya estos archivos.
