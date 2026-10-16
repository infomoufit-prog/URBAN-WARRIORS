# R277 acumulativo · Ayuda natural, 200 preguntas y perfil público

## Cambios

- Ayuda interpreta significado, utilidad o procedimiento; no sustituye automáticamente una definición por pasos.
- Las consultas de seguimiento conservan el tema. Compatibilidad con clientes anteriores que omiten el hilo: solo se recupera el título de una guía autorizada, sin copiar información privada de Assist.
- «Necesito más ayuda», «No lo entiendo» y «No me queda claro» permiten continuar. Si una respuesta es parcial, la IA invita a concretar lo que falta; no debe repetir esa invitación en todas las respuestas. La interfaz nueva incluye una indicación breve junto al campo de consulta.
- Catálogo de exactamente 200 preguntas distintas, con respuestas basadas en 67 guías existentes. Consulta humana: `docs/FAQ_200_R277.md`. Conservan restricciones de perfil, rol, verificación y servicio de la guía de origen. No se envían las 200 preguntas al modelo en cada consulta.
- Corregida la interpolación del prompt de ayuda gratuita, que podía insertar el código de una función en lugar de las instrucciones.
- Assist responde de forma breve y natural, distingue ausencia de datos de saldo cero y no afirma que se hayan ejecutado cobros.
- Social invita a «Crear mi perfil público» solo a la cuenta autenticada sin perfiles públicos. Explica ventajas y requisitos con detalles desplegables. No invita a duplicar perfiles existentes ni confunde un fallo de consulta con una cuenta sin perfil. Crear el perfil no otorga permiso de publicación.

## Conocimiento acumulativo revisado

No es reentrenamiento automático del modelo ni publicación automática de respuestas anteriores. Una respuesta completada puede generar una observación de carencia de guía o corrección, pendiente de revisión. La observación conserva identificadores de guía y del turno, no copia preguntas, respuestas, nombres ni datos financieros al conocimiento compartido.

Solo una aclaración general redactada y publicada expresamente por Owner se incorpora a consultas futuras. Una modificación de una aclaración publicada la devuelve a borrador. Las fuentes se filtran otra vez por los permisos actuales. No se han publicado aclaraciones de prueba en producción.

Migración aplicada y registrada: `20261016150256_help_reviewed_knowledge_r277.sql`. Esquema privado `kombax_help_knowledge`, tres tablas con RLS sin acceso directo de clientes. Dos RPC de servicio y dos RPC de Owner protegidas con usuario autenticado y comprobación de administrador de plataforma.

La revisión administrativa se realiza mediante las RPC `app_kombax_help_knowledge_owner_r277` y `app_kombax_help_knowledge_review_r277` con sesión Owner. Este paquete no añade una nueva pantalla de revisión Owner. Las operaciones disponibles son `draft`, `publish`, `reject`, `reviewed` y `dismiss`. Publicar exige el texto exacto `PUBLICAR CONOCIMIENTO GENERAL SIN DATOS PERSONALES`. No ejecutar esas llamadas con una sesión ordinaria ni usar una clave de servicio en frontend.

## Supabase verificado

Proyecto `poggsobhtutbuagjiydc`:

- `kombax-assist-r38`: versión 31, ACTIVE, JWT obligatorio.
- `kombax-usage-help`: versión 8, ACTIVE, JWT obligatorio.
- Se han leído de vuelta y comparado literalmente los seis archivos de cada despliegue con los preparados localmente: coinciden.
- Cuentas gratuitas: cinco respuestas IA completadas al mes por cuenta; pago: saldo y límites compartidos existentes con Assist y Migrations. No se cambian modelos, precios ni secrets.
- Verificación real de captura: una observación `correction` y otra `faq_gap` pendientes; cero aclaraciones publicadas al verificar. Los contadores pueden cambiar con el uso posterior.

Los advisors no están libres de avisos: seguridad muestra 242 tablas con RLS sin políticas, 61 funciones SECURITY DEFINER invocables por anon, 662 por authenticated y un aviso de protección de contraseñas comprometidas. Rendimiento: 259 claves foráneas sin índice, 298 índices sin uso y un índice duplicado. No se han alterado avisos heredados para silenciarlos. Las tres tablas privadas nuevas explican tres avisos informativos; las dos RPC Owner explican dos avisos SECURITY DEFINER, con comprobación de Owner y pruebas de denegación. El índice nuevo puede figurar como aún no utilizado.

## Evidencia de pruebas

- Pruebas aisladas de conocimiento: 23 comprobaciones de roles, RLS, borradores, publicación explícita, revocación e idempotencia; proveedor simulado, sin publicar conocimiento real.
- FAQ y recuperación: 2142 comprobaciones de cantidad, unicidad, fuentes, límites, permisos y continuidad sin copiar datos privados; sin llamadas al proveedor.
- Social: 41 casos de cuenta vacía, ocho tipos de perfiles existentes en cuatro estados, visitante, consulta no disponible y separación de permisos.
- Assist natural: 91 comprobaciones con proveedor simulado. Ayuda universal: 28; handler: 39. Estas suites se solapan con el gate, no sumarlas como pruebas independientes.
- Navegador real: seis consultas a Assist en el club demo verificaron utilidad, error ortográfico, continuidad, datos inexistentes, club activo y límites para cobrar. Ayuda real confirmó definición de cuota y seguimiento «¿Y eso para qué sirve?» sin pedir repetir el tema.
- Navegador local con datos simulados: invitación Social en escritorio y móvil de 390 px, detalles desplegables y ausencia de invitación al simular un perfil existente. El botón del arnés solo confirma la selección; no crea una cuenta ni sustituye una prueba de alta real.

El aviso de conexión comunicado por el usuario no tiene una causa única demostrada: el navegador registró problemas de conexión y el reintento acabó completado, sin evidencia de agotamiento de saldo. No se afirma haber eliminado cualquier posible interrupción de red. El frontend de producción observado todavía anteponía algunas guías; para la experiencia de conversación IA primero y la nueva indicación visual se necesita desplegar el frontend de este acumulativo.

El resultado final del gate y la compilación se adjunta en el registro `R277_RELEASE_COMPLETE.log`. Se mantienen visibles las tres incidencias heredadas de traducción: `i18n-r79-full-product-audit`, `test-kombax-20130-r79-i18n-phases-6-10` e `i18n-runtime-copy-audit`. La suite estricta no se presenta como completamente verde.

Resultado final ejecutado: **129 comandos PASS, tres P2 conocidos, cero fallos nuevos**. Build: **664 archivos**, web/dist/Android idénticos. Compatibilidad Linux: **396 archivos JavaScript y 965 importaciones locales**. La comprobación legal también pasó. Una consulta posterior a logs de estas dos funciones no devolvió filas en la ventana consultada; eso no demuestra ausencia universal de errores. Las respuestas reales y la lectura de los despliegues son la evidencia funcional disponible.

## Entrega y actualización

Acumulativo completo sobre el ZIP R275, que se conserva intacto. El manifiesto de integridad enumera los archivos modificados y añadidos. `web`, `dist` y recursos web Android se sincronizan mediante el build. No se ha compilado una APK/AAB ni se ha incrementado el código de versión Android.

La migración R277 ya está aplicada: no volver a ejecutar indiscriminadamente todas las migraciones históricas. Sigue incluida la discrepancia histórica R274 documentada en la entrega R275; esta migración nueva sí tiene el mismo prefijo que el registro remoto.

El usuario debe reunificar las cuatro partes, verificar el SHA-256, extraer el código completo, conservar sus secretos y credenciales fuera del repositorio, actualizar manualmente GitHub y realizar su despliegue de Netlify. No se han hecho commit, push, merge, PR ni despliegue de Netlify. No se ha publicado contenido Social/Instagram, cobrado, alterado alumnos ni aprobado solicitudes durante estas pruebas. La integración Instagram previa permanece incluida; no se ha vuelto a probar ni modificado su estado de App Review en esta intervención.
