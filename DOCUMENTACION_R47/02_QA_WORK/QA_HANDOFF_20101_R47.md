# QA handoff · R47 Social

## Estado
R47 es candidata PRE-QA / QA. Los gates automatizados y el backend R47 están verificados; falta recorrido autenticado en dispositivo con al menos dos identidades para validar audiencia real extremo a extremo.

## Recorrido manual requerido
1. Abrir Social en Android/móvil vertical.
2. Marcar «Me interesa», luego «No me interesa» y después «Sin preferencia»; confirmar que -1 no hace desaparecer la publicación.
3. Crear una publicación propia y abrir `··· > Visibilidad`.
4. Cambiar entre Todo KOMBAX, Mi red, club/federación, clubes seleccionados/excluidos, perfiles concretos y tipos de perfil.
5. Con segunda identidad, comprobar que cada audiencia realmente permite/deniega lectura como corresponde.
6. Probar foto vertical/cuadrada/horizontal y vídeo vertical: 4:5 / 1:1 / 16:9, tap, fullscreen, back/cierre y scroll.
7. Cargar segunda página del feed y revisar duplicados/saltos.
8. Revalidar comentario, compartir, guardar, denunciar y bloquear.
9. Probar cambio de audiencia con media pública/restringida y confirmar que la app impide una transición insegura sin republicar la media.

## Automatización final
- R47 28/28 PASS.
- R40 74/74 PASS.
- R44 25/25 PASS.
- R45 6/6 PASS.
- R46 15/15 PASS.
- Suite completa EXIT 0.
- Build PASS.
- Paridad 189/189/189 PASS, 0 hashes distintos.
- Secret scan PASS, 0 hallazgos.
- Android preflight 4/5: solo firma local pendiente.

## Congelación
No declarar Social production-ready ni levantar el HOLD de datos personales reales hasta completar QA manual autenticado y el cierre global de advisors/ciberseguridad.
