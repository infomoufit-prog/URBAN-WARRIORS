# FASE 5 · KOMBAX RC13 build 20.094 · Live + Results + Highlights + History

## Misión
Evolucionar KOMBAX Eventos desde descubrimiento/viralización a experiencia de evento vivo y archivo deportivo, sin convertir KOMBAX en una plataforma de streaming ni mezclar el dominio público con `Mi Club > Eventos`.

## Invariantes no negociables
1. `Mi Club > Eventos` continúa completamente separado y privado.
2. `KOMBAX Eventos` sigue siendo fuente pública/transversal; Social solo difunde referencias.
3. No leer ni promover automáticamente alumnos privados como participantes públicos.
4. No activar perfil Espectador todavía; cualquier lectura pública debe funcionar como visitante y cualquier acción personal reutiliza identidades autorizadas actuales.
5. No duplicar resultados, media ni relaciones evento/combate/competidor.
6. No exponer Storage mediante bucket público indiscriminado si existe contenido moderable o temporal.
7. Toda escritura pasa por RPC/gateway y permisos explícitos; ninguna UI hace `fetch` directo.
8. Mantener Finance Premium, Social, Showcase, Owner, moderación, privacidad y aislamiento multi-club sin regresiones.

## Diseño de producto
### A. Estado temporal del evento
- `PRÓXIMAMENTE`: evento publicado futuro.
- `AHORA`: evento en curso según estado editorial y ventana temporal.
- `FINALIZADO`: evento cerrado con resultados/histórico.
- Listas rápidas: Ahora, Próximos, Resultados recientes.
- Motion accesible para estado live, siempre respetando `prefers-reduced-motion`.

### B. Resultados e histórico
- Resultado oficial por combate con estado: pendiente / provisional / oficial / anulado.
- Ganador opcional, método, round, tiempo, decisión/notas públicas.
- Histórico del evento y del competidor mediante referencias, no copias.
- Cambios oficiales auditables y actualizados solo por gestores autorizados del evento.

### C. Álbum postevento / highlights
- Media vinculada a evento y opcionalmente a combate/competidor.
- Tipos: foto, clip, vídeo/enlace, highlight.
- Estados: pendiente, visible, oculto, retirado.
- Orden editorial y cover/featured.
- Descarga solo cuando `allow_download=true`.
- Moderación compatible con el sistema global existente.

### D. Almacenamiento y retención
- Bucket dedicado `kombax-events-media` si no existe.
- Objetos segmentados por `evento_id/<media_id>/...`.
- Lectura mediante signed URL/gateway para objetos propios de KOMBAX, no por bucket público general.
- Clips temporales pueden tener `expires_at`; highlights/fotos oficiales pueden conservarse.
- Eliminación lógica primero; limpieza física queda preparada para operación/retención segura.
- Vídeos externos se guardan como URL de referencia y nunca se rehostean automáticamente.

### E. Permisos
- Lectura pública: solo eventos visibles y media `visible` sin expiración efectiva.
- Gestión: organizador/colaborador con scope adecuado o platform admin.
- Resultado oficial: requiere permiso de gestión del evento.
- Media: creación/edición/eliminación lógica por gestor autorizado; futura aportación de terceros quedará fuera de 20.094.
- anon no ejecuta mutadores.

## Backend propuesto
### Migración 164 · Live + Results
- extender combate público con columnas de resultado oficial de forma compatible;
- RPC de lectura de timelines/estado;
- RPC de mutación de resultado con idempotencia/auditoría;
- índices de consulta temporal/resultado.

### Migración 165 · Event Media + Highlights
- tabla `kombax_evento_media`;
- FK a evento, combate y perfil competidor opcionales;
- constraint de unicidad lógica para evitar duplicados de objeto/referencia;
- RLS ON + acceso directo revocado;
- RPC de listado público y gestión autenticada;
- Storage policies mínimas o gateway compatible con signed URLs;
- índices FK/estado/orden/expiración.

### Migración 166 · History + Final Hardening
- RPC de histórico por evento/competidor;
- agregados de resultados recientes;
- helper de estado temporal;
- cierre de ACL/EXECUTE y verificación de índices;
- sin tocar el `app_diagnostico_final_v166` heredado salvo conflicto nominal (usar nombres Events específicos).

## Frontend
- Hub KOMBAX Eventos: chips/secciones Ahora / Próximos / Resultados.
- Detalle público: badge live, timeline, Fight Card con resultados, highlights/álbum.
- Tarjeta de combate: resultado oficial y estado visual.
- Visual Engine: tarjeta de resultado debe beber del resultado backend real.
- Media viewer con descarga condicionada y fallback para vídeo externo.
- Deep links existentes deben seguir funcionando.

## Android/PWA
- Sin API externa nueva.
- Compatibilidad WebView.
- No autoplay forzado con audio.
- `playsinline`, controls y carga diferida para clips.
- Mantener service worker/cache build 20094.

## QA obligatorio
1. Preflight backend 164 → apply → verify.
2. Preflight 165 → apply → verify.
3. Preflight 166 → apply → verify.
4. RLS/ACL focalizada Events: tablas nuevas/extendidas sin DML directo para anon/authenticated.
5. Mutadores no ejecutables por anon.
6. Storage: no bucket público; paths/permissions verificadas.
7. Performance Advisor: corregir únicamente regresiones nuevas de 20.094.
8. Security Advisor: clasificar baseline heredado vs nuevos avisos.
9. Tests 20090–20094 + arquitectura + regresión completa disponible.
10. `npm run build` + paridad web/dist/Android.
11. Actualizar health a build 20094 solo tras backend y build correctos.
12. Empaquetar ZIP completo 20.094 + manifest SHA-256 + continuidad 20.095.

## Fuera de alcance 20.094
- Streaming en directo alojado por KOMBAX.
- Pagos/ticketing.
- Perfil Espectador.
- Subidas públicas anónimas o UGC abierto de espectadores.
- Migración automática de `Mi Club > Eventos` a KOMBAX Eventos.
