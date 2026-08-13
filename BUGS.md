# Errores conocidos

## UW-RC10-001 — Subida de imagen grande puede quedar esperando

- Estado: **abierto; reproducido una vez en la vista previa web RC10**.
- Área: Supabase Storage / imágenes públicas.
- Síntoma: el formulario permanece en `Guardando…` durante más de un minuto y termina con `Failed to fetch`.
- Alcance observado: material con una imagen PNG de mayor peso. Comunidad y Comunicaciones guardaron imágenes; Material guardó correctamente una imagen ligera posterior.
- Integridad: no hubo escritura parcial ni registro duplicado, porque RC10 sube primero el archivo y después ejecuta `material.guardar`.
- Causa técnica candidata: `SupabaseClient.upload()` usa `fetch` sin timeout explícito ni información de progreso.
- Riesgo: experiencia bloqueada en conexiones lentas o archivos cercanos al límite de 5 MB.
- Criterio de corrección futuro: timeout controlado, mensaje comprensible, reintento seguro y optimización previa de imágenes, sin alterar el gateway ni RLS.
