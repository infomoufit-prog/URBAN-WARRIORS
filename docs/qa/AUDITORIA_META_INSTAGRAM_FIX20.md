# FIX20 acumulativo — Meta/Instagram y antigüedad financiera

Fecha: 7 de octubre de 2026. Implementación local. Ninguna migración aplicada, función desplegada, publicación real, commit, push, merge ni PR realizados en FIX20. FIX19 se conserva intacto.

## Arquitectura y alcance
La web sigue siendo estática. El backend nuevo utiliza exclusivamente Supabase Edge Functions. No se han creado Netlify Functions. Supabase Auth autentica al usuario; la identidad social seleccionada determina conexión y permisos. Cada conexión requiere un propietario/administrador autorizado. Las credenciales no se entregan al navegador.

Se implementan OAuth con Facebook Login for Business, selección explícita de página/cuenta profesional, conexión y desconexión por identidad, comprobación de conexión, publicación de una imagen JPEG y texto desde un post público autorizado de KOMBAX, desautorización y eliminación de datos de la integración. Reels, carruseles, historias y publicación automática a otras redes quedan fuera de esta entrega.

## Archivos Meta añadidos
- supabase/migrations/20261007190030_kombax_meta_instagram_fix20.sql
- supabase/functions/_shared/meta-instagram-core.js
- supabase/functions/_shared/meta-instagram-runtime.js
- supabase/functions/meta-instagram/index.ts
- supabase/functions/meta-instagram-callback/index.ts
- supabase/functions/meta-instagram-deauthorize/index.ts
- supabase/functions/meta-instagram-data-deletion/index.ts
- supabase/meta-instagram.env.example
- web/js/modules/instagram-integration.js
- web/js/meta-instagram-return.js
- web/meta-instagram.html
- web/js/i18n/meta-instagram-copy.js
- scripts/test-meta-instagram-fix20.mjs
- scripts/test-meta-instagram-runtime-fix20.mjs
- scripts/test-meta-instagram-db-fix20.mjs
- scripts/test-meta-instagram-browser-fix20.cjs
- docs/qa/PLAN_META_INSTAGRAM_FIX20.md

Modificados: supabase/config.toml, web/config.js, web/js/modules/kombax-social.js, web/js/i18n/legacy-runtime.js y package.json. Las copias generadas en dist y android/app/src/main/assets/www se sincronizan mediante build.

## Almacenamiento y permisos
El esquema privado kombax_meta contiene conexiones, credenciales, flujos, publicaciones, auditoría y confirmaciones de eliminación. RLS habilitado y permisos directos retirados. RPC interna reservada al servicio; la RPC de contexto exige usuario, condiciones aceptadas y autorización persistida para la entidad. Tokens y códigos transitorios cifrados AES-GCM con vinculación a entidad/flujo. Estado OAuth aleatorio, caducidad de diez minutos, prueba de navegador, vinculación al usuario y consumo único. No se usan user_metadata para conceder permisos.

La publicación consulta de nuevo los permisos y el contenido antes del envío final. No acepta una URL arbitraria del cliente. Ante resultado incierto no repite automáticamente el envío. Desconectar una identidad no revoca las conexiones de otras identidades. La eliminación solicitada desde Meta borra datos de esta integración; no borra cuentas KOMBAX ni historial financiero/legal.

## Funciones y URLs exactas
Rutas implementadas, TODAVÍA NO DESPLEGADAS:

| Uso en Meta | Edge Function | URL |
|---|---|---|
| Valid OAuth Redirect URI | meta-instagram-callback | https://poggsobhtutbuagjiydc.supabase.co/functions/v1/meta-instagram-callback |
| Deauthorize Callback URL | meta-instagram-deauthorize | https://poggsobhtutbuagjiydc.supabase.co/functions/v1/meta-instagram-deauthorize |
| Data Deletion Request URL | meta-instagram-data-deletion | https://poggsobhtutbuagjiydc.supabase.co/functions/v1/meta-instagram-data-deletion |

La cuarta función es meta-instagram: operaciones autenticadas de conexión, estado, verificación, selección, publicación y desconexión. Las tres URLs coinciden literalmente con las carpetas y config.toml. No deben confundirse con proveedores OAuth de Supabase Auth ni con URLs de Netlify. Sin barra final añadida.

## Variables y secretos requeridos (sin valores)
Introducir manualmente en Supabase cuando se autorice el despliegue:
- META_APP_ID
- META_LOGIN_CONFIG_ID
- META_APP_SECRET
- META_GRAPH_API_VERSION
- META_TOKEN_ENCRYPTION_KEY (32 bytes aleatorios codificados como 64 caracteres hexadecimales; conservar para descifrar)
- KOMBAX_APP_URL (origen HTTPS exacto de la web, sin ruta)

El runtime utiliza SUPABASE_URL y las claves suministradas por Supabase: SUPABASE_PUBLISHABLE_KEYS y SUPABASE_SECRET_KEYS; admite los nombres legacy SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY. Nunca introducir la clave de servicio en frontend. Los identificadores públicos facilitados por el usuario se configurarán manualmente; no se ha comprobado su configuración mediante una conexión real a Meta. El ejemplo de variables no contiene valores reales.

## Pruebas y límites
- 23 pruebas unitarias Meta con Graph/RPC simulados: correctas.
- 8 comprobaciones del transporte Supabase simulado: API keys nuevas en apikey, JWT del usuario conservado y compatibilidad con service_role legacy. Correctas.
- 28 comprobaciones PostgreSQL aisladas de la migración Meta: correctas. Las dependencias de permisos Social y condiciones son fixtures; no equivalen a pruebas en Supabase de producción.
- 32 comprobaciones de navegador Meta en móvil/escritorio con transportes simulados: correctas.
- Comprobación Deno de las cuatro entradas Edge Function: correcta. El núcleo JS se ejecuta en los tests; no se afirma tipado estricto completo del núcleo.
- Resultado final: 109 PASS, tres P2 heredados de traducción y cero fallos nuevos. Build de 648 archivos, 381 JavaScript y 926 importaciones locales verificadas para Linux; web/dist/Android idénticos. Legal gate correcto. Ver BUILD_FIX20.log y resultados adjuntos. No se altera la lista de excepciones para esconder incidencias.
- No hay ensayo real de OAuth, permisos avanzados, descarga de imagen por Meta, publicación o renovación/caducidad de un token real.
- No hay APK/AAB compilada. Los recursos web Android se sincronizan. Una AAB posterior necesita un versionCode no utilizado.

## Riesgos operativos
La conexión no podrá activarse hasta desplegar migración/funciones y configurar secretos y URLs. El frontend mantiene integrations.instagram.enabled=false hasta esa activación. Los flujos caducados se limpian en nueva actividad OAuth; no se ha instalado cron de limpieza. Una publicación atascada tras un fallo o de resultado incierto requiere revisión; no se repite automáticamente. Reconectar otra cuenta conserva el historial y la protección contra volver a enviar el mismo post. La autorización inicial debe hacerse en la web autenticada: la sesión de Android no se transfiere al navegador externo. Las imágenes deben cumplir JPEG, tamaño y proporción admitidos. Las traducciones nuevas usan español e inglés de respaldo; traducción nativa a los otros idiomas pendiente según política piloto existente.

## Pasos manuales posteriores
1. Guardar copia de seguridad y revisar migraciones pendientes del proyecto existente. No ejecutar indiscriminadamente todas las migraciones históricas sobre una base ya actualizada.
2. Aplicar las dos migraciones nuevas FIX20 en orden y comprobar permisos/funciones. No se han aplicado durante esta entrega.
3. Configurar los secretos en Supabase mediante un canal seguro.
4. Desplegar meta-instagram, meta-instagram-callback, meta-instagram-deauthorize y meta-instagram-data-deletion con el config.toml entregado. La función de control exige JWT; los callbacks públicos validan estado o firma según corresponda.
5. En Meta for Developers registrar las tres URLs de esta tabla en Facebook Login for Business y los apartados de desautorización/eliminación de datos. Comprobar dominios, sitio web y política de privacidad. Conservar los cinco permisos previstos: business_management, instagram_basic, instagram_content_publish, pages_read_engagement, pages_show_list.
6. Probar con una cuenta autorizada en roles de la app Meta, profesional y vinculada a una página. Seleccionar explícitamente la cuenta, verificar estado y autorizar una imagen de prueba. Ninguna publicación se ha hecho durante esta implementación.
7. Verificar revocación, reconexión, solicitudes firmadas de borrado y ausencia de secretos en frontend/logs con la configuración real.
8. Habilitar el flag frontend solo tras las comprobaciones. El usuario actualizará manualmente GitHub y desplegará Netlify; este paquete no modifica el remoto.

## App Review / Advanced Access
Los permisos añadidos en el panel no acreditan por sí solos acceso avanzado aprobado. Antes de abrir a terceros hay que comprobar en Meta el nivel de acceso de cada permiso, los requisitos de verificación del negocio que indique el panel, URLs legales públicas, instrucciones de prueba, cuentas de prueba y una grabación del flujo completo y uso de permisos. Solicitar solamente permisos realmente usados. La aprobación corresponde a Meta y no está garantizada ni solicitada por este trabajo. Revisar la documentación oficial vigente al realizar la solicitud.

Referencias técnicas: https://www.postman.com/meta/instagram/folder/u4g5a2a/instagram-api-with-facebook-login y https://supabase.com/docs/guides/database/postgres/row-level-security.

## Reproducir QA aislada
Los ensayos PostgreSQL se ejecutaron con PGlite 0.3.14 instalado fuera del producto. Para repetirlos, instalar esa versión en un entorno QA y apuntar KOMBAX_PGLITE_PATH a su dist/index.js. Los scripts de navegador admiten KOMBAX_PLAYWRIGHT_PATH y KOMBAX_BROWSER_PATH. No requieren una sesión Meta real.

Referencia de compatibilidad de claves: https://supabase.com/docs/guides/getting-started/api-keys.
