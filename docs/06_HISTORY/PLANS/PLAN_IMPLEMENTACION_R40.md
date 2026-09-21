# PLAN_IMPLEMENTACION_R40.md

## Objetivo
Cerrar antes del piloto la neutralidad y control de visibilidad de KOMBAX Social y KOMBAX Events, mejorar la descubribilidad de Mi red y hacer KOMBAX Migrations más visible en los puntos donde un club incorpora datos. Preservar íntegramente la navegación global cerrada en R39 y el aislamiento de preparación/pesos R35-R39.

## Bloque 1 · Mi red accionable
- Mantener `Mi red` como concepto de producto.
- Mostrar descriptor visible `Contactos y conexiones KOMBAX`.
- Mostrar CTA explícito `Añadir a mi red`.
- Permitir buscar perfiles públicos y solicitar relación con consentimiento.
- La red y su tamaño siguen siendo privados.

## Bloque 2 · Visibilidad Social neutral
Audiencias disponibles según identidad/permisos:
- Todo KOMBAX.
- Mi red.
- Solo mi club.
- Federación / afiliados cuando corresponda.
- Clubes seleccionados.
- Todo KOMBAX excepto clubes seleccionados.

Ocultar contenido no rompe relaciones, mensajería, afiliaciones ni participación conjunta en Events. El límite operativo de listas de clubes es 50 por publicación.

## Bloque 3 · Visibilidad avanzada de Events
Separar `quién descubre el evento` de `qué bloques del evento se publican` (política R36).
Modos:
- Público · web + KOMBAX.
- Todo KOMBAX.
- Mi red.
- Solo un club.
- Clubes seleccionados.
- Federación / afiliados.
- Por invitación.

La visibilidad nunca concede acceso a preparación privada, historial de peso o pesaje oficial privado. Los eventos existentes conservan su semántica heredada hasta que un organizador cambie la configuración.

## Bloque 4 · KOMBAX Migrations visible
Mantener acceso directo a Migrations y reforzar CTA contextual dentro de Mi Club en:
- Inicio.
- Alumnos.
- Finanzas.
- Perfil del Club.
- Federaciones y licencias.
- Archivo documental.

Mensajes visibles: IA asistida, Excel/CSV/PDF/imágenes, análisis por lotes, vista previa y confirmación antes de importar.

## Bloque 5 · Auditoría Perfil Marca
Antes del cierre R40 comprobar continuidad real de R37: Business Hub, campañas, propuestas/CRM, búsqueda comercial opt-in, patrocinios, equipo de Marca, preferencias y proyección pública limitada. No reimplementar si ya está correcto.

## Reglas inmutables
1. Navegación global R39 intacta: Mi perfil, KOMBAX Social, KOMBAX Eventos, KOMBAX Showcase, Mi Club.
2. Preparación y pesos privados nunca se incorporan a Social/Events visibility.
3. No publicación automática por rivalidad/afiliación; la visibilidad la decide el actor autorizado.
4. No Netlify, GitHub, Google Play ni firma Android durante esta iteración de código/QA.
5. No secretos/JKS/.env dentro del entregable.
6. No declarar R40 oficial hasta pasar QA, build, paridad y extracción limpia.

## QA obligatorio
- test específico R40;
- regresión R39-R32;
- npm test completo;
- migraciones live y permisos/RLS;
- referencias a peso/preparación = 0 en funciones R40;
- build web=dist=Android;
- Android preflight;
- ZIP único, manifiesto SHA-256 y extracción limpia;
- test R40/R39 y build desde el ZIP extraído.
