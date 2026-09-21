Actúa como arquitecto principal, auditor técnico, responsable QA y responsable de release de KOMBAX.

BASE DE TRABAJO OBLIGATORIA
Trabaja exclusivamente sobre la última base completa y validada:

KOMBAX R71 · build 20122 — SIDEBAR PRODUCT ACCORDIONS READY

La implementación debe ser estrictamente acumulativa. No se puede perder ninguna funcionalidad existente, alterar precios no relacionados, romper permisos, eliminar documentación histórica, degradar Android/PWA/PC ni modificar reglas previamente cerradas salvo donde este prompt lo ordene expresamente.

OBJETIVO DE LA REVISIÓN
Crear la siguiente revisión mayor de KOMBAX para dejar preparada una base ideal de fase piloto/congelación que incorpore conjuntamente:

1. Ampliaciones de catálogo Showcase en bloques de +25 productos.
2. Preservación permanente de referencias, reputación y reseñas de productos.
3. Valoraciones y reseñas multimedia en KOMBAX Showcase.
4. Compra verificada para reseñas asociadas a pedidos reales.
5. Comunidad, comentarios y valoraciones en KOMBAX Events.
6. Distintivo de asistente verificado cuando exista Ticketing + check-in válido.
7. Actualización integral de precios, contratos, textos legales, capacidades, tablas, documentación y UI.
8. QA completa PC/PWA/Android.
9. ZIP completo autosuficiente y congelable como nueva única base de trabajo.

# ================================================== A. AMPLIACIÓN DE CATÁLOGO SHOWCASE

Los límites actuales dejan de interpretarse como límites destructivos.

Capacidad incluida actual que debe conservarse:

Club Básico:

- 15 productos incluidos.

Club Premium:

- 25 productos incluidos.

Club Enterprise:

- catálogo ilimitado.

Brand Start:

- 25 productos incluidos.

Brand Growth:

- 100 productos incluidos.

Brand Enterprise:

- catálogo ilimitado.

Federación:

- sin Showcase/Commerce salvo reglas futuras expresas.

Crear nuevo servicio:

AMPLIACIÓN DE CATÁLOGO SHOWCASE

- +25 productos.
- Precio objetivo inicial: 8 € / 30 días.
- Renovable.
- Acumulable.
- Puede contratarse varias veces.
- Cada bloque suma 25 slots adicionales activos.
- No habilita Commerce por sí mismo.
- No modifica la comisión de plataforma.
- No sustituye al plan principal.
- No afecta a Enterprise, que sigue siendo ilimitado.

Ejemplos:

Club Básico:
15 incluidos
+1 bloque = 40
+2 bloques = 65
+3 bloques = 90

Club Premium:
25 incluidos
+1 bloque = 50
+2 bloques = 75
+3 bloques = 100

Brand Start:
25 incluidos + ampliaciones.

Brand Growth:
100 incluidos + ampliaciones.

Enterprise:
ilimitado; no necesita ampliaciones.

Debe existir una recomendación contextual de upgrade a Enterprise cuando económicamente empiece a resultar más interesante, pero nunca un bloqueo artificial.

# ================================================== B. PRESERVACIÓN DE PRODUCTOS Y REPUTACIÓN

Nunca eliminar automáticamente una referencia porque el cliente haya perdido capacidad de catálogo.

Crear estados claros:

- activo
- borrador
- archivado
- fuera\_de\_capacidad
- retirado, si ya existe semántica compatible

Un producto archivado:

- no consume slot activo;
- conserva URL/referencia;
- conserva reseñas;
- conserva puntuación;
- conserva fotografías;
- conserva ventas históricas;
- conserva estadísticas;
- conserva trazabilidad.

Si vence una ampliación y el vendedor supera su capacidad:

NO borrar productos.

Los productos excedentes deben entrar en un flujo de resolución seguro:

- renovar ampliación;
- contratar otro bloque;
- subir de plan;
- elegir qué productos mantener activos;
- archivar productos voluntariamente.

Nunca destruir reputación o historial.

# ================================================== C. SHOWCASE — VALORACIONES Y RESEÑAS

Incorporar valoraciones de producto tipo marketplace.

Por producto:

- puntuación media de 1 a 5 estrellas;
- número total de reseñas;
- distribución por estrellas;
- texto;
- fotografías;
- edición de la propia reseña;
- retirada de la propia reseña;
- fecha;
- usuario;
- estado de moderación;
- respuesta del vendedor.

Filtros:

- más recientes;
- mejor valoradas;
- peor valoradas;
- con fotos;
- compra verificada.

Compra verificada:

Mostrar distintivo:

“Compra verificada”

únicamente cuando KOMBAX pueda demostrar que ese usuario tiene un pedido legítimo de ese producto que cumple la condición definida para reseñar, preferentemente pedido entregado.

Evitar:

- reseñas duplicadas abusivas;
- varias reseñas por el mismo pedido/producto sin justificación;
- manipulación por parte del vendedor;
- compra de verificación.

El vendedor:

- puede responder;
- puede reportar;
- no puede modificar la reseña;
- no puede borrar una crítica legítima.

Crear en Mi Showcase:

VALORACIONES

con:

- puntuación media del catálogo;
- número de reseñas;
- porcentaje verificadas;
- reseñas recientes;
- productos mejor valorados;
- productos peor valorados;
- evolución;
- respuestas;
- reportes.

# ================================================== D. KOMBAX EVENTS — COMUNIDAD Y VALORACIONES

Añadir una capa social vinculada al evento concreto.

Antes del evento:

- comentarios;
- respuestas;
- reacciones;
- preguntas;
- Me interesa;
- compartir.

Durante/después:

- comentarios;
- respuestas;
- fotografías;
- vídeos cortos, si la arquitectura multimedia actual lo soporta;
- valoración del evento;
- contenido de asistentes.

Crear distintivo:

“Asistió al evento”

solo cuando exista evidencia válida:

- entrada legítima;
- QR válido;
- check-in registrado.

No exigir asistencia para comentar públicamente.

Distinguir:

Comentario público

de

Asistente verificado.

Permitir valoración general del evento, preferentemente priorizando o diferenciando valoraciones de asistentes verificados.

Ejemplo:

4,8 ★
126 valoraciones de asistentes

# ================================================== E. CENTRO DEL EVENTO

En:

Mis Eventos → Centro del evento

crear sección:

COMUNIDAD Y VALORACIONES

Debe incluir:

- puntuación media;
- número de valoraciones;
- valoraciones de asistentes verificados;
- comentarios;
- respuestas;
- fotografías;
- vídeos;
- interacción;
- contenido reportado;
- moderación;
- estadísticas de comunidad.

Organizador:

- puede responder;
- puede reportar;
- no puede borrar libremente críticas legítimas.

# ================================================== F. MODERACIÓN

Reutilizar cuando sea posible la arquitectura existente de KOMBAX Social/moderación.

Incluir:

- reportar contenido;
- ocultación/moderación por plataforma cuando proceda;
- estados de revisión;
- trazabilidad;
- protección anti-spam;
- límites razonables;
- control de multimedia;
- privacidad;
- protección de menores.

No crear mecanismos que permitan comprar reputación.

# ================================================== G. PRECIOS Y PLANES

Actualizar TODA aparición relevante de planes y límites.

Incluir el nuevo servicio:

Ampliación Showcase +25 productos
8 € / 30 días

Debe figurar donde corresponda en:

- páginas públicas de precios;
- comparativas de planes;
- Seller Center;
- Plan y servicios;
- flujos de activación;
- textos informativos;
- configuración comercial;
- runtime comercial;
- documentación técnica;
- documentación comercial;
- contratos;
- anexos;
- FAQs;
- capacidades;
- matrices;
- pruebas.

Mantener:

Club Básico:
15 productos incluidos.

Club Premium:
25 incluidos.

Brand Start:
25 incluidos.

Brand Growth:
100 incluidos.

Enterprise:
ilimitado.

Commerce del Club Básico:
12 € / 30 días.

No confundir ampliación de catálogo con Commerce.

# ================================================== H. CONTRATOS Y LEGAL

Auditar todos los contratos actuales relacionados con:

- KOMBAX Showcase;
- Commerce;
- Seller Center;
- condiciones de vendedor;
- productos;
- eventos;
- Ticketing;
- contenido multimedia;
- comunidad;
- valoraciones;
- moderación.

Actualizar cuando corresponda para cubrir:

- reseñas de usuarios;
- fotografías de reseñas;
- contenido generado por usuarios;
- respuestas del vendedor;
- moderación;
- conservación histórica de referencias;
- productos archivados;
- ampliaciones de catálogo;
- renovación/caducidad de add-ons;
- tratamiento de reputación;
- contenido de Events;
- asistentes verificados.

No afirmar revisión jurídica final si no existe.

Mantener claramente marcado cualquier documento que requiera revisión jurídica antes de producción pública.

# ================================================== I. BACKEND

Auditar Supabase antes de modificar.

Preferir reutilización sobre duplicación.

Crear solo lo necesario para:

- catálogo ampliable;
- add-ons acumulables;
- slots;
- estado archivado/fuera de capacidad;
- reseñas;
- multimedia de reseñas;
- compra verificada;
- respuestas de vendedores;
- valoraciones de eventos;
- comentarios;
- asistente verificado;
- moderación;
- métricas.

Aplicar:

- RLS;
- ownership;
- permisos;
- auth;
- SECURITY DEFINER seguro cuando sea necesario;
- search\_path explícito;
- idempotencia;
- índices;
- restricciones;
- protección multi-tenant;
- auditoría.

No exponer datos privados.

# ================================================== J. UI / UX

KOMBAX Showcase:

Ficha de producto:

- puntuación;
- número de reseñas;
- estrellas;
- galería de reseñas;
- escribir reseña;
- compra verificada;
- respuesta del vendedor.

Mi Showcase:

- Productos;
- Valoraciones;
- Estadísticas;
- Cuenta vendedor;
- resto de secciones actuales.

Mostrar capacidad:

25 / 50 productos activos

Ejemplo:

“25 incluidos + 25 adicionales”

CTA:

“Ampliar catálogo +25 · 8 €/30 días”

KOMBAX Events:

Ficha de evento:

- Comunidad;
- comentarios;
- asistentes verificados;
- valoración;
- fotos/vídeos.

Centro del evento:

- Comunidad y valoraciones.

Mantener diseño oscuro premium y estética propia de cada módulo.

# ================================================== K. ANDROID / PWA / PC

Todo cambio web debe sincronizarse con:

- dist;
- Android embedded web assets;
- service worker/cache;
- versionado;
- UA;
- build;
- rutas;
- recursos.

No afirmar APK/AAB generado si no puede compilarse realmente.

# ================================================== L. QA

Ejecutar regresión completa existente y añadir nuevas baterías.

Como mínimo verificar:

CATÁLOGO:

- límite incluido;
- +25;
- múltiples bloques;
- caducidad;
- no borrado;
- archivado;
- reactivación;
- Enterprise ilimitado.

RESEÑAS:

- crear;
- editar;
- retirar;
- estrellas;
- fotos;
- compra verificada;
- no verificada;
- respuesta vendedor;
- reportar;
- permisos.

EVENTS:

- comentar;
- responder;
- valorar;
- multimedia;
- asistente verificado;
- usuario no asistente;
- organizador;
- moderación.

PERMISOS:

- espectador;
- alumno;
- menor;
- club;
- marca;
- organizador;
- administrador.

REGRESIÓN:

- precios;
- Commerce;
- Seller Center;
- Mis Eventos;
- Ticketing;
- Stripe Connect;
- identidad;
- Social;
- navegación;
- acordeones.

# ================================================== M. AUDITORÍA PREVIA OBLIGATORIA

Antes de implementar:

1. Inventariar todos los archivos y RPC relacionados.
2. Identificar límites actuales.
3. Identificar todas las tablas de precio.
4. Identificar contratos.
5. Identificar capacidades duplicadas o hardcoded.
6. Identificar riesgos de regresión.
7. Crear informe de auditoría.
8. Crear plan de implementación.
9. Solo entonces modificar.

# ================================================== N. VERSIONADO

Partir de:

R71 / build 20122

Crear siguiente versión coherente:

R72 / build 20123

salvo impedimento técnico documentado.

# ================================================== O. ENTREGA FINAL

Entregar un ZIP COMPLETO, no un parche.

Debe contener:

- proyecto completo;
- web;
- dist;
- Android;
- Supabase;
- migraciones;
- funciones;
- tests;
- documentación histórica;
- documentación nueva;
- informe de auditoría;
- plan;
- informe final;
- QA;
- rollback;
- estado Supabase;
- changed files;
- manifest SHA-256;
- checksum del ZIP.

El ZIP final debe ser:

- autosuficiente;
- verificable;
- reconstruible;
- acumulativo;
- congelable;
- apto como única base para siguiente fase;
- preparado para piloto controlado;
- sin secretos;
- sin keystores;
- sin .env reales.

No declarar producción-ready si quedan:

- revisión jurídica;
- QA manual autenticada;
- Stripe E2E;
- firma Android;
- Google Play;
- Netlify;
- advisors críticos;
- validaciones externas.

No desplegar frontend.
No hacer push GitHub.
No publicar Google Play.
No activar SaaS Billing.