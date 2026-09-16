# KOMBAX 20.101 R53 · Auditoría de portadas de vídeo

## Flujo auditado
`generación de portada → persistencia → álbum → herencia a KOMBAX Social → lectura de media_presentation → poster del vídeo → Android/PWA`

## Evidencia del fallo histórico
En R51, un vídeo podía generar correctamente portada en el álbum, pero la referencia creada para KOMBAX Social perdía `media_presentation`. Después se detectó un segundo problema: el feed devolvía el multimedia resuelto como `media_id`, mientras el frontend buscaba la presentación únicamente por `social_media_id`; además, un objeto `{}` vacío podía tapar una presentación real.

## Correcciones acumuladas conservadas en R53
- R52: herencia backend Álbum→Social y backfill para referencias vacías.
- R52.2: el feed resuelve la presentación usando el identificador multimedia efectivo y un `{}` vacío no tiene prioridad sobre datos válidos.
- R53: conserva esa cadena y la somete a regresión junto con los cambios de perfiles/red/Events.

## Evidencia real
Los vídeos de prueba de 37,87 s auditados en el entorno vivo tienen portada automática persistida con `cover_time = 9.47`, `cover_storage_path` y bucket público. El álbum ya mostraba correctamente esa portada; el problema restante era de recuperación/render en la publicación Social Android y quedó cubierto por R52.2, conservado en R53.

## Paridad de aplicación
Build R53:
- Web: **191 archivos**.
- Dist/PWA: **191 archivos**.
- Android assets: **191 archivos**.
- Faltantes: 0.
- Extras: 0.
- Diferencias SHA: 0.

Esto demuestra que el código de portada que se sirve en PWA es el mismo que queda embebido en Android. No sustituye la validación visual en un APK físicamente instalado.

## Regresión
- R51 → **54/54 PASS**.
- R52 → **15/15 PASS**.
- R52.2 → **10/10 PASS**.
- R53 → **21/21 PASS**.
- `npm test` completo → **EXIT 0**.

## QA visual obligatoria
Con el APK R53 generado localmente:
1. abrir una publicación Social que contenga un vídeo con portada existente;
2. confirmar que la tarjeta muestra la portada seleccionada/generada y no el fotograma gris del reproductor;
3. reproducir/abrir y comprobar el vídeo original completo;
4. repetir con vídeo de álbum de Club/Perfil publicado posteriormente en Social;
5. repetir en KOMBAX Events.
