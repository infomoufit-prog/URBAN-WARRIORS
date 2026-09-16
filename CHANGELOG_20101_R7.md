# Changelog · KOMBAX 20.101 R7 · Gateway Atmospheric Hero

## Entrada KOMBAX
- Integrada la composición multi-deportista aprobada como hero de entrada.
- El antiguo watermark grande se conserva únicamente como compatibilidad histórica no visible; ya no forma parte de la composición mostrada.
- Asset final: `web/assets/brand-heroes/gateway-kombax-community.webp`.
- Optimización: PNG de origen ≈2,3 MB → WebP 184.038 bytes.
- H1 reequilibrado: máximo visual de 64 px en desktop.
- Nueva máscara de profundidad para proteger la lectura del copy.
- Dos capas de humo/bruma CSS con movimiento independiente rojo/azul.
- Glow respiratorio ambiental sutil.
- `loading=eager` + `fetchpriority=high` para el visual principal.

## Responsive
- Desktop: arte a la derecha y copy a la izquierda.
- Tablet: menor opacidad y máscara más protectora.
- Móvil ≤620 px: la imagen pasa a bloque panorámico propio antes del copy.
- Móvil ≤420 px: altura limitada a 184 px para preservar accesos.
- Todos los overlays son decorativos y no interceptan gestos.

## KOMBAX Social / Events / Showcase
- Añadidas dos capas de humo animado al motor Brand Hero compartido sin generar imágenes nuevas.
- Social: intensidad media y ritmo equilibrado.
- Events: intensidad superior y movimiento más vivo.
- Showcase: intensidad más baja y velocidad más lenta/elegante.
- Showcase alinea su micro-claim a `MUESTRA · PROMOCIONA · DESTACA`.
- Se mantienen fotos, CTA, features y lógica existentes.

## Accesibilidad y rendimiento
- Animaciones basadas en `transform`/`opacity` y gradientes CSS.
- Sin GIF, vídeo, WebGL ni dependencia nueva.
- `prefers-reduced-motion` desactiva el motion atmosférico.
- El asset de entrada queda por debajo del presupuesto de 500 KB.

## Compatibilidad
- Sin migraciones SQL.
- Sin cambios Supabase / RLS / RPC / Edge Functions.
- Sin cambios en permisos o entitlements.
- Accesos `Entrar con mi club` y `Solicitar o gestionar un perfil KOMBAX` conservan bindings existentes.
- Build funcional continúa siendo 20101; revisión visual R7.
