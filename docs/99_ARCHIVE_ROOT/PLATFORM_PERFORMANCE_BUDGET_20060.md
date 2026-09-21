# KOMBAX 20.060 · Platform Performance & Scale Budget

## Objetivo
Mantener la sensación de respuesta rápida sin convertir crecimiento, mala cobertura o pantallas en segundo plano en tormentas de consultas.

## Guardrails implementados
- Cabecera global: una sola RPC agregada para avisos Club + actividad KOMBAX + mensajes; el centro completo se carga solo cuando se abre.
- Monitor de cabecera: 45 s en primer plano, 180 s oculto, jitter del 15 %, backoff exponencial ante fallos hasta 10 min y despertar inmediato al volver conexión/foco.
- Chat abierto: 2,5 s en primer plano, pausa total en segundo plano, jitter del 10 %, backoff ante error hasta 20 s y despertar al recuperar conexión/visibilidad.
- Lecturas concurrentes idénticas: coalescidas mientras están en vuelo; no se introduce caché persistente ni se comparten resultados entre usuarios/clubes.
- Dashboard: snapshot de 30 s por tenant y eliminación de consultas de disciplinas/asistencias que el panel no consumía.
- Portal: loaders separados por Dashboard / Horarios / Mi perfil para no descargar módulos que la pantalla no utiliza.
- Feed Social, perfiles, Showcase y chat histórico conservan paginación keyset/cursor existente.
- Todas las mutaciones siguen invalidando la caché del tenant.

## Presupuesto de lanzamiento
- RPC de cabecera: objetivo p95 < 100 ms en datos normales de un club.
- Feed Social / Showcase por página: objetivo p95 < 200 ms de servidor en el dataset de lanzamiento.
- Ningún polling de chat cuando la app está oculta.
- Ningún refresco completo de 1.000 notificaciones para pintar badges.
- Ninguna carga no paginada nueva en Social/Showcase/chat.
- Errores de red periódicos deben reducir frecuencia, no multiplicar reintentos.

## Validación de escala
Antes del lanzamiento masivo, ejecutar carga autenticada en staging con 50 / 100 / 250 / 500 / 1.000 sesiones combinando navegación, feed, chat y operaciones Club. No ejecutar esa prueba destructiva contra producción.
