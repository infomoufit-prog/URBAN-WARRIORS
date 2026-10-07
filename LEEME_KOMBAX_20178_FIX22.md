# FIX22 acumulativo para despliegue manual en Netlify

7 de octubre de 2026. Conserva FIX21 y todo el proyecto; incorpora la migración posterior competitor_pilot_showcase_capacity_fix21 y los informes actuales de Supabase. No incluye APK/AAB compiladas ni cambia el código Android 20178.

## Clubes piloto comprobados

Urban Warriors, Sant Pedro urban warrios y Doragon Santa Coloma: alta piloto activa y plan efectivo premium. Se comprobaron las funciones reales de permisos de Events y de gestión/capacidad de Showcase como administrador de cada club. Seis comprobaciones correctas, en una transacción revertida.

El catálogo vigente concede 2 publicaciones de Events al mes y 25 elementos activos en Showcase. Los requisitos de organización, contratos del evento, revisión de productos, autorización de vendedor y Stripe no desaparecen. No se publicaron eventos/productos ni se hicieron cobros de prueba. La tienda se prepara al acceder a Mi Showcase con los permisos del club.

## Cambios acumulativos y backend

Instagram permanece habilitado en el frontend de FIX21. Las cuatro Edge Functions están desplegadas y las URLs Meta guardadas, según el informe anterior. Conexión OAuth real y publicación externa siguen pendientes; la app Meta en desarrollo condiciona las cuentas autorizables. El competidor existente necesita aceptar las condiciones vigentes antes de conectar Instagram.

Antigüedad e históricos: migración member_seniority_historical_finance_fix20 aplicada, versión real 20261007205827. Registro manual de cargos pendientes y pagos ya realizados, sin iniciar cobros externos. Seis comprobaciones en Supabase y 29 aisladas correctas.

Competidores piloto: las cinco plazas autorizadas obtienen 15 publicaciones activas de catálogo Showcase. Se aplicó competitor_pilot_showcase_capacity_fix21; siete pruebas reales revertidas correctas. No autoriza ventas ni cobros sin los requisitos existentes. Cinco plazas disponibles tras las pruebas.

Se conservan archivo, permisos, equipos, altas, perfiles, navegación y recursos de FIX21. Los cambios posteriores son SQL e informes; no hay cambios nuevos de interfaz. Evidencias en docs/qa/CLUBES_PREMIUM_FIX22.json y los informes de activación.

## Actualización

1. Descargar las cuatro partes FIX22, el reunificador CMD y SHA256. Ponerlos en la misma carpeta, ejecutar el CMD y extraer el ZIP generado.
2. Usar el contenido de la carpeta KOMBAX_20178_R120_FIX22 como raíz del proyecto al actualizar manualmente GitHub; package.json y netlify.toml deben quedar en la raíz, sin otra carpeta anidada.
3. Netlify: comando npm run release:build, directorio publicado dist, Node 22. Conservar las variables y configuración privadas ya existentes. No subir credenciales, .env reales ni firmas Android.
4. Las migraciones anteriores ya están aplicadas en Supabase. No ejecutar db push masivo: las versiones reales de algunas migraciones aplicadas por conector difieren del nombre local. Este paquete conserva la fuente para trazabilidad.
5. Tras el despliegue, probar como administrador la entrada a Mi Club, Events y Mi Showcase. Conectar Instagram desde https://kombax.es con cuenta profesional autorizada por Meta. No se publicó contenido real en Instagram.

FIX21 permanece intacto. No se hizo commit, push, merge, PR ni despliegue Netlify. Para una futura AAB se necesitará un versionCode no utilizado.

## QA

El resultado de la compilación actual se recoge en docs/qa/BUILD_FIX22.log. Se conserva la línea base de 109 pruebas correctas, 3 incidencias P2 conocidas de traducción y cero fallos nuevos; no se ocultan las incidencias conocidas. Las pruebas de navegador anteriores son aisladas con transporte simulado; no equivalen a subida binaria real u OAuth real.
