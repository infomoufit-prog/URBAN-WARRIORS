# Auditoría previa R56 — perfil público y perfil propio

## Hallazgos confirmados en R55
- `gallery(profile)` construye todos los elementos del álbum recibido y por tanto la ficha principal puede crecer con todo el álbum.
- Social ya aplica `slice(0,5)` y `profilePosts(...,10)` para continuar bajo demanda.
- Showcase ya oculta desde el quinto elemento y ofrece `Ver todo su Showcase`.
- `renderOwnKombaxProfilePage()` inyecta `profileActions(...)` en `pageHeader`, creando una parrilla de gestión antes del banner.
- La misma página añade un bloque persistente `Una identidad, un perfil` antes del hero.
- Las acciones de gestión existentes están centralizadas en `profileActions()` y `bindProfileActions()`, por lo que pueden reagruparse sin alterar repositorios ni permisos.
- El perfil público de terceros necesita conservar Añadir a mi red / Contactar / Denunciar / Compartir.
- No se requiere migración backend para el alcance acordado.

## Riesgos a evitar
- Romper tests históricos que verifican presencia de acciones Miembro.
- Duplicar IDs de controles entre ficha y modal de gestión.
- Cargar todo el álbum antes de pulsar `Ver álbum completo`.
- Perder el acceso a seguridad, privacidad, edición, afiliación, publicaciones o gestión del club.
- Cambiar accidentalmente Social/Showcase/Events.

## Decisión
Implementación exclusivamente frontend en `public-profile.js` + estilos, con prueba focal y versionado 20106.
