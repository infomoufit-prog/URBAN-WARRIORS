# Auditoría R60 · navegación móvil, KOMBAX Events y multimedia de perfiles

Base: R60 corregida + UI Stabilized + Events Flow Fix.

## Alcance
Intervención exclusivamente frontend. No se modifica backend, Supabase, SQL/RPC, Edge Functions, Auth/RLS, Storage, Hermes, agentes ni configuración de firma Android.

## 1. Navegación móvil
Se detectó redundancia entre la barra inferior y el menú lateral. Por decisión de producto, la barra inferior queda oculta en móvil (`<=820px`) y el menú lateral pasa a ser la única superficie de navegación móvil.

Ajustes asociados:
- se elimina la reserva vertical de la tab bar en `.main-view`;
- se conserva únicamente el safe-area inferior del sistema;
- los toast dejan de reservar la altura de una barra que ya no existe;
- escritorio conserva su comportamiento previo.

## 2. Flujo KOMBAX Events
La auditoría previa del flujo identificó cuatro causas de sensación de recarga/lentitud:
1. primer paint esperando datos auxiliares;
2. re-render destructivo de cartelera tras revalidación;
3. apertura de evento esperando el roster competitivo;
4. ausencia de deduplicación/prefetch del detalle.

La versión actual mantiene las correcciones:
- Events pinta primero y carga contextos auxiliares en paralelo;
- cartelera cacheada al reentrar y continuidad de scroll;
- detalle con caché de 60 s y deduplicación de requests en vuelo;
- prefetch por `pointerenter`, `focusin` y `pointerdown`;
- feedback de apertura tras 120 ms sin recargar la cartelera;
- el mismo modal de espera se transforma en el detalle final;
- preparación competitiva se hidrata fuera del critical path;
- guardas por secuencia impiden que respuestas tardías sobrescriban el evento actual.

Todas las aperturas internas de tarjetas convergen en `openEvent()`. No se introduce navegación de página completa para abrir un evento interno.

## 3. Álbumes de perfiles a pantalla completa
Se añade un visor inmersivo común que se apila por encima del álbum abierto, en lugar de destruir el modal del álbum.

Cobertura:
- fotos de perfiles públicos;
- vídeos de perfiles públicos;
- fotos/vídeos de álbum Miembro;
- fotos/vídeos de perfiles directos gestionados desde el hub.

El visor:
- ocupa el viewport completo;
- usa `object-fit: contain` para no recortar el original;
- respeta safe areas;
- ofrece cierre visible y tecla Escape;
- pausa vídeo al cerrar;
- conserva el álbum debajo para volver de forma natural.

## 4. Encuadre de heroes KOMBAX
No se modifican los archivos de imagen. Solo se corrige el punto focal CSS en tamaños estrechos.

Móvil vertical:
- KOMBAX Events: `68% 15%` para mantener visibles los dos rostros enfrentados;
- KOMBAX Social: `70% 15%` para centrar mejor el peleador.

También se reajustan tablet y móvil horizontal para evitar volver a recortar los sujetos en otros ratios.

## Verificación
- QA específico nuevo: 16/16 PASS.
- R60 Events Navigation Flow: 12/12 PASS.
- R44 Events Flow Stability: 25/25 PASS.
- R54 Events Mobile Quality: 14/14 PASS.
- R55 Events Load Budget: 5/5 PASS.
- R53 Pilot Network/Profile/Events: 21/21 PASS.
- R57 Social Info UX: 25/25 PASS.
- R60 Migrations/Guide/History: 32/32 PASS.
- `node --check`: components, public-profile, gateway y kombax-events PASS.
- Build: `web = dist = Android`, 192 archivos.
- Android preflight: 4/5; solo firma local pendiente, como en la base.

La fluidez física final depende del dispositivo/red real y debe validarse con la APK piloto; a nivel de código se ha eliminado el critical path y los repaints destructivos identificados.
