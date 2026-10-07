# Auditoría funcional acumulativa FIX16

7 de octubre de 2026. FIX15 original conservado. Este documento sustituye los estados preliminares anteriores.

## Hallazgos corregidos

1. Administración titular tenía dirección y marca coordinación; el cliente priorizaba coordinación y ocultaba aprobar/rechazar equipo. Normalización dirigida y prioridad de dirección, sin convertir otros usuarios en titulares.
2. Avisos de equipo: los dos avisos revisados se guardaron inmediatamente o aproximadamente tres segundos después; la espera del cliente podía alcanzar cinco minutos. Refresco visible reducido a 15–30 segundos, pausa en segundo plano y backoff ante errores. No equivale a push instantáneo.
3. Cuenta existente: campos de alta nueva ocultos/deshabilitados, obligatorios solo en alta nueva. Se conservan errores de transporte/autorización sin sustituirlos por una exigencia falsa de actualizar backend. Mensajes públicos genéricos y comprensibles; detalles técnicos fuera del aviso. También se corrige el estilo de campos hidden en modales; probado su display real en navegador.
4. Aprobación de alumnos: el trigger de notificaciones chocaba con el guard de ciclo de vida. Contexto protegido limitado a sincronización y restaurado al terminar/fallar. Coordinación puede aprobar alumnos, pero no equipo.
5. Retirada de equipo: botón del titular en Mi Club > Equipo. Una confirmación; revoca todas las funciones operativas de la persona en ese club, conserva familia/alumno, cuenta y otros clubes. No puede retirar al titular. Revoca invitaciones pendientes de esa persona para ese club y registra auditoría.
6. Navegación: invitaciones y avisos generales quedan en la cuenta; no se mezclan en el menú Marca/Federación u otras identidades. Un selector, un enlace de gestionar cuenta y cierre de sesión. Showcase conserva la identidad seleccionada.
7. Fondo de onboarding e Inicio: integrado con degradados y posición superior, sin cartel independiente. La imagen original no se modifica. Estética aprobada por el usuario y conservada.
8. Archivo de documentos: fallo LIFECYCLE_GATEWAY_REQUIRED reproducido para titular. Se abre el contexto solo alrededor de la rama validada de archivo, con permisos, idempotencia y auditoría existentes; se restaura también en error. No elimina el fichero físico.
9. Showcase: patrón de URL sobreescapado en la función desplegada impedía reconocer imágenes propias para su limpieza. Corregido sin cambiar protección de propiedad, archivos compartidos ni pedidos históricos. La limpieza física es posterior mediante cola; cron activo cada minuto. No se afirma haber borrado archivos reales en esta auditoría.
10. Assist/Migrations: identidad y catálogo se obtienen del servidor bajo permisos. Rechazo de cambio involuntario de club respecto del expediente, con compatibilidad para referencias antiguas. Reglas de plataforma, lenguaje breve, una pregunta agrupada solo ante datos esenciales ambiguos y una confirmación de importación en la interfaz. No se inventan disciplinas ni asociaciones. Descarga concurrente de archivos del lote autorizado, sin modificar límites ni modelo.

11. Invitaciones de equipo: el RPC usado por la interfaz carecía de permiso de ejecución authenticated. Restaurado solo para cuentas confirmadas; se verifica correo real, estado, vencimiento y roles permitidos, sin permitir dirección.
12. Alta familiar por código: referencia ambigua a result en el gateway bloqueaba el registro. Corregida la variable manteniendo código, rate limit e idempotencia. La segunda alta familiar se realiza después de aprobar la primera vinculación al club.
13. Publicación de productos: el backend exigía ficha de seguridad estructurada sin formulario conectado. Añadidos editor privado autorizado y reglas de categoría, con fabricante, responsable UE cuando corresponda y documentos existentes conservados. Categorías restringidas quedan pendientes de revisión; Owner dispone de revisión manual con motivo y confirmación de documentación, usando el RPC existente. Aprobar ficha no publica automáticamente; completar un formulario no sustituye la autorización de venta ni activa Commerce.
14. Correo: retirado el detalle técnico de la respuesta pública de autorización en invite-email. El cambio desplegado conserva exactamente el resto de la versión activa; el código acumulativo también conserva las mejoras de idiomas previas.

15. Invitaciones personales de alumno: el gateway permanente interceptaba también los códigos personales y los rechazaba. Se deriva al flujo nominativo solo con club y correo confirmado coincidentes; conserva caducidad, uso único e idempotencia. Un resultado fallido de registro ya no consume la invitación. La corrección SQL intermedia de slug se completa en la migración siguiente.

## Matriz operativa

| Acción | Titular del club | Coordinación | Otros |
|---|---|---|---|
| Aprobar/rechazar equipo, cambiar rol, retirar acceso | Sí | No | No |
| Aprobar alumnos/matrículas | Sí | Sí | Secretaría según permisos existentes |
| Pagos manuales | Sí | Sí | Secretaría/tesorería según permisos existentes |
| Cambiar plan/titularidad de cobro | Reservado al titular | No | No |
| Archivar documentos | Sí | Sí, representada por membresía autorizada | Secretaría; monitor/familia sin autorización |
| Eliminar contenido público definitivamente | Owner de plataforma | No por ser coordinación | Moderación no obtiene borrado definitivo |
| Importación asistida | Gestión autorizada del club y confirmación | Según acceso de importación existente | Sin ampliación de permisos |

La cuenta, la identidad, el equipo y las suscripciones conservan separación. No se transfiere propiedad ni se introduce vendedor gratuito. Catálogo comercial vigente; nueva contratación pública Marca/Federación bloqueada. No se activan cobros automáticos.

## Evidencia y límites

- Supabase real: normalización de cuatro membresías de dirección y lectura posterior; aprobación de equipo y alumno comprobadas dentro de transacciones revertidas. Solicitudes reales siguen pendientes. Contexto Assist y retirada de acceso probados con rol authenticated y denegaciones fuera del contexto. Archivo de documento probado como titular y coordinación, guard restaurado y cero documentos QA persistidos.
- Migraciones FIX16 registradas: 20261006145810 (permisos de correo, ya aplicada antes de esta intervención; fichero recuperado del registro), 20261006200115, 20261006201705, 20261006211006, 20261006211717, 20261006211922, 20261006212918, 20261006213057, 20261006213119, 20261006214336, 20261006214428, 20261006221411 y 20261006221420. La corrección intermedia 213057 queda completada por 213119; aplicar en orden. Los ficheros locales coinciden con los identificadores registrados.
- Edge kombax-assist-r38 versión 15 ACTIVE, verify_jwt=true, contenido leído de nuevo. Primer intento falló por referencia antigua de import map; segundo despliegue con deno.json explícito completado. No hubo despliegue Netlify ni publicación Play.
- Supabase real adicional, con SET LOCAL ROLE authenticated y transacciones revertidas: invitación nominativa creada/aceptada, correo incorrecto rechazado; solicitud de coordinación por código sin acceso prematuro y aprobación del titular; tutor por código general y, en un segundo ensayo, invitación personal, con dos hijos, dos disciplinas y tres grupos por hijo, aprobación por coordinación y lectura familiar autorizada.
- Contenido real revertido: publicación Social, producto general con ficha de seguridad, evento borrador/publicado y retirada/eliminación Owner; publicaciones/productos ausentes de feeds públicos después de las acciones. Producto restringido bloqueado antes de revisión; vendedor no puede aprobar su propia ficha; revisión Owner comprobada. Owner usa una sesión de prueba administrativa con AAL2 dentro de la transacción, no se desactiva la seguridad de producción.
- Correo externo: invite-email versión 10 ACTIVE y JWT obligatorio. 16 controles del handler acumulativo y otros 16 del código efectivamente desplegado, con proveedor simulado; autenticación, destinatario autorizado, códigos, HTML escapado, éxito/error y configuración ausente. No se envían mensajes reales ni se ha verificado entregabilidad SMTP/bandeja de entrada. Los logs consultados no aportaron evidencia de entrega.
- Bases aisladas: 11 controles de titularidad, 8 de preinscripción, 33 de roles/retirada, 10 de contexto Assist, 9 de archivo 57 de eliminación/moderación, 13 de aceptación de invitaciones, 8 del gateway de cuenta por código y 11 de permisos del editor de seguridad de productos y 14 del recorrido de invitación personal de alumno. Pruebas con código real y fixtures; no son sesiones de usuarios reales.
- Handler Assist: 29 controles con proveedor IA y almacenamiento simulados; contexto, carga paralela, límites, autenticación y contabilización. No hubo inferencia real, entrenamiento de un modelo ni medición de latencia real. Las pautas mejoran instrucciones/contexto; su calidad conversacional necesita prueba de uso.
- Navegador local: 17 controles de acceso/retirada/formulario; 44 Marca/Federación; 30 menús de seis tipos; 12 encuadres responsive y 17 interacciones del formulario de seguridad Showcase (producto correcto, datos requeridos, enlaces inválidos, conservación de documentos y bloqueo de publicación restringida). Sesiones y repositorios simulados. Capturas revisadas. No se prueba una APK instalada.
- Auditoría Supabase: los RPC nuevos SECURITY DEFINER expuestos a authenticated requieren revisión de sus comprobaciones explícitas. En las funciones de contexto/retirada auditadas: contexto comprueba acceso por identidad; retirada exige titular y protege propietario. search_path vacío y anónimo sin ejecución. Los dos RPC adicionales de seguridad Showcase requieren autenticación; el editor además comprueba gestión de la entidad. Las pruebas aisladas verifican rechazo anónimo, otra entidad e ID inexistente. Los avisos heredados del proyecto no se consideran resueltos ni se afirma ausencia global de problemas.
- Regresión acumulativa incluye altas, familias con varios hijos, disciplinas/grupos, cuotas, pagos, verificación, equipos, servicios, archivos y moderación. El registro final de compilación indica el resultado de suites y las tres incidencias de traducción heredadas congeladas. No se modifica su baseline para ocultar errores nuevos.

Los ensayos de Events no incluyen ticket vendido, check-in ni liquidación Stripe real. Las regresiones de pagos/ticketing son aisladas y de contrato; no se afirma validación completa en producción. Los flujos por email requieren comprobar la recepción externa.

La cuenta reportada que no pudo enviar solicitud está confirmada; su envío SQL con identidad autenticada funcionó y se revirtió. No se reprodujo su sesión móvil ni se conoce su fallo exacto. Requiere repetir desde la sesión del usuario para cerrar ese caso particular.

## Actualización

Supabase ya contiene estas correcciones. Formulario, botones, navegación, refresco y vista de Migrations necesitan desplegar el frontend actualizado. Recursos web/dist/Android sincronizados; no existe APK/AAB nueva compilada. Una AAB requiere firma original y versionCode no utilizado.

ZIP acumulativo en cuatro fragmentos con reunificador y SHA-256; el manifiesto y COMPROBACION_ZIP_FIX16.json son la evidencia de integridad final. No publicar hasta leer los límites anteriores.

Prueba de correo autorizada a bryanmrg@gmail.com pendiente: el control del navegador falló dos veces al inicializar el entorno (helper_unknown_error). No se envió invitación real ni se creó acceso para esa prueba. No se sustituye el envío de la aplicación por un correo de otra herramienta.

Cierre de compilación: 108 suites PASS, tres P2 heredados y cero fallos nuevos. Compatibilidad Linux: 376 módulos JavaScript y 901 importaciones locales. Web, dist y recursos Android idénticos. La suite estricta conserva los tres P2; no se afirma una ejecución estricta completamente verde.
