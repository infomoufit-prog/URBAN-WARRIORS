# KOMBAX 20.101 R53 · PLAN INTERNO DE IMPLEMENTACIÓN

## Objetivo
Derivar R53 desde R52.2 sin modificar la baseline congelada R51 y cerrar un candidato de piloto coherente en Web/PWA, APK Android y bundle Google Play.

## Bloque A · Mi red KOMBAX
- Convertir “Mi red” en una conexión privada general disponible entre cualquier par de perfiles públicos KOMBAX activos y visibles.
- Mantener vínculos profesionales existentes (Club↔Federación, Competidor↔Club, Marca↔Club, etc.) como categorías opcionales, no como requisito para conectar.
- Añadir el CTA “Añadir a mi red” tanto en resultados de búsqueda como dentro de toda ficha pública ajena.
- Detectar solicitud pendiente o conexión ya confirmada antes de crear duplicados.
- Mantener aceptar, rechazar y eliminar de Mi red.
- No publicar la lista de relaciones ni el tamaño de la red.

## Bloque B · Perfil público universal
Aplicable a Miembro, Club, Federación, Marca, Competidor, Profesional y cualquier identidad pública KOMBAX visible.
- Cabecera pública y acciones consistentes.
- Álbum clasificado con filtros Todo / Fotos / Vídeos.
- Últimas 5 publicaciones visibles según la audiencia del espectador.
- Acción “Ver todas las publicaciones” con paginación posterior.
- Sección Showcase universal; muestra hasta 4 fichas inicialmente y permite expandir todas las fichas activas del perfil.
- Mantener datos privados, financieros, administrativos, familiares y documentos fuera del perfil público.

## Bloque C · KOMBAX Events · auditoría definitiva de estabilización
- Reejecutar regresiones R44/R48/R49/R51 y flujo multimedia.
- Revisar apertura de detalle, builder, gestión, Fight Card, Main/Co-Main, participantes, visibilidad, álbum, vídeo/portada y móvil.
- Corregir rutas de error silenciosas que puedan dejar al usuario sin feedback durante gestión.
- No introducir un dominio paralelo ni nuevas tablas si no son necesarias.

## Bloque D · Portadas de vídeo
- Verificar extremo a extremo: generación → persistencia → herencia Álbum→Social → lectura de presentación → poster en feed → Android assets.
- Mantener foto/vídeo original intacto y encuadre no destructivo.

## Cierre multicanal obligatorio
1. WEB/PWA: test + build + paridad web/dist.
2. APK: sincronización web/dist/android y runner debug operativo.
3. GOOGLE PLAY: mismo contenido Android, preflight, AAB preparado; firma release se valida localmente si el keystore no está disponible en el entorno de auditoría.
4. No desplegar Netlify, no hacer push GitHub y no publicar Google Play sin autorización expresa.
