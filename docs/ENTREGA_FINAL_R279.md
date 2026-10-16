# Entrega R279 · 17 de octubre de 2026

Acumulativo completo sobre el ZIP R278, conservado intacto. Incluye todo el conocimiento maestro, ayuda y reparación Owner descritos en `ENTREGA_FINAL_R278.md`, además del cambio visual solicitado después de su entrega.

## Cambio nuevo

- Asset principal `gateway-kombax-community.webp` compartido como fondo administrativo predeterminado de los perfiles gestionados: Competidor, Profesional, Marca, Federación, Media y Espectador.
- Club: mismo asset en el inicio de gestión, también en los roles del equipo que utilizan ese panel.
- Los banners personalizados mantienen prioridad. No se sustituyen fotos o banners públicos de las cuentas.
- Encuadre superior panorámico del fondo predeterminado para mostrar los peleadores y evitar presentar el cartel completo. La regla no altera el encuadre de un banner personalizado.
- Archivos principales: `web/js/core/workspace-visuals.js`, `web/js/modules/profile-administration.js`, `web/js/modules/managed-profile-hub.js`, `web/js/modules/dashboard-catalog.js`, `web/css/kombax-ui-stabilization-r60.css`. Copias generadas en dist y recursos Android.

Las vistas locales de Competidor, Federación, Profesional y perfil público Social se abrieron usando componentes reales y datos ficticios. Los servidores de vista previa están fuera del proyecto distribuido. No se crean cuentas, credenciales, fechas ni publicaciones de ejemplo en Supabase.

## Validación

Se ejecuta de nuevo la cadena completa de entrega antes de empaquetar. El registro de salida se incluye junto al informe de descarga. La suite estricta conserva las tres incidencias de traducción heredadas de R278; no se presentan como corregidas.

Comprobaciones específicas posteriores al cambio visual: 22 de espacio privado y vendedor, 13 de destino de acceso, 1.299 de conocimiento y permisos, compilación y compatibilidad Linux. Recursos web, dist y Android iguales.

La reconstrucción del ZIP se ejecuta realmente, se comprueba el SHA-256 y se verifica el CRC de todas sus entradas. También se ejecuta el reunificador de las cuatro partes descargables.

## Estado y límites conservados

El backend R278 está activo en Supabase. Este cambio visual requiere desplegar el frontend actualizado. No se ha desplegado GitHub ni Netlify ni publicado Google Play.

Los siete formatos PDF Owner se probaron con datos aislados; el nuevo PDF real de marketing sigue pendiente de una sesión Owner válida. No se han realizado publicaciones reales en Instagram, cobros, campañas ni aprobaciones de usuarios durante estas pruebas.

No incluye una APK/AAB compilada. La guía maestra no garantiza respuestas infalibles ni sustituye las verificaciones y permisos de servidor. Se conservan los límites y el modelo comercial vigentes del piloto.
