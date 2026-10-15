# Informe R272 · 15 de octubre de 2026

## Alcance entregado

R272 parte del ZIP R271 validado. Conserva las funcionalidades acumuladas de identidades, álbumes, productos, moderación, altas piloto, familias y finanzas. Esta intervención cambia la presentación de navegación y añade la ayuda; no sustituye la arquitectura ni concede permisos de negocio nuevos.

El menú Club pasa de una lista extensa de destinos a siete áreas: Inicio, Personas, Entrenamiento, Finanzas, Mi comunidad, Material y Administración. Las rutas autorizadas originales siguen siendo el catálogo de permisos y conservan sus enlaces. Las secciones numerosas usan un selector dentro del área; las cortas, botones. Social, Events, Showcase y Recursos mantienen sus accesos existentes.

La ayuda usa 41 tareas extraídas de las guías existentes y 26 procedimientos añadidos o detallados, incluidas finanzas y exploración. Ofrece opciones relacionadas, no ejecuta operaciones. No es un entrenamiento nuevo del modelo: es una selección de documentación proporcionada a la IA al consultar expresamente.

## Regla final de visibilidad

- Alta, acceso inicial y creación de identidades: guías para todos, sin IA.
- Club: ayuda para el equipo de gestión según el rol. Dirección, coordinación, secretaría y economía pueden solicitar IA si el backend confirma derecho, cupo y créditos. Monitor y comunicación tienen guías; no se amplía su acceso al presupuesto administrativo.
- Marca/Federación: guías; IA solo si tienen derecho comercial o piloto vigente y saldo/cupo suficiente.
- Alumno, miembro, familia, espectador, competidor y profesional: widget oculto en su espacio habitual; al crear una nueva identidad vuelve a mostrarse la ayuda inicial sin IA.
- Sesiones Owner de soporte y pasos obligatorios pendientes no obtienen el presupuesto IA del cliente mediante esta ayuda.

## Conversación

El widget vive fuera del contenedor que se reemplaza al cambiar de pantalla. La conversación permanece al navegar dentro de la misma identidad, cerrar/reabrir la ayuda o abrir el destino de una guía. La clave incluye cuenta, identidad y rol. Cambiarlos invalida consultas pendientes y reinicia el texto para evitar mezclas. Una recarga completa reinicia el transcript visible; no se ha implementado historial persistente de la ayuda.

## Consumo y privacidad

Consultar guías no invoca al proveedor, no crea casos y no reserva asistencias. La IA exige pulsar Consultar con IA; después reutiliza la misma conversación/caso y la contabilidad existente de Assist/Migrations. No se crean créditos ni se modifican precios.

Cupos leídos de Supabase: Club Básico 10 asistencias/mes, Club Premium 30, Federación 30 y KOMBAX Pro 100. Son casos/asistencias, no mensajes. El límite vigente es 12 turnos por caso. Para esta ayuda, salida máxima min(600, límite del plan): Básico 500. Entrada máxima 1500 caracteres. Presupuestos, saldos y medición del proveedor continúan protegidos por el backend existente.

La consulta de ayuda recibe solo documentación publicada, pregunta, idioma y tipo/nombre público de la entidad. No serializa alumnos, saldos, datos bancarios, archivos ni la conversación privada de Assist. No analiza adjuntos, inicia Stripe ni publica contenido. El contexto operativo de Assist y los flujos de Migrations de la versión desplegada v20 se conservan para sus canales originales.

Las pruebas no han hecho llamadas reales al modelo: latencia y calidad de generación real siguen pendientes de una consulta autorizada. Se ha verificado con proveedor simulado el payload, los límites, los reintentos y el registro de consumo oficial. No se inventa consumo cuando el proveedor no devuelve medición.

## Supabase real

- Migración aplicada: usage_help_paid_entitlement_r272; registro remoto 20261015172633. Fuente local: supabase/migrations/20261015172350_usage_help_paid_entitlement_r272.sql.
- Nuevo RPC: app_kombax_usage_help_access_r272(text,text). Comprueba usuario, organización accesible, ticket propio y derecho comercial/prueba/piloto antes de cualquier reserva de esta ayuda. No modifica planes, saldos ni datos.
- Función desplegada: kombax-assist-r38, versión 21, ACTIVE, verify_jwt=true. Archivos desplegados comparados exactamente con el paquete.
- Dependencias: _shared/usage-help-guide.ts, usage-help-catalog.json y usage-help-knowledge.js; deno.json incluido.
- Sin nuevos secrets ni cambios en los valores existentes. Se conservó copia de la versión 20 en edge-before para revisión/recuperación.
- Estado real: endpoint de salud 200 y configurado; POST sin sesión 401. Esto verifica carga y protección, no una inferencia IA real.
- SQL real en transacciones de comprobación: 3 clubes piloto registrados autorizados; 1 Marca y 1 Federación actuales autorizadas; 2 Competidores rechazados; 5 casos alumno/familia rechazados; organización ajena y ticket inexistente rechazados. Las pruebas no guardaron cambios en esos registros.
- Anon no tiene EXECUTE del nuevo RPC. Authenticated sí, con controles internos de propiedad y acceso; sin sesión devuelve ai_allowed=false.
- Logs de la función, ventana 17:30–17:36 UTC: arranque y cierre normales, sin nivel error observado en esa ventana. No equivale a una auditoría histórica de todos los logs.

## Advisors

No se crearon tablas ni políticas RLS. El RPC usa SECURITY DEFINER deliberadamente para consultar las autorizaciones privadas y devuelve únicamente un booleano tras comprobar usuario/entidad. El advisor lo señala como función ejecutable por authenticated: aviso revisado y conservado, no ocultado. Anon está revocado y search_path está vacío.

La revisión global sigue mostrando avisos de funciones históricas, RLS sin políticas, protección de contraseñas filtradas desactivada y un índice duplicado. No se presentan como resueltos ni como causados por esta entrega. Performance no señala la nueva función. Referencias: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable y https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.

## Pruebas aisladas y navegador

- test-navigation-help-r272.mjs: 46 comprobaciones, áreas, permisos, coincidencia de preguntas, aislamiento, onboarding y visibilidad.
- test-usage-help-handler-r272.mjs: 32 comprobaciones con handler real y proveedor simulado; usuario, plan gratuito, cupo agotado, límites, privacidad, archivos rechazados, medición y reintentos.
- Las regresiones previas de contexto Assist fix16/fix18 continúan en el gate.
- Navegador: aplicación real local para la presentación inicial; entorno con datos simulados y componentes reales para Club/Marca/Federación/alumno/competidor, navegación de comunidad, ayuda inicial sobre formularios, propuestas financieras, apertura de destino, cambio de identidad y conservación del transcript al navegar/cerrar/reabrir.
- Móvil 390×844: ancho sin desbordamiento horizontal y panel dentro del viewport; vista de escritorio y cierre de sesión conservados. No se probaron todos los teléfonos físicos.
- No se hizo acceso real a cuentas de testers para completar altas, pagos o publicar en Social/Events/Showcase. La regresión de esos módulos es la de los scripts acumulados, no una prueba manual exhaustiva en producción.

## Build y baseline

release-legal-gate: PASS. release-netlify-r104-3: 121 PASS, 3 P2 heredados, 0 fallos nuevos. Compatibilidad: 395 archivos JavaScript y 964 importaciones locales revisadas para Linux. Build: 663 archivos; web = dist = recursos Android.

Los tres P2 conservados son i18n-r79-full-product-audit, test-kombax-20130-r79-i18n-phases-6-10 e i18n-runtime-copy-audit. La suite estricta completa sigue fallando por ellos; no se modificó el baseline para ocultarlos. Etiquetas nuevas integradas en localización, con fallback inglés según política piloto. Las guías detalladas tienen fuente en español; no se afirma traducción nativa completa de las 67 tareas a los ocho idiomas.

## Entrega y pasos pendientes

La comprobación externa COMPROBACION_R272.json contiene archivos añadidos/modificados, SHA-256, CRC y resultado de ejecutar el reunificador CMD. Todos los archivos del ZIP R271 se conservan, usando sus versiones actualizadas cuando procede. No se incluyen dependencias node_modules ni claves de firma nuevas.

El frontend R272 requiere tu actualización manual de GitHub/Netlify para aparecer en la web pública. El backend ya está activo. No se hicieron operaciones Git ni despliegues Netlify/Play. No se generó APK/AAB; solo se sincronizaron recursos. La integración Instagram acumulada se conserva: esta intervención no revalida OAuth, App Review ni publicaciones reales.
