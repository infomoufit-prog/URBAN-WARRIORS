# KOMBAX RC13 build 20.096 · Auditoría visual de KOMBAX Eventos

Base auditada: **20.095 Integration / Hardening Final Candidate**.

## Diagnóstico previo

La 20.095 ya disponía de una arquitectura visual sólida y oscura, pero todavía presentaba varios rasgos que podían percibirse como software funcional antes que como producto deportivo premium:

1. Iconografía demasiado genérica en navegación y categorías.
2. Dependencia casi exclusiva del rojo como acento, con poca profundidad cromática.
3. Fondo animado correcto pero con sensación plana en pantallas grandes.
4. Hero potente, aunque sin suficiente contraste entre energía digital, arena y marca.
5. Tarjetas de evento con buena jerarquía pero poca iluminación direccional.
6. Fight Cards funcionales, pero con margen para parecer más cercanas a una gráfica broadcast profesional.
7. Partners/sponsors y highlights visualmente coherentes, aunque todavía demasiado administrativos.
8. Estados de carga/vacío mejorables para conservar personalidad aun sin contenido.
9. Plantillas compartibles correctas, pero no plenamente alineadas con el nuevo acabado neon/premium.
10. Interacciones hover pensadas principalmente para escritorio; faltaba una capa táctil explícita.

## Dirección visual adoptada

- Negro profundo / grafito como escenario.
- Rojo KOMBAX como firma principal.
- Cian neon como energía digital y conectividad.
- Violeta neon como profundidad ambiental, nunca como color dominante.
- Verde menta para resultado/confirmación oficial.
- Dorado reservado para Main Event / sponsor principal / jerarquías especiales.

Principio: **neón controlado, no ruido visual**.

## Mejoras implementadas

### Iconografía
- Nuevo icono `arena` para KOMBAX Eventos en navegación.
- Iconos semánticos por categoría: bolt, users, flame, trophy, medal, professional, sparkles, brand.
- Icono broadcast en CTA principal.

### Fondo y atmósfera
- Nuevo asset local `kombax-events-neon-mesh.svg`.
- Grid + líneas diagonales + halos rojo/cian/violeta.
- Drift ambiental lento y capas de glow independientes.
- Respeta `prefers-reduced-motion`.

### Hero
- Campo neon de tres capas.
- Badge `LIVE ECOSYSTEM`.
- Titular con gradiente rojo → blanco → cian.
- Arena KX con doble temperatura de luz y spark animado.
- CTA Explorar con tratamiento digital cian.

### Cards y navegación
- Glass oscuro, edge glow y profundidad.
- Iluminación asimétrica rojo/cian.
- Estados Próximo/Live/Abierto con firma cromática propia.
- Search/tabs con focus premium y blur controlado.
- Interacciones táctiles `pointer: coarse` y `touch-action: manipulation`.

### Fight Cards
- Rival A: luz roja KOMBAX.
- Rival B: luz cian.
- VS con eje de luz dual.
- Main Event con reserva dorada.
- Live con glow rojo dinámico.
- Resultado oficial con menta + firma KOMBAX.

### Organizaciones, sponsors y media
- Contenedores glass premium.
- Hover y edge glow de partners.
- Sponsor principal con tratamiento dorado discreto.
- Highlights con profundidad y acento cian en interacción.

### Landing pública
- Fondo neon local compartido con la app.
- Hero público con iluminación ambiental y mayor contraste.
- KPIs públicos con semántica de color.

### Visual Engine
Se han rediseñado localmente, sin API externa:
- `fight-card-square.svg`
- `fight-card-story.svg`
- `event-share-square.svg`
- `event-share-story.svg`
- `fight-share-square.svg`
- `fight-share-story.svg`
- `result-share-square.svg`
- `result-share-story.svg`

Todas mantienen datos dinámicos y generación local/Canvas/QR.

## Criterios de rendimiento

- No se añaden librerías visuales externas.
- No se añade WebGL.
- No se añade vídeo de fondo.
- No se añade polling visual.
- Animaciones basadas en transform/opacity siempre que es posible.
- Hover se neutraliza en móvil para evitar movimientos incómodos.
- `prefers-reduced-motion` conserva una experiencia completa sin animación ambiental.

## Resultado

20.096 eleva KOMBAX Eventos desde una interfaz premium funcional hacia una identidad propia de **producto deportivo/broadcast digital**, sin alterar el modelo de datos, RLS, backend, inscripciones, resultados ni separación con Eventos internos de Mi Club.
