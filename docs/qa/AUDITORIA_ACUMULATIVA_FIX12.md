# Auditoría acumulativa R120 FIX12

Fecha: 2026-10-05. Base local acumulativa: work/URBAN-WARRIORS. Este informe es el estado de entrega vigente; los informes FIX11 y FASE1–3 describen etapas anteriores. No se afirma que el remoto GitHub esté actualizado con estos cambios.

## Familias, alumnos y matrículas

Una ficha de alumno admite varias disciplinas y varios grupos de una misma disciplina. La edición administrativa sustituye los campos incompatibles de una sola disciplina/grupo/grado por selección múltiple y guarda datos y nuevas matrículas en una transacción. Conserva las matrículas anteriores; no las desactiva implícitamente. Valida disciplina activa, correspondencia de grupo/grado, plazas, club y permisos. Una operación inválida revierte también los cambios de la ficha.

La cuenta de un tutor puede vincular varios hijos. Sus solicitudes nuevas incluyen el identificador exacto del hijo, mantienen la aprobación del club y no reutilizan otra ficha solo porque comparta el correo del padre. Al aprobar una solicitud para un hijo existente no se crea otro alumno ni se concede tutoría al administrador que aprueba. El formulario de alta inicial sigue registrando un hijo cada vez; pueden repetirse altas para hermanos y añadir varias matrículas a cada ficha.

El portal identifica la ficha del familiar seleccionado. El perfil público del adulto es independiente: consultar a otro hijo no cambia ese perfil. La relación de tutor permite las operaciones privadas autorizadas del alumno, sin otorgar automáticamente edición de su identidad Social. No se crean perfiles públicos de menores automáticamente.

Se identificaron limitaciones de selección única y referencias ambiguas de alumno en el circuito previo. No se obtuvo el registro del error concreto de las pruebas de Movfit/Urban Warriors; las correcciones se validaron con funciones reales en una base aislada y formularios con transporte simulado, sin presentar esto como reproducción autenticada en sus cuentas.

## Navegación e identidades

Marca, Federación, Profesional, Competidor, Media y Espectador comparten navegación lateral y móvil, iconos, acceso a Mi Espacio y cerrar sesión. Los entornos gestionados muestran su nombre y tipo en la cabecera, con acabado premium y efecto LED rojo KOMBAX. Se verificaron explícitamente Marca, Federación, Profesional y Media. El acabado visual no concede funciones de pago.

Los perfiles y organizaciones mantienen identidad y permisos independientes dentro de una cuenta. Los módulos de Club y sus accesos piloto se conservan. Se reutilizan los módulos existentes de campañas, catálogo, licencias, colaboraciones, operaciones profesionales, preparación, eventos, pagos y contenido; no se sustituyen sus comprobaciones por permisos visuales.

## Equipos y acreditaciones

Invitaciones genéricas para identidades adultas de Marca, Federación, Profesional, Competidor y Media: correo confirmado coincidente, consentimiento, caducidad, aceptación, rechazo, revocación e idempotencia. Roles admin/editor/comunicación, sin transferencia de titularidad. Comunicación no hereda operaciones profesionales privadas. Se añade bandeja interna; no se añade envío de correo para esta API ni un rol financiero delegado nuevo.

La verificación general habilita la actividad profesional ordinaria. Las acreditaciones adicionales se limitan a servicios específicos médicos/arbitrales con reglas expresas, evidencia y vigencia. Psicología deportiva y Psicoterapia no heredan capacidades médicas. El perfil profesional permite presentar experiencia y servicios y publicar credenciales y una copia documental expresamente autorizada. La evidencia privada original permanece privada. Ocultar o invalidar la credencial retira el acceso público de la copia. No se declara purga automática de copias privadas antiguas tras su reemplazo.

## Herramientas y finanzas

Marca y Federación tienen registro administrativo de ingresos recibidos, gastos y devoluciones, totales separados por moneda, consulta por páginas de diez y exportación de la página a CSV. No realiza cobros ni emite facturas fiscales; Stripe conserva su módulo propio. Escritura financiera reservada a administradores con identidad verificada y servicio activo; consulta autorizada y cancelación trazable siguen disponibles al vencer el servicio.

Campañas y Embajadores, Centro de Temporada y Centro de Producción añaden planificación de tareas, fechas, notas, responsables y resultados documentados; las categorías avanzadas de Marca requieren su servicio correspondiente. Es una herramienta administrativa, sin atribución automática de ventas, motor publicitario externo ni cálculo automático de ROI. La publicación de campañas y envío de propuestas de Marca requieren servicio activo y verificación; un borrador gratuito sigue permitido. La implementación antigua queda cerrada a llamadas directas para impedir saltarse ese control.

Organizadores conservan activaciones por evento, eventos y ticketing, sin exigir una suscripción de Club. Se mantiene el catálogo vigente y el bloqueo de contratación pública nueva de Marca/Federación acordado para el piloto. La nueva distribución Basic/Premium/Enterprise y sus precios/límites siguen pendientes de definición comercial; no se presentan como contratación final abierta.

## Supabase aplicado

Proyecto poggsobhtutbuagjiydc. Migraciones locales alineadas con el historial real:

- 20261005142904_kombax_professional_accreditation_scope_r120.sql
- 20261005142905_kombax_profile_team_invitations_r120.sql
- 20261005143523_kombax_professional_team_private_scope_r120.sql
- 20261005152449_kombax_professional_public_document_r120.sql
- 20261005165320_kombax_profile_operations_r120.sql
- 20261005165327_kombax_member_batch_enrollment_r120.sql

Función professional-public-document ACTIVE v1 con JWT. Depósito de copias privado. Read-back de últimas migraciones: tablas creadas sin registros de pruebas, columna de destino presente, ejecución anónima denegada y función antigua de marca cerrada a usuarios. Se ejecutaron asesores de Supabase y se revisaron los permisos de este alcance; quedan avisos de funciones SECURITY DEFINER y tablas RPC-only, y no se declara auditoría global sin avisos.

## Pruebas y límites

- 29 casos de operaciones/finanzas/campañas con implementación SQL real y esquema aislado.
- 25 casos de matrículas/familias con funciones reales: dos hijos, tres grupos por hijo, aprobación sin duplicación, capacidad, reversión, permisos y revocación.
- 26 casos de acreditación, 26 de invitaciones, 14 de matrícula previa y 24 de documentos/handler.
- 18 casos Chrome móvil de ficha, tutor, finanzas, bloqueos y marca LED en cuatro tipos de identidad; sin errores JavaScript.
- Regresión adicional de navegación, equipos y documentos en Chrome; resultados JSON adjuntos.
- Revisión acumulativa de entrega: 89 suites aprobadas, tres P2 históricos de traducción, cero fallos nuevos. La suite estricta completa no está limpia.
- Recursos web/dist/Android idénticos; sintaxis de 371 JavaScript e imports locales compatibles con Linux. La compilación de recursos contiene 637 archivos.
- HTTP real del visor para credencial inexistente devuelve 404; descarga positiva de documentos de usuario no probada en producción.

Las pruebas de navegador simulan el transporte; los casos positivos SQL usan una base aislada. No se han creado usuarios, hijos o clubes reales para probar, ni consumido plazas piloto. No se han probado APK/AAB instaladas, correos reales, renovación/cobro/fallo real de Stripe, ni un despliegue Netlify de producción. No se garantiza todo el producto por extensión de estas pruebas.

## Entrega

Paquete acumulativo en cuatro fragmentos y reunificador con verificación SHA-256. Validación CRC de todos los archivos del ZIP y prueba real del CMD de reunión, documentadas en COMPROBACION_ZIP_FIX12.json. Sin claves, dependencias instaladas ni binarios APK/AAB. No se ha hecho push, despliegue frontend ni publicación Play. Para usar los formularios y menús nuevos en la webapp debe desplegarse este frontend.
