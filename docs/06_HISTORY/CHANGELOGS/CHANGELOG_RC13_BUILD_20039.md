# KOMBAX RC13 · Build 20039

## Manual interactivo del perfil Miembro

- Se crea un manual interactivo específico para `rol = alumno`, separado del manual operativo del Club.
- El manual del Miembro contiene 13 temas centrados únicamente en funciones realmente disponibles para el alumno.
- Se añaden accesos rápidos a Horarios, Cuotas, Mi perfil y Notificaciones.
- La navegación del alumno muestra `Mi manual` mientras que los roles de gestión conservan `Manual interactivo`.
- Social y Showcase aparecen solo cuando sus feature flags están activas.
- Se conservan Condiciones, Privacidad, consentimientos y eliminación de cuenta debajo del manual.
- No se añaden manuales provisionales para Competidor, Federación ni Marca; la selección de catálogo queda centralizada para futuras extensiones.

## Seguridad y regresión

- El manual Miembro no contiene rutas administrativas (Alumnos, Equipo, Configuración, Ámbitos, Archivo, etc.).
- Buscador, filtros, modales y deep links operan contra el catálogo activo y no contra un catálogo hardcodeado.
- La regresión 20038 se hace compatible con builds posteriores sin rebajar sus comprobaciones funcionales.
- Se añade `test-kombax-20039-member-manual.mjs` a la suite principal.

## Release

- Web/PWA/Android: build 20039.
- Sin cambios de schema ni migraciones Supabase.
- Firebase presente.
- Firma release JKS sigue pendiente de integración local.
