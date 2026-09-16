# KOMBAX Brand Heroes · Sistema visual oficial 20.100

## Regla de marca
La única marca gráfica autorizada dentro de los Heroes es `KOMBAX_BRAND.symbol`, actualmente `./assets/brand/kombax-symbol-white.png`. Las fotografías son ambiente/editorial y nunca sustituyen el isotipo. No usar lobos, escudos ni logos generados como marca KOMBAX.

## Arquitectura
Componente compartido: `web/js/ui/brand-hero.js`.
Estilos: `web/css/kombax-brand-heroes.css`.
Fondos locales: `web/assets/brand-heroes/`.

El copy, logo, botones e iconos son HTML/SVG de la aplicación. Esto permite responsive, accesibilidad, traducción y futuras modificaciones sin regenerar imágenes.

## Social
- Fondo: peleador individual sobre atmósfera oscura, sin logo de club ni texto incrustado.
- Color: rojo KOMBAX.
- Claim: `CONNECT · COMPETE · GROW`.
- Headline: `Tu red. Tu legado.`
- Intención: identidad pública, comunidad, actualidad, red y conversación.

## Events
- Fondo: dos luchadoras MMA en careo.
- Color: cian neón + firma roja KOMBAX.
- Claim: `FROM HYPE TO HISTORY`.
- Headline: `El espectáculo no empieza en el ring. Empieza aquí.`
- Intención: máxima intensidad visual de la plataforma; hype, entradas, Fight Card, teaser, álbum, Live, resultados e historia.

## Showcase
- Fondo: atleta editorial.
- Color: oro/cobre sobre negro.
- Claim: `DESCUBRE · PROMOCIONA · DESTACA`.
- Headline: `Muestra. Promociona. Destaca.`
- Intención: exposición profesional de perfiles, productos, servicios y oportunidades.

## Motion
- `kxHeroBreathe`: movimiento de cámara extremadamente lento.
- `kxHeroParticle`: partículas luminosas leves.
- `kxHeroEdge`: línea de energía inferior.
- Todo queda desactivado con `prefers-reduced-motion: reduce`.

## Responsive
Desktop prioriza copy izquierda + sujeto derecha. En móvil la fotografía se reencuadra y el degradado se vuelve vertical para proteger lectura y zonas táctiles.
