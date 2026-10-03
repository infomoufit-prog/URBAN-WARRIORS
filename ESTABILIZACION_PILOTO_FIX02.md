# Estabilización KOMBAX 20177 R118 FIX02

Comprobación del 03/10/2026 sobre el proyecto Supabase poggsobhtutbuagjiydc y el código entregado. El alta gratuita Club Piloto está comprobada y corregida. El piloto completo todavía no está certificado de extremo a extremo: Stripe y correo requieren actuaciones externas, y quedan recorridos de usuario por ensayar.

## Reparaciones aplicadas realmente

- Reparación Owner: SQL de verificación, colas privadas, alertas, notificaciones y revisión manual.
- Función Owner v7 y worker v2 desplegados. El worker usa autenticación propia por secreto de cron; rechaza llamadas anónimas. El agente mantiene validación JWT.
- Planificador activo cada minuto; varias ejecuciones correctas. Una llamada autenticada al worker respondió HTTP 200 con processed:0 porque no había expedientes pendientes. El diagnóstico autenticado posterior confirmó agent_configured:true y la versión de agente R118: las credenciales necesarias están presentes, aunque no se ejecutó una inferencia con documentos reales.
- Corrección del disparador compartido de identidad: accedía a NEW.origen_identidad_social_id en la tabla de solicitudes, donde ese campo no existe. Impedía realmente crear Clubs; la prueba inicial reprodujo el error 42703. La corrección conserva el control de titularidad y la compatibilidad de facetas.
- Preferencia de idioma activada: faltaban la columna y dos servicios utilizados por el cliente.
- Health v41 actualizado: antes anunciaba 20172; ahora responde HTTP 200 con build 20177 y db:ok.
- Retirados dos adaptadores familiares sin consumidores que apuntaban a servicios inexistentes. Los controles familiares que usa Social continúan utilizando los servicios reales de consentimiento.
- Pruebas históricas adaptadas a la versión actual, tildes y finales de línea Windows, conservando sus comprobaciones funcionales. Verificador de sintaxis optimizado: analiza cada módulo con el parser de módulos de Node sin ejecutar su contenido.

## Evidencia por recorrido

| Recorrido | Comprobación realizada | Límite de la comprobación |
|---|---|---|
| Cuenta gratuita → Club Piloto | Base real: creación de usuario y perfil, Club, dirección y Premium piloto sin tarjeta ni pago; repetición idempotente | Prueba SQL con correo previamente confirmado; no prueba la entrega del correo de Auth |
| Cuatro Clubs | Base real: un Club existente más tres temporales; quinto Club rechazado con KOMBAX_PILOT_CLUB_SLOTS_FULL | Transacción revertida; quedaron uno registrado y tres plazas libres |
| Cuenta con clasificación previa | Base real: cuenta gratuita con clasificación legacy profesional también crea Club | No comprueba cada combinación de facetas públicas |
| Equipo del Club | Base real: invitación, aceptación y relación activa de comunicación; otro correo rechazado | No se envió ningún correo ni se probó el clic en una invitación recibida |
| Alumnos, disciplina y grupo | Base real mediante app_mutate_v160: se crean y relacionan correctamente | Reclamos de acceso de alumno, tutor y cada rol requieren recorrido completo de usuario |
| Sesiones | Base real mediante el canal de escritura: sesión programada creada para el grupo | Reservas, recurrencia, asistencia y cada rol quedan por probar de extremo a extremo |
| Recibos | Base real: cuota y material emiten recibo con importes/conceptos correctos; pago parcial no emite recibo final; sin duplicados | Prueba del disparador con estados temporales, sin cobros de Stripe |
| Logos de recibos | Navegador: dos emisores distintos usan su nombre/logo y no los de otro Club de la sesión; acción imprimir/PDF presente | Datos de prueba; no se completó una impresión PDF con datos de producción |
| Informes PDF y analytics | Funciones existentes; acceso anónimo bloqueado; pruebas de contrato financiero y de informes pasan | Falta generar y revisar PDF real autenticado, logos y rangos de cada Club |
| Material y publicaciones del Club | Base real: producto de material y publicación creados por el canal de escritura | No se subieron imágenes ni se cobró una venta |
| Showcase y multimedia | Editor y carga ensayados con mocks: clasificación, portada/galería, formatos y límites; categorías públicas responden 200 | Pendiente subida real, publicación Social/Showcase autenticada, compra y confirmación de webhook |
| Perfiles personales, profesionales y espectadores | Pruebas R118 y registro actuales pasan; continuidad de identidad y bloqueo de titular ajeno comprobados en PostgreSQL aislado | No sustituye un recorrido real para cada perfil/edad/membresía |
| Verificación de documentos | SQL privado, funciones y cron activados; 26 casos de decisión SQL aislados y 5 casos Edge con respuestas simuladas | No se presentó ni aprobó un documento real de usuario durante esta auditoría |
| Stripe | Funciones activas; checkout exige login; webhook rechaza llamadas sin firma; estado guardado consultado | Cuenta conectada action_required; cobros y transferencias false; compra no comprobada |
| Correos y avisos | Avisos internos Owner activados; pruebas de invitaciones y notificaciones pasan | Despachador informa commerce_email.configured:false; recepción de Auth/invitaciones/push pendiente |

Las pruebas SQL de alta, equipo, sesiones, productos y recibos finalizaron con ROLLBACK. Comprobación posterior: cero usuarios y cargos de prueba restantes. No se consumieron plazas, enviaron invitaciones por email ni realizaron cobros.

## Cuatro autorizaciones verbales

El Owner autoriza verbalmente a quienes registrarán los cuatro Clubs. La aplicación limita a cuatro Clubs, no comprueba esa autorización verbal ni identifica cuatro correos concretos. La ventana está abierta y no pide código. La cuenta de dirección es gratuita y el beneficio Premium del piloto corresponde al Club. Una cuenta no puede dar de alta otro Club si ya administra uno fuera de la reutilización idempotente de su Club piloto.

Alta abierta hasta el 16/11/2026 a las 00:00 de Madrid. La configuración distingue las operaciones del piloto, fechadas desde el 05/10/2026 a las 00:00. No se han ampliado fechas ni plazas.

## Comprobaciones de código y navegador

Gate de entrega: 69 comprobaciones pasan, tres incidencias de traducción heredadas siguen identificadas y no se admiten regresiones nuevas. Las nueve pruebas adicionales seleccionadas pasan. Sintaxis de 358 módulos, 831 importaciones locales sensibles a mayúsculas Linux y 624 archivos web/dist/Android coincidentes comprobados. HTTP: siete comprobaciones pasan, incluidos salud, alta pública, categorías y protección de funciones. Navegador de escritorio/móvil: sin errores JavaScript, recursos locales fallidos ni desbordamiento horizontal.

El inventario compara nombres de servicios usados por el cliente con Supabase; no constituye una ejecución de todas las combinaciones de argumentos, permisos y rutas. Las pruebas de texto y mocks están diferenciadas de las transacciones en la base real.

El compilador local ha pasado. No se ha publicado en Netlify ni hecho push a GitHub. La compilación APK/AAB continúa sin verificar y requiere Firebase, firma y Android Studio/entorno nativo funcional. npm test estricto sigue detectando las tres incidencias de traducción documentadas en FIX01.

## Qué impide certificar el piloto completo

1. El titular de Stripe debe completar el alta alojada: negocio, representante, cuenta bancaria, términos y pruebas de identidad. La base refleja requisitos pendientes de esas categorías y cobros/transferencias deshabilitados. No se inventan esos datos ni se marcan artificialmente como completados. El conector Stripe no llegó a proporcionar una cuenta usable tras solicitar autenticación; no se cambió su configuración ni se hizo una transacción de prueba.
2. Configurar el canal comercial de correo y comprobar confirmación, recuperación e invitaciones con destinatarios de prueba autorizados. commerce_email.configured:false no demuestra por sí solo que el SMTP de Auth esté desconfigurado: son canales distintos.
3. Con esos servicios listos, completar una sesión real de pruebas por rol: dirección, equipo, alumno, familiar y espectador; documentos reales de prueba legibles/dudosos; publicación con archivos reales; PDF; venta, webhook, recibo y reembolso en modo de prueba.

La revisión automática de Supabase conserva avisos generales sobre funciones SECURITY DEFINER y tablas privadas con RLS sin políticas. Esos avisos no demuestran por sí solos un fallo: el diseño usa servicios gobernados y tablas sin acceso directo. La protección de contraseñas filtradas aparece desactivada; su referencia oficial es https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection. Esta estabilización no constituye una auditoría de seguridad integral.
