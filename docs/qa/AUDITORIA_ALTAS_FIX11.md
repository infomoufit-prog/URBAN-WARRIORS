# Auditoría de altas · KOMBAX FIX11 acumulativo

Fecha de comprobación: 4 de octubre de 2026. Base de código: work/URBAN-WARRIORS, acumulativa sobre FIX10. Proyecto Supabase comprobado: poggsobhtutbuagjiydc. El backend de estas correcciones está aplicado; el frontend se entrega para despliegue. No se ha hecho push, despliegue Netlify ni compilación nueva de APK/AAB.

## Incidente del club piloto

La cuenta indicada existe y tiene el correo confirmado. No tenía membresía de club en la comprobación final. La imagen compartida por Instagram muestra el fallo del formulario de KOMBAX; no demuestra un acceso mediante Instagram.

Los registros de Supabase permitieron identificar el error real: el formulario envió el identificador de Instagram del club, pero la columna de perfil público exigía una URL HTTPS. La activación fallaba al escribir ese perfil y revertía la operación. Se reprodujo la restricción `perfiles_club_publicos_instagram_check1` antes de corregirla. La presentación vacía del formulario no causaba ese error.

El backend ahora transforma un identificador válido, con o sin @, en una URL de Instagram. También normaliza enlaces web, TikTok y YouTube, conserva campos vacíos como opcionales y rechaza entradas inválidas con un error identificable. La activación con la cuenta afectada se probó dentro de una transacción: creación del club, perfil público, dirección, beneficio piloto e idempotencia. Se revirtió todo. No hemos creado Urban Warriors en nombre del usuario ni utilizado su contraseña.

## Correcciones realizadas

| Problema comprobado | Corrección |
|---|---|
| Identificador social incompatible con la restricción de URL | Normalización de enlaces en la operación de alta piloto del servidor. |
| Descripción de club admitida hasta 1.600 caracteres aunque la tabla solo admite 1.200 | Límite de 1.200 en formulario y operación piloto; mensaje explícito si se supera. |
| Descripciones válidas de perfiles chocaban con la biografía Social de 800 caracteres | Se conserva la descripción completa; únicamente el resumen Social se recorta a 800. |
| La fecha de nacimiento enviada directamente al servidor podía permitir cuentas menores de 16 | El disparador de alta valida edad mínima de 16; tutor requiere 18. |
| Fecha futura o anterior a 1900 de un menor pasaba el cálculo previo de edad | Validación canónica de fecha antes de crear la preinscripción. |
| El alta en club podía sustituir la fecha canónica de la cuenta | El servidor rechaza una fecha diferente a la de la cuenta autenticada. |
| Algunos consentimientos obligatorios no tenían la restricción nativa del formulario | Los campos checkbox marcados obligatorios ahora bloquean el envío sin aceptación. Los opcionales permanecen opcionales. |
| Reintentos por una API antigua tras rechazos de validación | Solo se permite compatibilidad cuando realmente falta la función; no ante errores de negocio o red. |
| Reglas incoherentes de contraseña entre alta nueva y acceso existente | Alta nueva exige ocho caracteres antes de enviar a Auth; acceso existente deja autenticar su contraseña al servicio Auth. |

Se añadieron mensajes de los nuevos errores en los ocho idiomas existentes. No se modificaron los planes, el límite piloto, la concesión de permisos de dirección, la verificación de vendedor ni las reglas de publicación del miembro sin club.

## Cobertura y pruebas

| Flujo | Evidencia obtenida | Límite de la comprobación |
|---|---|---|
| Cuenta gratuita general | Navegador: fecha, contraseña, consentimientos y conservación de datos durante confirmación. Base real: rechazo de menores y ausencia de altas parciales. | No se recibió un correo real ni se completó su enlace. |
| Club piloto | Reproducción del fallo y activación transaccional con la cuenta afectada. Dirección, beneficio e idempotencia comprobados. | Alta real pendiente de que el usuario la envíe. |
| Cupo piloto | Se llenaron temporalmente las plazas disponibles; un quinto club fue rechazado; los reintentos no duplicaron club. | Todo se revirtió. |
| Club ordinario | Formulario móvil, nombre, descripción, documento y declaración. Validaciones compartidas auditadas. | No se completó una solicitud real y su aprobación externa. |
| Adulto y familia/tutor | Alta transaccional real: menor asociado, solicitud pendiente, fecha canónica, duplicados y fechas inválidas. Formularios móviles. | No se probó la entrega de email. |
| Equipos | Invitación personal rechaza correo ajeno; aceptación vinculada al correo correcto; código general crea solicitud pendiente sin membresía activa; dirección no se puede autoasignar. | No se envió una invitación por email real. |
| Ficha de alumno existente | Formulario y autenticación simulada con contraseña anterior; prueba de operaciones de alumno en club. | No se inició sesión con credenciales reales de un alumno. |
| Espectador, competidor, profesional, media, marca y federación | Se crearon los seis tipos en la base real dentro de transacciones reversibles, incluidos textos largos y resumen Social. Formularios de solicitud y documentación. | Se comprobó creación y restricciones, no aprobación externa de documentos reales. |
| Miembro público sin club | Creación transaccional de identidad pública; publicación deshabilitada y sin membresía artificial. | Vinculación real posterior pendiente. |
| Vendedor autorizado | Formulario móvil y bloqueo sin verificación; declaraciones y datos fiscales obligatorios. | Sin aprobación comercial, onboarding Stripe ni cobro real. |
| Documentación | Archivos vacíos, no admitidos y superiores a 15 MB rechazados antes de subir; archivo de prueba limpiado si falla la escritura de metadatos. | Ensayo de navegador con almacenamiento simulado. |
| Operaciones tras crear club | Base real: disciplina, grupo, alumno, sesión, material y publicación de club en prueba reversible. | No sustituye probar todos los servicios de pago o PDFs en dispositivos reales. |

Resultados finales:

- Tres suites nuevas de base aislada: 23 + 15 + 21 = **59 comprobaciones correctas**.
- Chrome real, ventana móvil de 390 × 844 y servicios externos simulados: **73 comprobaciones**, cero errores de página. No se enviaron altas reales desde estos ensayos.
- Puerta acumulativa de entrega: **83 suites correctas**, tres P2 históricos de traducción, cero fallos nuevos.
- Compatibilidad: **365 archivos JavaScript y 858 importaciones locales** comprobados para Linux. Construcción de 631 archivos; web, dist y recursos web de Android idénticos, build 20178.
- La suite estricta completa conserva los tres P2 de traducción: no se declara totalmente limpia.

Las pruebas SQL `club-team-live-rollback-fix11.sql` y `pilot-capacity-live-rollback-fix11.sql` finalizan deliberadamente con un error `QA_..._OK_ROLLBACK` después de todas sus aserciones. Este marcador indica que llegaron al final y revierte las escrituras. Otro error no indica éxito. Son pruebas, no migraciones de despliegue.

## Estado final de la base y migraciones

Última lectura: tres clubes totales, uno inscrito en el registro piloto —una de las cuatro plazas—, cuenta afectada confirmada, cero membresías para esa cuenta, cero cuentas de prueba restantes y cero perfiles huérfanos. Se distingue el número total de clubes del cupo del registro piloto.

| Archivo local | Nombre aplicado | Versión registrada por el servicio |
|---|---|---|
| 20261004193838_kombax_pilot_profile_input_r119.sql | kombax_pilot_profile_input_r119 | 20261004194516 |
| 20261004195147_kombax_registration_validation_r119.sql | kombax_registration_validation_r119 | 20261004195622 |
| 20261004200243_kombax_profile_social_bio_limit_r119.sql | kombax_profile_social_bio_limit_r119 | 20261004201756 |

El servicio asignó sus propias versiones al aplicar las migraciones. Ya están activas en este proyecto: no repetirlas ni ejecutar una sincronización de migraciones a ciegas. En otro entorno deben revisarse primero el historial y las dependencias del paquete acumulativo.

El asesor de Supabase conserva avisos de configuración previos: tablas con RLS sin políticas, funciones definidoras ejecutables por roles anónimo/autenticado y protección de contraseñas filtradas desactivada. Son categorías agrupadas, no cuatro incidencias individuales ni prueba automática de explotación. No se han corregido globalmente dentro de este cambio. Referencias: [asesor de base de datos](https://supabase.com/docs/guides/database/database-linter), [protección de contraseñas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## Uso de la entrega

FIX11 contiene los cambios acumulativos de FIX10 y esta auditoría. El fallo concreto del alta piloto está corregido en el backend y la cuenta afectada puede volver a intentarlo desde su aplicación. Los nuevos límites, mensajes y validaciones visuales requieren desplegar este frontend y, para la aplicación instalada, compilar una actualización que lo incluya.

No se garantiza aquí la entrega real de correos, Stripe, las reglas de aprobación de Google Play ni el funcionamiento de una APK instalada que no hemos probado. No se ha compilado una AAB. El código fuente Android conserva 20178: Google Play ya comunicó que está utilizado. Antes de generar otra AAB hay que elegir un versionCode superior al máximo realmente utilizado en Play Console y conservar la misma identidad y firma de aplicación.

Los nuevos espacios de perfiles y suscripciones que siguen documentados como plan en entregas anteriores no se presentan como implementados por esta auditoría.

Coloca las cuatro partes FIX11 y el archivo UNIR_KOMBAX_20178_FIX11.cmd en una carpeta. Ejecuta el archivo de unión y espera su comprobación SHA-256; después extrae el ZIP. Conserva la carpeta .git, credenciales, configuraciones locales y firma Android al trasladar cambios a tu checkout. El paquete no contiene dependencias instaladas, claves privadas ni APK/AAB. La aplicación debe revisarse en staging y en el dispositivo piloto antes de publicar.
