# KOMBAX 20.101 R7 · Auditoría visual UX/UI

## Alcance auditado
- Gateway / interfaz de entrada.
- Brand Hero de KOMBAX Social.
- Brand Hero de KOMBAX Events.
- Brand Hero de KOMBAX Showcase.
- Comportamiento responsive de los cuatro escenarios.
- Motion, legibilidad, jerarquía y coste de assets.

## Qué estaba bien en R6
### Sistema compartido de marca
- Social, Events y Showcase ya utilizan un único componente `brandHero()`, evitando tres diseños divergentes.
- El logo oficial se reutiliza desde `KOMBAX_BRAND`; no hay marcas alternativas.
- Paleta de área ya diferenciada: rojo Social, cian Events, dorado Showcase.
- Las fotografías están preparadas con espacio negativo a la izquierda para copy HTML.
- Existían `prefers-reduced-motion`, máscara de legibilidad, partículas, glow y animación de respiración.

### Events
- Es el hero con mejor narrativa visual: dos atletas, tensión previa y buen uso del cian/rojo.
- El copy «El espectáculo no empieza en el ring. Empieza aquí.» funciona como entrada de producto.
- CTA funcional de explorar/crear permanece integrado en el hero.

### Social
- El luchador queda claramente asociado a identidad/red y dispone de suficiente aire para el claim.
- «Tu red. Tu legado.» ya tiene jerarquía fuerte y los accesos conceptuales están resumidos en features.

### Showcase
- La fotografía tiene lectura comercial/editorial y gran zona limpia para copy.
- «Muestra. Promociona. Destaca.» es una línea clara y memorable.

## Qué estaba regular
### Gateway
- El watermark grande de símbolo + wordmark reforzaba marca, pero no explicaba visualmente que KOMBAX representa múltiples personas, edades, disciplinas y perfiles.
- El H1 llegaba a 80 px y competía demasiado con el bloque visual derecho.
- La primera impresión tenía más identidad gráfica que narrativa humana.

### Motion de Social / Events / Showcase
- El humo presente en las fotografías era estático; el movimiento provenía principalmente del zoom/respiración de toda la foto, partículas y halo del copy.
- Visualmente era correcto, pero no generaba aún la sensación de humo vivo solicitada.
- La misma base de motion se percibía con intensidad parecida entre áreas; Events necesitaba liderar claramente el nivel de inmersión.

### Móvil
- El sistema era responsive, pero el gateway no disponía de un bloque multimedia protagonista independiente: el watermark ambiental era demasiado secundario.
- Un asset de entrada de gran formato podía desplazar los CTA si no se limitaba por altura.

## Qué debía mejorarse ya — implementado en R7
1. Sustituir visualmente el watermark gigante por la composición multi-deportista aprobada.
2. Optimizar el PNG aprobado (2,3 MB) a WebP de 184.038 bytes sin alterar el contenido visual.
3. Reducir el H1 del gateway a máximo 64 px en desktop para equilibrar texto y multimedia.
4. Añadir máscara izquierda/inferior para que imagen y texto puedan convivir sin solapes.
5. Crear humo/bruma animado con CSS, no GIF ni vídeo.
6. Hacer que Events tenga la mayor intensidad atmosférica; Social media; Showcase la más sutil.
7. En móvil, convertir la imagen de entrada en un bloque panorámico de altura acotada antes del copy.
8. Mantener `pointer-events:none` y `aria-hidden` en toda capa decorativa.
9. Mantener fallback de reduced-motion.
10. Separar cache de assets R7 sin cambiar la identidad funcional build 20101.

## Mejoras opcionales para siguientes fases
- Afinar microinteracciones de CTA al entrar en viewport, sin animar layout.
- Medir LCP real en Android de gama media y ajustar calidad del WebP si fuese necesario.
- Revisar en dispositivos físicos 360/390/430 px el crop exacto de la composición aprobada.
- Refinar transiciones internas de Events (cartelera → detalle → resultados/highlights) después de validar este nuevo lenguaje de motion.
- Valorar más adelante un loop WebM exclusivamente para una campaña/landing si CSS no fuese suficiente; no se recomienda para el producto base actual.

## Resultado de auditoría
La arquitectura R6 era sólida y reutilizable. No se justifica rehacer componentes. La mejora correcta es evolutiva: nuevo asset de entrada + motion atmosférico ligero sobre la estructura existente. R7 aplica esa corrección sin modificar lógica de negocio, navegación, permisos ni backend.
