# KOMBAX 20.101 R50 · Media Framing + HD60

## Base preservada
R49 Social + Events final polish. R49 no se modifica.

## Alcance cerrado
1. KOMBAX Social: eliminar el recorte forzado móvil que anulaba `Mostrar completo`.
2. Foto y vídeo Social: respetar `Completo / Rellenar marco`, posición X/Y y zoom guardados.
3. Extender el editor de encuadre Social a vídeo sin modificar el archivo original.
4. Visor fullscreen: mantener siempre el original completo (`contain`).
5. KOMBAX Social: aceptar vídeo MP4 hasta 60 s, HD hasta 1080p, con validación cliente + backend.
6. KOMBAX Events: consolidar UX/documentación en MP4 HD hasta 60 s; preservar backend existente de 60 s/1080p.
7. Social + KOMBAX Events: usar la geometría real del contenido: vertical 9:16, horizontal 16:9 y cuadrado 1:1.
8. Al tocar foto/vídeo, abrir visor inmersivo con el original completo (`contain`) y sin recorte.
9. Mantener compatibilidad con eventos/publicaciones existentes y presentaciones ya guardadas.

## Backend previsto
- Social sí requiere migración: subir límite de `kombax_social_media` de ~15 s a ~60 s.
- Las rutas de álbum de Club y Perfil Directo usadas desde Social también deben aceptar hasta 60 s para no fallar cuando `Guardar también en álbum` esté activo.
- Events no requiere DDL: el contrato vivo ya admite <=60.2 s y <=1080p.

## Riesgos
- Colisión CSS `object-fit:cover!important` móvil.
- Vídeos de Club/Perfil Directo limitados históricamente a 15 s.
- Límite del bucket público de 25 MB: HD 60 s puede superar ese peso. R50 mantendrá un límite de archivo seguro y lo hará explícito; no habrá transcodificación pesada en cliente.
- Compatibilidad con WEBM/MOV históricos: se preserva lectura, pero la nueva subida recomendada/aceptada desde estos flujos será MP4.

## QA obligatorio
- Test R50 focal.
- R47/R49 Social.
- R44/R48 Events.
- Suite completa npm test.
- Build y paridad web/dist/Android.
- Supabase live: migración, constraints/functions, RLS/GRANTs, Advisors.
- Secret scan y Android preflight.
- ZIP limpio + extracción + smoke.

## Criterios de cierre
- Ninguna foto/vídeo se recorta por una regla CSS global cuando su presentación es `contain`.
- Autor puede ajustar foto o vídeo con Completo/Rellenar + foco/zoom.
- Social acepta MP4 <=60 s y <=1080p en todos los tipos de identidad admitidos por el publicador.
- Events mantiene MP4 <=60 s <=1080p y la UX lo comunica claramente.
- 0 regresiones funcionales en suites históricas.

## Regla final de proporciones Social + KOMBAX Events
- Horizontal: marco 16:9.
- Vertical: marco 9:16.
- Cuadrado: marco 1:1.
- Foto y vídeo respetan la orientación real del archivo.
- Dentro del marco, `Mostrar completo` usa contain y `Rellenar marco` usa cover/encuadre guardado.
- Al tocar la media, el visor inmersivo siempre muestra el archivo original completo con contain, sin recorte.


## Corrección de cierre backend
Durante el gate final se detectó que un hardening incremental del guard 1080p expresaba temporalmente `width<=1920` y `height<=1080`, lo que podía rechazar un vídeo vertical 1080x1920. Antes de entregar R50 se corrigió en vivo y en la cadena local con `greatest(width,height)<=1920` y `least(width,height)<=1080`, haciendo la validación independiente de la orientación.
