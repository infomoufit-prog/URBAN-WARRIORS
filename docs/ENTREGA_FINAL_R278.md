# R278 · Conocimiento maestro y administración Owner

Fecha: 16 de octubre de 2026. Base acumulativa: R277 conservada. No se ha hecho commit, push, merge, PR ni despliegue en Netlify. No se ha compilado una APK/AAB.

## Ayuda y conocimiento

- Guía maestra de 112 temas: 67 áreas principales y 45 casos especializados. Se conservan las 200 preguntas frecuentes de R277.
- Inventario estático de 72 módulos de interfaz y sus 198 exportaciones; inventario ampliado de 395 archivos, 1.338 funciones con nombre y 551 referencias a RPC. Es trazabilidad de código, no una afirmación de pruebas completas de todas las operaciones en producción.
- Familias con varios hijos, varias disciplinas y grupos, cuotas múltiples, pagos parciales, tarifas, antigüedad, recibos, equipos, permisos, fotos/banner/álbum, Social, Events, Showcase, Instagram, acreditaciones, perfiles y servicios.
- Ayuda distingue significado, utilidad, comparación, procedimiento y fallo. Reconoce fórmulas naturales de introducción y faltas leves, mantiene el tema en repreguntas y recibe requisitos y comprobaciones de las fuentes seleccionadas.
- Se priorizan tareas distintas al recuperar información, evitando ocupar el contexto con varias versiones de un mismo tema. Las fuentes se limitan a 7.000 caracteres y los límites de IA vigentes se conservan.
- No confunde una causa posible con una causa confirmada; no dispone de acceso libre a datos de alumnos ni puede ejecutar cobros o aprobaciones. Assist conserva su finalidad operativa autorizada y Migrations la importación.
- Conocimiento privado de Owner separado del catálogo de ayuda público. Las propuestas de aprendizaje requieren revisión; las respuestas anteriores no se convierten automáticamente en hechos.
- La ampliación es conocimiento consultado por el asistente, no un reentrenamiento de los pesos del modelo. No se garantiza una respuesta correcta a cualquier pregunta; cuando falte evidencia debe reconocerlo y orientar sin inventar.

Guía: `docs/GUIA_MAESTRA_KOMBAX_R278.md`. Catálogos: `usage-help-master-r278.json`, `usage-help-supplements-r278.json` y catálogo de navegador saneado. Generadores y comprobaciones de fuentes incluidos.

## Reparación de Owner aplicada en Supabase

Migración aplicada: `20261016175613_owner_knowledge_reports_r278.sql`.

Se corrigió el agregado de créditos decimales que fallaba al convertir un valor como `1.378` en entero. También la restricción de notificaciones que impedía registrar correctamente fallos de agentes y avisos de verificación. Se conservaron RLS, destinatario obligatorio y los permisos existentes.

Siete turnos antiguos bloqueados se marcaron como fallidos con motivo de reconciliación, sin simular respuestas terminadas ni repetir sus acciones. La comprobación real de Pilot Intelligence después de la reparación respondió con datos del piloto; no ejecutó acciones de negocio.

RPC nueva `app_kombax_owner_insights_r278`: exige usuario autenticado y sesión administrativa Owner válida. Agrega datos; no entrega listados de correos, datos de alumnos ni listas para campañas. Auxiliar en esquema privado, sin acceso directo concedido a usuarios.

Funciones activas y contenido leído de nuevo, coincidente con las fuentes enviadas:

| Función | Versión |
| --- | --- |
| kombax-owner-agents-r105 | 14 |
| kombax-owner-report-r114 | 12 |
| kombax-assist-r38 | 34 |
| kombax-usage-help | 11 |

Las cuatro mantienen verificación JWT. No se han cambiado claves, modelos ni tarifas. El código conserva la comprobación de incertidumbre antes de aprobar verificaciones.

## Informes y datos

Siete tipos: Ejecutivo, Piloto, Altas y activación, Marketing y adopción, Soporte e incidencias, IA y conocimiento, Operaciones y verificaciones. Selector, vista de datos y CSV agregado en la interfaz nueva de Owner.

Incluyen cuentas e identidades, estados, altas del periodo, cohortes de registro, publicaciones, eventos, verificaciones, actividad de agentes y conocimiento revisado cuando la fuente lo permite. Separan total actual, registros del periodo y ausencia de datos. Las cohortes no representan retención ni atribución.

No se inventan CAC, LTV, MRR, churn, ROI ni clics. No hay un registro disponible de consentimiento de marketing y no se generan listas de destinatarios ni campañas.

PDF en almacenamiento privado, URL temporal de 600 segundos y SHA-256. Se revisaron siete PDF con datos de prueba usando la biblioteca real: Ejecutivo de seis páginas y los otros seis tipos de una página, sin páginas iniciales en blanco.

La generación de un nuevo PDF de marketing con datos reales sigue pendiente: la sesión administrativa caducó; se abrió el acceso local, que seguía mostrando el formulario. No se ha eludido la autenticación ni afirmado que ese PDF real esté generado.

## Interfaz Owner

Enter envía; Mayús+Enter permite otra línea. Un turno nuevo no reemplaza por error un mensaje pendiente anterior. Al fallar se conserva la pregunta y los adjuntos/contexto para reintentar. El informe se genera cuando se pide expresamente; una frase como «no crees listas de contactos» no cancela una solicitud de PDF.

## Pruebas y límites

- Conocimiento: 1.299 comprobaciones de fuentes, permisos, contexto limitado, preguntas naturales, aislamiento de Owner y recuperación de temas.
- Informes: 42 comprobaciones con generación PDF real y servicios externos simulados, sin llamadas a producción.
- Owner: 17 comprobaciones de controlador y 17 de datos/migración con base aislada.
- Navegador local real: apertura de KOMBAX y ayuda sin sesión, pregunta formulada con lenguaje cotidiano, repregunta que conserva el tema, acceso Owner protegido. Escenario de club simulado identificado como tal y sin gasto real.
- Revisión visual de los siete PDF de prueba y sus doce páginas.
- Regresión acumulativa: consultar `VALIDACION_R278.md` para el resultado final.

Los advisors mantienen deuda previa: 242 avisos informativos de RLS sin políticas, 61 funciones SECURITY DEFINER accesibles a anon, 663 a autenticados y protección de contraseñas filtradas pendiente. El aviso adicional de autenticados corresponde al RPC Owner nuevo, protegido internamente. Rendimiento: 259 claves foráneas sin índice, 297 índices sin uso y un índice duplicado. Estos avisos no se han ocultado ni se ha aplicado una reforma global ajena a este cambio.

## Actualización manual

El backend descrito ya está aplicado en Supabase. Las nuevas guías locales, controles de chat y selector de informes requieren actualizar manualmente el frontend. Se mantiene el catálogo comercial y el bloqueo de contratación pública nueva de Marca/Federación durante el piloto, sin habilitar cobros recurrentes.

El acceso local usa el backend real: `http://127.0.0.1:4196/`. Owner: `http://127.0.0.1:4196/admin`. Las pruebas de contenido o administración no autorizan borrar datos, publicar o ejecutar cobros reales.
