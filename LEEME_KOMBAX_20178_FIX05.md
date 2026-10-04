# KOMBAX R118 FIX05 — build 20178, base congelada 20177

Entrega acumulativa: conserva FIX01, FIX02, FIX03 y la reparación Netlify FIX04; incorpora el flujo de Mi Espacio acordado. Esta guía sustituye las indicaciones de acceso y versión de las guías anteriores, conservadas como historial.

## Reunir las cuatro partes

1. Guarda KOMBAX_20178_R118_FIX05.zip.001, .002, .003 y .004 junto a UNIR_KOMBAX_20178_FIX05.cmd en una misma carpeta.
2. Ejecuta el CMD: reúne el ZIP y comprueba su SHA-256. Extrae únicamente el ZIP completo.
3. Haz copia de seguridad de tu carpeta GitHub. Conserva su carpeta .git y tus archivos privados de Firebase y firma Android. Copia dentro el contenido de KOMBAX_20178_R118_FIX05, sin introducir otra carpeta contenedora dentro del repositorio.
4. No conserves un pnpm-lock.yaml antiguo: esta entrega utiliza npm y package-lock.json. Con Node 22 y npm 10, ejecuta KOMBAX_20178_VERIFY_LOCAL.cmd.
5. Revisa los cambios y realiza tú mismo el push origin. No se ha realizado push, despliegue Netlify ni subida a Google Play por el agente.

## Flujo implementado

- Acceder a mi cuenta y completar un registro gratuito sin intención específica llevan al inicio existente: Social, Showcase, Events y Mi Espacio.
- Crear o gestionar mi perfil conserva su recorrido específico. Crear cuenta gratuita aparece antes de las tarjetas de identidad. Cuenta no equivale a perfil público.
- Mi Espacio reúne la gestión con barra lateral y menú móvil: explorar, Mi perfil, organizaciones/club y configuración. Se elimina el botón flotante Cambiar espacio y se incorpora acceso a Mi Espacio en la barra lateral del club.
- Un perfil personal presenta sus capacidades de espectador, competidor y profesional sin duplicar el acceso a su presentación pública. Los registros internos de facetas se conservan para sus verificaciones y herramientas; las organizaciones tienen identidad propia.
- Una cuenta sin perfil personal recibe la invitación a crearlo, aunque ya tenga una membresía privada o administre una organización.
- El practicante puede tener perfil público independiente, pero publicar como practicante sigue requiriendo membresía activa confirmada, edad y permisos del servidor. Solicitar una vinculación no habilita publicación.
- El directorio del club utiliza una selección común; el servidor distingue membresías, equipo y permisos. Los códigos, solicitudes, recuperación y aceptación de invitaciones se conservan.

## Piloto protegido

Comprobación real del proyecto Supabase poggsobhtutbuagjiydc: ventana abierta, cuatro plazas totales, una utilizada y tres restantes. Alta sin código ni tarjeta, con cuenta y correo confirmado; documentación inicial no obligatoria. Las autorizaciones verbales del Owner siguen sin convertirse en una lista de correos.

La nueva prueba comercial no sustituye los beneficios del piloto: la activación identifica las organizaciones piloto y conserva su circuito. Operaciones del piloto desde 05/10/2026 a las 00:00 de Madrid; fin de su ventana 16/11/2026 a las 00:00 de Madrid. El club se conserva después.

## Prueba y publicaciones de organizaciones

Mi club / la acción de servicios de una federación permite consultar el estado y activar expresamente una prueba de 30 días. Se crea una suscripción temporal del plan correspondiente; no se crea un cobro ni renovación automática. Una segunda activación no reinicia el plazo. Un plan activo conserva su estado después de una prueba anterior.

La prueba no sustituye las verificaciones, los permisos del equipo ni el alta del proveedor de pagos. La federación conserva los requisitos de verificación para sus capacidades. Los permisos derivados de su prueba tienen vencimiento.

Para clubes y federaciones sin plan activo: máximo tres publicaciones sociales por mes natural UTC. El servidor conserva los consumos aunque se borren publicaciones. El perfil público se conserva al terminar la prueba. Las verificaciones y reglas de publicación existentes siguen vigentes.

Se han aplicado y comprobado en Supabase las migraciones 20261004010000, 20261004011000 y 20261004012000 incluidas en supabase/migrations. No se han iniciado pruebas comerciales reales ni cobros durante QA. Para otro proyecto, aplica las migraciones en su orden y comprueba su historial.

## QA y alcance de la comprobación

- Compilación npm run build / release:build con Node 22: 72 comprobaciones PASS, cero fallos nuevos. Permanecen tres incidencias heredadas de traducción documentadas por la puerta piloto; npm test estricto sigue fallando por esas incidencias.
- Navegador Chrome real con datos de prueba: 18 recorridos, sin errores JavaScript, escritorio y móvil. Incluye registro confirmado simulado, inicio, Mi Espacio, recuperación de fallos, invitación piloto, equipo, aislamiento del club, facetas y activación expresa.
- PostgreSQL aislado: 18 comprobaciones de prueba, autorización, caducidad, repetición, activación nula, cuotas, borrado de publicaciones, continuidad de plan y separación del piloto.
- Compatibilidad: 360 módulos JavaScript analizados y 837 importaciones locales comprobadas con mayúsculas/minúsculas exactas. Web, dist y recursos Android idénticos. Son comprobaciones locales en Windows; no se afirma haber ejecutado Linux ni haber desplegado la revisión en Netlify.
- FIX04 reproduce el error NaN de Netlify y utiliza un informe separado de la consola para contar módulos. Sus regresiones comprueban salida adicional, conteo incorrecto y sintaxis inválida.

Los informes y registros están en docs/qa. Las pruebas de navegador utilizan fixtures: no prueban correos reales, compras reales, documentos reales aprobados por IA ni la totalidad del piloto con usuarios finales.

## APK y AAB

El proyecto incluye wrapper Gradle, SDK objetivo 36, applicationId estable com.urbanwarriors.app, versión nativa 20178 y los mismos recursos que la web. La revisión de requisitos obtuvo 7/9: faltan en el paquete Firebase y firma, que son archivos privados y deben conservarse en tu equipo.

Antes de compilar, restaura android/app/google-services.json, android/keystore.properties y tu almacén de claves real. Usa la misma clave de subida que la aplicación existente en Play. Selecciona JDK 21 en Android Studio y SDK Android 36. Ejecuta npm run android:preflight y después npm run android:play:r118; el procedimiento produce APK de release y AAB firmadas en artifacts si todas sus comprobaciones terminan correctamente.

Se intentó la compilación Gradle dos veces y falló con java.io.IOException: Unable to establish loopback connection antes de compilar la aplicación. Por ello NO se entregan APK/AAB compiladas ni se certifica la compilación nativa. Comprueba además que 20178 es superior al último versionCode utilizado en tu Play Console; su estado de revisión no se ha comprobado en esta fase.

## Pendientes externos

No se certifican ventas ni pagos reales. La activación completa de Stripe, firma Android, notificaciones Firebase, entrega de correos y pruebas finales con usuarios requieren sus configuraciones y validaciones correspondientes. Consulta ESTABILIZACION_PILOTO_FIX02.md para el historial; los estados antiguos de terceros pueden haber cambiado y no deben interpretarse como comprobación actual.
