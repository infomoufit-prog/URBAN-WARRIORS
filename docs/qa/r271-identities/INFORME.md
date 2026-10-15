# Informe R271 — identidades Social

## Resultado
Implementación compatible aplicada a reglas generales, no a una lista fija de correos.
Persona: vista pública común para Miembro, Competidor, Profesional y Espectador. Club, Marca, Federación y Media siguen independientes.
Ninguna autorización, verificación, propiedad, suscripción o cuenta Stripe se ha transferido por agrupar la presentación.
Los IDs anteriores se conservan como variantes: publicaciones, álbumes y conversaciones mantienen su procedencia.
El primer perfil personal público activo por fecha de creación representa la vista común. Los enlaces a las demás variantes se resuelven en el frontend actualizado.
No se han eliminado perfiles ni documentos.

## Correcciones
- Catálogo de perfiles gestionables independiente del permiso para publicar.
- Interacción de Miembro en su contexto Club separada de publicación, sin ampliar su autoridad para representar al Club.
- Selección común con preferencias por usuario, club y rol elegido. Se descartan actores no disponibles.
- Selector público agrupa facetas personales y conserva entidades separadas.
- No se cambia a otra entidad para publicar. Una faceta autorizada de la misma persona puede representar la publicación personal.
- Directorio general presenta una tarjeta por persona, manteniendo búsquedas que coincidan con sus facetas.
- Vista pública combina actividad y álbum públicos que las funciones anteriores permitan leer; la paginación mantiene IDs/cursor.
- Disponibilidad de Competidor y Profesional, afiliación Miembro y documentos se muestran por capacidad. Su gestión conserva la validación anterior.
- Red personal agrega relaciones de variantes autorizadas. Conversaciones de un perfil personal pueden incluir sus variantes, conservando interlocutor y autor originales.
- Instagram utiliza una faceta autorizada de la misma persona. No se trasladan conexiones ni tokens entre IDs y no se hizo una prueba OAuth real en esta intervención.
- Corrección de ajuste del selector en móvil para nombres de capacidades largos.

## Supabase real
Migración local: supabase/migrations/20261014221616_social_identity_resolution_r271.sql.
Migración aplicada: social_identity_resolution_r271, versión remota 20261014223118.
Nuevos endpoints:
app_kombax_social_identity_catalog_r271(uuid,boolean)
app_kombax_social_identity_bundle_r271(uuid)
app_kombax_social_directory_r271(text,integer)
Helpers privados revocados para anon/authenticated.
Las funciones públicas exigen sesión y usan las comprobaciones históricas de gestión, acceso público, red y publicación.
Se revisaron advisors. Los tres endpoints aparecen en el aviso genérico de SECURITY DEFINER ejecutable por authenticated: es intencionado, con search_path vacío y autorización explícita. No hay acceso anon a ellos. Persisten avisos anteriores del proyecto; esta entrega no es un saneamiento completo de todos los advisors.

## Pruebas
1. SQL aislado PGlite + selección JavaScript: 37 comprobaciones. Incluyen persona con facetas, entidades separadas, espectador, perfil pendiente, otra persona, contexto de Club, enlace antiguo, variante bloqueada y grants.
2. Supabase real: consultas con contexto de propietarios existentes, dentro de transacción revertida. El caso Miembro+Competidor tiene dos variantes y un grupo personal; organizaciones conservan sus grupos. No equivale a iniciar sesión como cada usuario real.
3. Navegador local con módulos reales y datos simulados: tres opciones Persona/Marca/Club; Marca pendiente sin botón de publicación; Club autorizado con botón; perfil común con Competidor verificado y Profesional pendiente; disponibilidad por capacidad. Ancho 390 y escritorio. El texto largo del selector pasó de desbordamiento amplio a encajar; queda el borde visual de 3 px del documento de pruebas, sin texto desbordado. No se probaron publicaciones reales ni carga de archivos reales en este navegador.
4. Compilación y regresiones finales: ver RELEASE_BUILD.log en esta carpeta. No se amplió la lista de incidencias de traducción heredadas para ocultar errores nuevos.
5. No APK/AAB compilada, no publicación Instagram, no pagos, no correos reales, no commit/push/PR ni deploy Netlify.

## Compatibilidad y límites
Se conserva la base R270 acumulativa y los fixes de backend posteriores incluidos en el paquete.
Agrupación de presentación, no fusión física de identidades. Las cuotas, verificaciones, servicios y conexiones continúan verificándose con el actor de origen.
Media permanece independiente porque el modelo actual no distingue creador personal de empresa de medios; no se infiere esa condición por nombre/correo.
Los menores y alumnos de familias con otros propietarios no se agrupan con el tutor.
Las funciones nuevas están operativas en Supabase; la experiencia visual nueva requiere que el usuario actualice el frontend.
Los escenarios de Profesional/Espectador sin cuentas reales se verificaron con fixtures, no con usuarios de producción.
Falta validación final del usuario en la web desplegada con su sesión, especialmente OAuth real de Instagram; no se afirma realizada.
Tres incidencias de traducción heredadas permanecen; suite estricta no se declara completamente verde.

## Migraciones ya aplicadas — no repetir indiscriminadamente
meta_instagram_member_owner_r270: 20261014214107
social_network_publication_capabilities_r270: 20261014215532
social_legacy_publication_capabilities_r270: 20261014215740
social_workspace_publication_capabilities_r270: 20261014220400
social_identity_resolution_r271: 20261014223118
Los archivos locales creados por CLI conservan su fecha de preparación. No ejecutar db push de todo el historial sin reconciliar antes versiones locales y remotas.

## Archivos de esta intervención
web/js/core/social-identity-resolution.js (nuevo)
web/js/core/identity-context.js
web/js/core/context-isolation-20083.js
web/js/core/repositories.js
web/js/modules/kombax-social.js
web/js/modules/public-profile.js
web/css/kombax-social.css
web/js/i18n/r270-pilot-copy.js
scripts/test-social-identities-r271.mjs (nuevo)
package.json
migración R271, documentación y copias generadas dist/Android.

## Pasos posteriores
Reunificar ZIP, comprobar SHA-256, extraer y actualizar el repositorio manualmente, desplegar frontend y probar con cuenta real.
No volver a aplicar migraciones ya registradas.
Conservar copia de la carpeta anterior. ROLLBACK_R271.sql documenta las funciones previas y retirada de endpoints nuevos si se necesita revertir; no se ejecutó.

## Ampliaciones posteriores de esta entrega

Vistas de catálogo: `CATALOGOS.md` y `CATALOG_BROWSER.json`.
Retirada y eliminación: `ELIMINACION.md`, 15 comprobaciones aisladas y endpoint real probado en transacción revertida.
Contexto MOUFIT DEMO: `MOUFIT_CONTEXTO.md`, 19 comprobaciones aisladas y publicación real transaccional revertida.

Migraciones adicionales registradas: `social_album_shared_media_r271` (`20261014231852`) y `social_club_status_context_r271` (`20261014233432`). No ejecutarlas de nuevo. MOUFIT demo no consume plaza piloto ni está marcado como documentalmente verificado.

La revisión final restauró la codificación UTF-8 de repositories.js. Se conserva el control de frases exactas de la deuda de traducción; no se amplió el baseline para aceptar texto nuevo.

## Cierre final de esta entrega

Compilación y regresión final: **118 suites PASS, 3 P2 de traducción heredados, 0 fallos nuevos**, salida 0. Compatibilidad: 390 archivos JavaScript, 950 importaciones locales verificadas para Linux, build 20178 y web/dist/Android idénticos. Evidencia completa: `FINAL_RELEASE_BUILD.log`. Las referencias anteriores de este informe a 116 PASS describen el corte previo a la ampliación de álbum y MOUFIT. La suite estricta npm test sigue señalando las tres incidencias conocidas.

No se ha compilado una APK/AAB nueva, no se ha hecho push/commit/merge/PR ni se ha desplegado Netlify. Las pruebas SQL transaccionales se revirtieron. La integración Instagram acumulada sigue requiriendo su prueba completa con una cuenta profesional autorizada; esta entrega no afirma una publicación real en Instagram.
