# Auditoría final · KOMBAX R60 Pilot Final

Fecha de cierre técnico: 2026-09-09.

## 1. Navegación y frontend

La navegación móvil no utiliza la barra inferior redundante. El menú lateral conserva los módulos y la capa de conversaciones funciona como pantalla propia. Social, Showcase, Assist, Migrations y Soporte comparten shell visual pero no comparten contexto de conversación ni permisos.

KOMBAX Events conserva la arquitectura multimedia R55 y suma la estabilización posterior: detalle con caché acotada, prefetch, deduplicación de solicitudes, protección frente a respuestas fuera de orden, restauración de scroll y feedback de apertura sin reconstrucción completa de la cartelera.

Las fotografías y vídeos de álbumes de perfiles se abren en visor fullscreen con `contain`, controles de vídeo y retorno al punto previo del álbum.

## 2. Assist / Migrations / Soporte

### KOMBAX Assist

Nueva línea `MANAGEMENT`. Acceso autorizado para roles operativos de Club y perfiles gestionables Federación/Marca. En piloto trabaja con snapshot compacto de solo lectura. No puede afirmar que ha cambiado cobros, alumnos, licencias, catálogo, eventos o cualquier dato operativo.

### KOMBAX Migrations

Se mantiene como categoría `MIGRATION`, limitada a Club/Federación. Conserva staging privado, análisis por archivo, metering documental, vista previa y confirmación obligatoria. Marca no recibe acceso a Migrations.

### Soporte KOMBAX

Las categorías históricas/formales permanecen separadas de `MANAGEMENT` y `MIGRATION`. El usuario no puede autoactivar el chat guiado; requiere sesión guiada activa creada por Soporte. El caso puede pasar a verificación/revisión humana y puede continuar por correo.

## 3. Economía de IA

Los límites se validan en backend. La reserva de conversación de gestión utiliza un caso `CHAT` independiente del chat guiado de Soporte; el coste de seguridad continúa teniendo guardrails globales por tenant para evitar consumo inesperado.

## 4. Compatibilidad histórica

Se reconciliaron tests históricos que dependían de copy visible o hashes de frontend ya obsoletos. Los tests ahora verifican la invariantes funcionales originales sin forzar a restaurar textos internos de modelo de datos ni bloquear mejoras posteriores de Events.

No se reintrodujeron textos como “Nunca se convierte en subtipo Profesional” en la UI. La separación Competidor/Profesional se valida por taxonomía y contratos reales.

## 5. Resultado automatizado

- Regresión completa: PASS.
- Build: PASS.
- Paridad `web = dist = Android`: PASS, 197 archivos.
- Pilot Final Assist/Conversations: 28/28 PASS.
- R60 Migrations: 32/32 PASS.
- R38 Assist/Migrations reconciliado: 67/67 PASS.
- R57 Social: 25/25 PASS.
- R56 public profile: 25/25 PASS.
- R55 Events media architecture: 26/26 PASS.
- R55 load budget: 5/5 PASS.
- R54 Events mobile flow: 14/14 PASS.
- Gate legal: PASS.

## 6. Android

Preflight 4/5. La única condición pendiente es la firma local mediante `android/keystore.properties`. El archivo de firma no se incorpora al ZIP por seguridad.

## 7. Advisors Supabase

La revisión posterior a DDL sigue mostrando advisors históricos de proyecto: funciones `SECURITY DEFINER` expuestas de versiones previas, RLS sin policies en tablas cerradas por RPC, FKs sin índice y un índice duplicado histórico. Las cuatro funciones públicas afectadas por este cierre fueron verificadas y no conceden `EXECUTE` a `anon`.

Estos advisors globales deben tratarse como una línea independiente de hardening antes de declarar producción general; no bloquean la entrega del candidato de piloto bajo QA controlado.
