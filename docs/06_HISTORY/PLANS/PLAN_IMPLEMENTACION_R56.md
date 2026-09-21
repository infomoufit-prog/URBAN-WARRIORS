# KOMBAX 20.106 R56 — plan interno de implementación

Objetivo: preparar una revisión frontend de perfil público/propio apta para validación y congelación QA sin ampliar alcance funcional.

## Alcance cerrado
1. Perfil público: álbum resumido a máximo 5 elementos en la ficha principal.
2. Si existen más de 5 elementos, mostrar `Ver álbum completo` y abrir una vista dedicada con Todo/Fotos/Vídeos.
3. No cambiar KOMBAX Social del perfil: mantener 5 publicaciones + carga de anteriores.
4. No cambiar KOMBAX Showcase del perfil: mantener 4 productos iniciales + ver todo.
5. Perfil propio: retirar del encabezado la parrilla de acciones de gestión, el bloque persistente `Una identidad, un perfil` y la cabecera explicativa que precedía al banner.
6. Perfil propio: tras la navegación global, mostrar como primer contenido el banner/avatar/identidad/contenido, igual que la ficha pública.
7. Añadir una única entrada contextual `Gestionar perfil` en la cabecera visual del perfil propio.
8. Reagrupar dentro de esa entrada todas las acciones existentes, sin eliminar capacidades ni alterar permisos.
9. Aplicar el patrón a todos los tipos de perfil; las acciones específicas continúan condicionadas por tipo/capacidad.
10. No modificar Supabase, contratos de visibilidad, Social, Showcase ni Events.

## Reglas UX
- El escaparate público es la primera capa.
- La gestión es una segunda capa explícita y accesible.
- Máximo 5 elementos multimedia en la ficha principal.
- El álbum completo solo se construye al pedirlo el usuario.
- En móvil, el botón de gestión debe permanecer visible sin tapar avatar o contenido importante.
- Acciones destructivas/privadas siguen dentro de sus flujos actuales.

## Gates de cierre
- Nueva suite focal R56.
- Regresiones R53/R54/R55 + suite completa `npm test`.
- `node scripts/build.mjs` y paridad exacta web/dist/android assets.
- Android preflight.
- Intento de APK debug; no declarar PASS si Gradle externo impide compilar.
- Intento/preflight de AAB Play; no publicar.
- ZIP íntegro + SHA256.
