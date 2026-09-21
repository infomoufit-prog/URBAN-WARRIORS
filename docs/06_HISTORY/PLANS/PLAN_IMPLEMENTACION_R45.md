# KOMBAX 20101 R45 · Showcase Mobile Visual Stabilization

## Alcance
- Mantener R44 intacta como base estable.
- Mejorar la visualización vertical móvil de las tarjetas de KOMBAX Showcase.
- Convertir únicamente el bloque visual de la tarjeta en móvil (`<=620px`) a proporción 1:1.
- No modificar tablet, escritorio, detalle de producto, backend, Supabase ni reglas comerciales.

## Riesgos
- Alterar por error el layout de desktop/tablet.
- Deformar imágenes o perder el encuadre configurado.
- Introducir overflow vertical/horizontal.

## Implementación
- `web/css/app.css`: sustituir altura fija móvil de `170px` por `height:auto; aspect-ratio:1/1`.
- Mantener `object-fit:cover` para conservar el encuadre sin deformación.

## QA
- Test estático R45 sobre la regla responsive.
- Regresión R44 y suite completa.
- Build y paridad web/dist/Android.

## Criterio de cierre
- Tarjetas Showcase móviles 1:1.
- Sin cambios fuera del breakpoint móvil.
- Suite y build en verde.
