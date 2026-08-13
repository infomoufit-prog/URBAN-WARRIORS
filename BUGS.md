# Errores conocidos

## UW-RC10-001 — Subida de imagen grande puede quedar esperando

- Estado: **corrección implementada localmente en Release H; pendiente de prueba real**.
- Área: Supabase Storage / imágenes públicas.
- Síntoma: el formulario permanece en `Guardando…` durante más de un minuto y termina con `Failed to fetch`.
- Alcance observado: material con una imagen PNG de mayor peso. Comunidad y Comunicaciones guardaron imágenes; Material guardó correctamente una imagen ligera posterior.
- Integridad: no hubo escritura parcial ni registro duplicado, porque RC10 sube primero el archivo y después ejecuta `material.guardar`.
- Causa técnica candidata: imagen demasiado pesada para la conexión y `SupabaseClient.upload()` sin timeout explícito.
- Riesgo: experiencia bloqueada en conexiones lentas o archivos cercanos al límite de 5 MB.
- Corrección local: optimización previa hasta 1920 px/5 MB, WebP cuando está disponible, timeout controlado y mensaje comprensible. No hay reintento automático porque una respuesta perdida no permite garantizar que Storage no haya recibido ya el objeto.
- Prueba pendiente: repetir en web y Android con la imagen que falló y revisar que la subida optimizada finaliza o termina de forma controlada.
