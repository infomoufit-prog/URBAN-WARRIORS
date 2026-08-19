# KOMBAX RC13 build 20036 — Manual interactivo del portal de club

## Objetivo
Sustituir los manuales visuales/PDF específicos de Urban Warriors por una capa interactiva, genérica y mantenible dentro de KOMBAX para la vía de acceso de clubes.

## Implementación
- Nuevo `Manual interactivo del club` dentro de `#help`.
- 28 temas funcionales auditados y agrupados por áreas operativas.
- Buscador por palabra/tarea y filtro por bloque.
- Cada tema incluye propósito, roles, paso a paso, reglas importantes y acceso directo a la función real cuando el rol lo permite.
- Manual adaptado a roles y ámbitos sin revelar capacidades como ejecutables cuando no corresponden.
- Combat Social documenta publicación, multimedia, corazón, comentarios, respuestas, guardados y perfiles públicos.
- Showcase se documenta como escaparate no transaccional y separado de Social.
- Se documentan códigos cortos de club, altas, equipo, monitores, grupos, sesiones, asistencia, progreso, finanzas, recibos, cobros, eventos, comunicaciones, Comunidad, material, documentos, archivo, notificaciones, branding, instalación y privacidad.
- Eliminadas del frontend las galerías y PDFs antiguos de Urban Warriors.
- Integrado `Cartel_Descarga_KOMBAX_Club.png`, genérico para cualquier club, con espacio QR y código de invitación.
- `Instalar app` pasa a lenguaje KOMBAX genérico e integra el nuevo cartel y el manual interactivo.
- Build actualizado a 20036 en web/PWA/service worker/Android.

## Backend / Supabase
No se añade migración nueva: esta entrega es una evolución de frontend/documentación interactiva y utiliza los contratos backend ya desplegados hasta 062. Añadir DDL sin necesidad habría introducido riesgo sin beneficio.

## Compatibilidad
- El manual actual es exclusivamente para la vía `portal de club`.
- Los manuales específicos de Competidor, Federación, Marca y otras vías directas quedan fuera de este build y tendrán su propio tutorial.
