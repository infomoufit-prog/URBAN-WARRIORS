# QA HANDOFF — KOMBAX 20.101 R52

## Objetivo focal
Validar que un vídeo guardado en álbum de Club o Perfil Directo conserve su portada al publicarse en KOMBAX Social.

## QA manual
1. Recargar KOMBAX Social y comprobar que el vídeo Urban Warriors de 37,87 s muestra como portada un fotograma real, no el frame inicial genérico.
2. Publicar un nuevo MP4 desde identidad Club con “Guardar también en el álbum” activado.
3. Confirmar que la portada automática aparece en el feed Social al terminar la publicación.
4. Cambiar la portada desde “Elegir portada del vídeo” y verificar persistencia tras recargar.
5. Repetir desde Perfil Directo.
6. Elegir un vídeo ya existente del álbum y publicar; debe conservar portada + encuadre.

## Estado backend
Migración `kombax_social_album_cover_inheritance_r52` aplicada en Supabase del proyecto principal durante QA.

## Preservación
R51 continúa como baseline congelada. R52 es una derivada correctiva para QA.

## Automatizado
- R52 focal: 15/15 PASS.
- Regresión R51: 54/54 PASS.
- `npm test`: EXIT 0.
- Build: 190 archivos; web = dist = Android.
- Paridad runtime: 0 faltantes, 0 extras, 0 diferencias SHA.
