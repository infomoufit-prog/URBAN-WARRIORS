# KOMBAX 20177 R118 · base congelable · corrección 01

Base descargada de GitHub: infomoufit-prog/URBAN-WARRIORS, rama main, commit 7dd7c7ed39df13bb67880685c7c2df875b43f267. El repositorio contenía build 20177; no había una base 20178 en main. Se mantiene 20177 y la versión 2.0.0-rc.13-r118-pilot-stabilization-1. Esta entrega incorpora las correcciones descritas aquí sobre esa base.

No se ha hecho push, publicación en Netlify, actualización de Supabase ni aprobación de documentos reales. La compilación local con Netlify CLI ha pasado. La activación de Owner requiere los pasos de Supabase de esta guía.

## 1. Reunir las cuatro partes en el escritorio

1. Descarga los cuatro archivos .zip.001, .zip.002, .zip.003 y .zip.004 y UNIR_KOMBAX_20177.cmd en la misma carpeta del escritorio. Conserva sus nombres.
2. Haz doble clic en UNIR_KOMBAX_20177.cmd. Creará KOMBAX_20177_R118_FIX01.zip y comprobará su SHA-256.
3. Cuando confirme la integridad, extrae el ZIP completo. Las partes no son cuatro ZIP independientes y no deben descomprimirse por separado.
4. Dentro encontrarás KOMBAX_20177_R118_FIX01, con el proyecto completo. No incluye .git, dependencias instaladas ni claves privadas.

## 2. Preparar tu carpeta local de GitHub

Haz una copia de seguridad de tu carpeta actual. Conserva su .git, android/app/google-services.json, android/keystore.properties, tu archivo de firma .jks/.keystore y cualquier configuración privada local. Copia el contenido del proyecto extraído en tu carpeta de trabajo de GitHub. Conserva .git para mantener el remoto origin y el historial. Retira el antiguo pnpm-lock.yaml si permanece: esta base utiliza package-lock.json y npm.

Instala Node 22 con npm 10. Desde la raíz del proyecto ejecuta KOMBAX_20177_VERIFY_LOCAL.cmd. Realiza una instalación limpia y comprueba la compilación. No publica nada.

## 3. Activar Owner en Supabase, una sola vez

El proyecto que he comprobado es poggsobhtutbuagjiydc, el mismo que aparece en web/config.js. Había un Owner activo, almacenamiento privado correcto y una función de agentes activa. Faltaba la función de alertas R114 y sus disparadores; las credenciales profesionales tenían dos textos SQL tratados erróneamente como nombres de columna. La función activa del agente tenía correcciones posteriores al archivo de GitHub: se han conservado su autenticación interna, sus informes y su salida de respaldo ante fallos del modelo.

El push de Netlify no actualiza Supabase. Sigue este orden:

1. En el editor SQL del proyecto Supabase, revisa y ejecuta únicamente supabase/migrations/20261003183352_owner_verification_flow_r118_fix.sql. La reparación es transaccional y conserva las solicitudes y documentos. No ejecutes todas las migraciones históricas ni uses db push indiscriminadamente sobre esta instalación activa.
2. Publica manualmente estas dos funciones desde la raíz del proyecto, con tu sesión de Supabase CLI:

   npx supabase functions deploy kombax-owner-agents-r105 --project-ref poggsobhtutbuagjiydc
   npx supabase functions deploy kombax-owner-verification-worker-r118 --project-ref poggsobhtutbuagjiydc --no-verify-jwt

   El agente conserva validación de usuario/JWT. El proceso privado valida x-uw-cron-secret mediante el mismo mecanismo que notification-dispatch. No es una función abierta a aprobaciones anónimas.
3. Comprueba en los secretos de las funciones que OPENAI_API_KEY y UW_CRON_SECRET estén configurados. UW_CRON_SECRET debe coincidir con el secreto privado uw_cron_secret de Vault. Se reutiliza la configuración existente; no pongas valores de secretos en archivos o en GitHub. La función privada usa la clave service role provista por Supabase.
4. En el editor SQL ejecuta supabase/maintenance/owner-verification-enable-r118.sql. Programa la revisión de la cola cada minuto y reutiliza los secretos project_url y uw_cron_secret de Vault. Ambos nombres y las extensiones necesarias existían durante la comprobación. Este script exige que estén disponibles y no crea claves nuevas.
5. Entra en Owner, abre Alertas y Credenciales y prueba una solicitud piloto propia con una licencia o certificado ficticio claramente marcado como prueba. Comprueba el resultado, el aviso al solicitante y la trazabilidad antes de incorporar documentos reales. Los avisos internos quedan persistidos; el push al dispositivo depende de permisos, registro del dispositivo y configuración FCM del despachador existente.

## 4. Cómo decidirá la IA durante el piloto

La subida de un archivo a un borrador no verifica un perfil por sí sola. Cuando la solicitud esté enviada, con declaración aceptada y documentos privados registrados, se incorpora a la cola automática. Los documentos posteriores de una solicitud pendiente vuelven a activar la revisión.

La IA recibe los archivos asociados a la solicitud, con acceso autorizado por el backend. Puede aprobar automáticamente una credencial individual o una solicitud de identidad de adulto cuando toda la evidencia es legible, pertinente, coherente, vigente, de bajo riesgo y sin dudas, con confianza mínima 0,90. El backend vuelve a comprobar el estado, el Owner autorizado, la evidencia existente, la declaración y los requisitos del validador actual. Una identidad no se convierte por ello en una licencia profesional. El análisis del modelo no equivale a una autenticación independiente con el organismo emisor.

Durante esta fase se analizan automáticamente hasta tres documentos de verificación por solicitud, de hasta 15 MB cada uno, con un máximo total de lectura de 45 MiB. Más documentos, ausencia de evidencia, archivos ilegibles, caducidad, dudas, falta de declaración o fallos de lectura remiten a revisión manual. Los clubes, federaciones, menores, pagos y privilegios conservan la revisión humana. Licencias emitidas por una federación para una credencial profesional sí pueden entrar en el flujo automático.

Owner conserva Revisar y Verificar credencial. Las decisiones manuales cancelan trabajo pendiente; el ejecutor no reemplaza una resolución humana ya registrada. Los fallos de IA se reintentan hasta tres veces y después generan un aviso manual. Una misma ejecución no aplica dos veces la decisión.

Para detener únicamente el proceso automático: en Supabase SQL ejecuta select cron.unschedule('kombax-owner-verification-pilot-r118');. La revisión manual sigue funcionando. El botón Analizar con IA también puede realizar una verificación automática elegible cuando Owner lo solicita.

La programación sigue el mecanismo oficial de [Supabase para funciones programadas](https://supabase.com/docs/guides/functions/schedule-functions) y [pg_net](https://supabase.com/docs/guides/database/extensions/pg_net).

## 5. Hacer tu push y publicar en Netlify

Después de verificar localmente y activar Owner, revisa los archivos modificados en tu repositorio, crea tu commit y haz tú el push a origin. No se ha cambiado tu remoto.

Configuración de Netlify incluida en netlify.toml: raíz del repositorio, comando npm run release:build, carpeta publicada dist y Node 22. Se ha probado con Netlify CLI en modo offline, sin despliegue. Si tu sitio conserva ajustes externos distintos, alínalos con estos valores y revisa sus variables privadas. La prueba local no certifica los secretos ni la configuración de tu sitio real.

La compilación sincroniza web, dist y los recursos Android antes de comprobarlos. Se han corregido pruebas que exigían números de versiones antiguos, el marcador efectivo del service worker, rutas/importaciones sensibles a mayúsculas de Linux y la configuración reproducible de npm. No se han eliminado las pruebas estrictas de traducción: existen tres fallos heredados de internacionalización. El gate piloto permite exclusivamente las frases pendientes de la base congelada y bloquea nuevas regresiones. npm test continúa mostrando esa deuda; release:build es el comando comprobado para Netlify.

## 6. Crear APK y AAB en tu equipo

Abre android en Android Studio. Usa JDK 21, Android SDK 36 y tu google-services.json real para com.urbanwarriors.app. La firma de Google Play y Firebase Android no se incluyen en el ZIP: conserva los archivos de tu proyecto actual.

Para una APK de prueba ejecuta KOMBAX_20177_BUILD_ANDROID_QA.cmd. Para APK release y AAB firmadas ejecuta KOMBAX_20177_BUILD_ANDROID_PLAY.cmd después de configurar android/keystore.properties o las variables UW_* indicadas por el proyecto. Los archivos resultantes se guardan en artifacts. Los scripts seleccionan un JDK compatible y utilizan el mismo contenido web actualizado.

No se han generado APK/AAB en este entorno: Gradle no pudo establecer su conexión local antes de compilar. Tampoco se dispone de tu Firebase ni tu firma privada. Se ha comprobado la coherencia de versión, SDK, wrapper y recursos; la compilación nativa queda pendiente de ejecutarla en tu equipo. Si Google Play ya ha recibido versionCode 20177, exigirá otro versionCode para una actualización posterior; no cambies la base congelada sin registrar esa nueva entrega.

## Comprobaciones de esta entrega

- Instalación limpia con Node 22/npm 10 y compilación Netlify CLI offline: aprobadas.
- Sintaxis de 358 archivos JavaScript, 831 importaciones locales y 624 archivos iguales entre web/dist/Android: aprobados.
- Suite del gate piloto: 68 comprobaciones aprobadas y tres fallos heredados de traducción documentados.
- Reparación SQL ejecutada en PostgreSQL aislado: 26 casos aprobados, con documentos y cuentas ficticios. Los validadores anteriores se simulan en las pruebas de identidad; la revisión profesional usa la función reparada real.
- Funciones del agente comprobadas con Deno: cinco casos aprobados, con red simulada. No se enviaron documentos reales al modelo.
- Vista Owner en Chrome con datos ficticios: siete comprobaciones aprobadas, incluida revisión manual y errores visibles. Acceso público y páginas legales probados sin errores de JavaScript.
- ZIP y cuatro partes: integridad comprobada por SHA-256 y prueba de extracción.
