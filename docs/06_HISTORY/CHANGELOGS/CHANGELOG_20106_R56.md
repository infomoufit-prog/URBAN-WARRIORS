# KOMBAX 20.106 R56 — PROFILE PUBLIC UX QA FREEZE CANDIDATE

Base: R55 Events Media Architecture Hardening.

## Cambios funcionales
- El álbum de la ficha pública muestra como máximo 5 elementos inicialmente.
- Si existen más elementos aparece `Ver álbum completo`.
- La vista completa conserva filtros Todo / Fotos / Vídeos y solo se construye bajo demanda.
- KOMBAX Social del perfil mantiene 5 publicaciones iniciales + carga progresiva de anteriores.
- KOMBAX Showcase mantiene 4 fichas iniciales + `Ver todo su Showcase`.
- `Mi perfil` deja de mostrar la parrilla administrativa, el bloque persistente `Una identidad, un perfil` y la cabecera explicativa previa al banner.
- En la carga correcta de `Mi perfil`, el banner/hero pasa a ser el primer contenido de la ficha tras la navegación global.
- El propietario ve primero su banner, avatar, identidad y contenido público.
- Las herramientas existentes se agrupan en `Gestionar`, accesible desde la esquina superior derecha del hero.
- `Privacidad y condiciones` queda disponible dentro de `Gestionar` en cualquier apertura del perfil propio, no solo desde la ruta principal.
- Se conservan compartir, avatar, banner, publicaciones, seguridad, afiliación, álbum, edición, privacidad y gestión de club según capacidad/tipo.
- El patrón de acceso a gestión es genérico para cualquier identidad propia.

## Alcance preservado
- KOMBAX Social: sin cambios de módulo respecto a R55.
- KOMBAX Showcase: sin cambios de módulo respecto a R55.
- KOMBAX Events: sin cambios de módulo respecto a R55.
- Repositories: sin cambios respecto a R55.
- Sin nueva migración de base de datos R56.
- Health sincronizado a build 20106.
