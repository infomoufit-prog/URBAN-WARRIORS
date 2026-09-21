# KOMBAX 20.062 · Founders Promotion Traceability

Fecha de auditoría: 2026-08-20

## Decisión de producto

KOMBAX comunica dos campañas de lanzamiento sin publicar todavía precios, porcentajes, descuentos ni una contraprestación económica concreta:

- **Combat Social**: primeros 20 competidores que completen la verificación KOMBAX.
- **KOMBAX Showcase**: primeros 20 clubes que completen la verificación KOMBAX.

El mensaje visible habla únicamente de una **ventaja especial de lanzamiento** cuyos detalles se comunicarán próximamente.

## Regla auditable de plaza

La plaza no se determina por fecha de registro, fecha de creación de borrador, fecha de envío de solicitud ni por haber visto el anuncio.

La fuente de verdad será el orden de los eventos de verificación completada:

1. `public.kombax_verificacion_eventos.evento = 'verified'`.
2. Unión por `solicitud_id` con `public.kombax_solicitudes_alta`.
3. Separación por `kombax_solicitudes_alta.tipo` (`competidor` o `club`).
4. Orden ascendente por `kombax_verificacion_eventos.creado_en`, con `id` como desempate determinista si fuese necesario.
5. Las primeras 20 solicitudes distintas verificadas de cada tipo ocupan las 20 plazas de su campaña.

La tabla de eventos contiene `id`, `solicitud_id`, `perfil_directo_id`, `actor_perfil_id`, `evento`, `detalle` y `creado_en`, por lo que la secuencia puede reconstruirse posteriormente.

## Estado live al inicio de la campaña

Auditoría de solo lectura en el proyecto Supabase `poggsobhtutbuagjiydc`:

- perfiles Competidor totales: **0**;
- perfiles Competidor verificados: **0**;
- eventos `verified` de solicitudes Competidor: **0**;
- eventos `verified` de solicitudes Club: **0**.

El Club Urban Warriors preexistente es un tenant/bootstrap anterior al flujo de esta campaña y no tiene un evento `verified` de solicitud Club en el registro auditado. Bajo la regla anterior, no consume una de las 20 plazas promocionales.

## Recomendación operativa futura

Cuando se definan las condiciones económicas concretas, no modificar retrospectivamente el criterio de entrada. Generar un snapshot/auditoría de las 20 solicitudes ganadoras de cada tipo a partir de los eventos de verificación y asociar después el beneficio comercial definido.

No se ha creado una tabla promocional ni una migración nueva en 20.062 porque la trazabilidad necesaria ya existe.
