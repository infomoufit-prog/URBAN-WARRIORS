# KOMBAX 20.101 R9 · Visual Hero Correction

## Alcance
Intervención acumulativa sobre R8. No se rehace ninguna pantalla ni se modifica la lógica funcional de Social, Events, Showcase, Supabase, RLS, finanzas o firma.

## 1. Entrada · imagen y humo
### Causa raíz
Una regla antigua `.gateway-brand-stage>:not(.gateway-brand-watermark)` tenía mayor especificidad que la regla R7 de `.gateway-entry-visual`. Esa regla forzaba el contenedor visual nuevo a `position: relative`, mientras sus hijos seguían siendo absolutos. Resultado: el espacio quedaba reservado, pero la foto y el humo podían no ocupar la superficie real del hero.

### Corrección
- Selector directo de mayor especificidad: `.gateway-brand-stage>.gateway-entry-visual`.
- Asset resuelto con `new URL(..., import.meta.url)` para navegador local, PWA y WebView Android.
- Fallback CSS con la misma imagen aprobada.
- Logo/watermark antiguo desactivado en la entrada.
- Dos capas de humo reales (roja y azul) con múltiples gradientes, blur y animaciones independientes.
- Humo reforzado a una opacidad visible pero controlada, sin GIF, vídeo, canvas ni WebGL.
- `pointer-events:none` en todo el sistema decorativo.
- Cache bust R9 (`20101r9` / `media-r9`) para evitar que una copia antigua oculte la corrección.

## 2. KOMBAX Social · encuadre del peleador
- Peleador ampliado.
- Desplazado hacia el interior para que tenga un peso visual comparable a Events y Showcase.
- Crop desktop reajustado a `76% 30%`.
- Escala desktop `1.125` con traslación controlada.
- Crop móvil específico `76% 18%` con escala propia.
- Humo de Social ligeramente reforzado para que la atmósfera sea perceptible sin competir con el copy.

## 3. Noche de Impacto · Main Event vs organizadores
- La zona inferior derecha de la portada de detalle queda reservada para organizadores y avales.
- El teaser del combate estelar se compacta dentro de la columna izquierda.
- Retratos del teaser reducidos de forma controlada para mantener jerarquía sin invadir la zona institucional.
- Tarjetas de organizadores compactadas y recolocadas.
- El hero admite hasta 3 entidades que organizan + 3 que avalan (máximo 6 visibles) antes de remitir al bloque completo de Organización.
- Responsive: en tablet se usa una columna institucional; en móvil deja de ser absoluta y se apila sin solapes.

## Garantías de regresión
- `npm run build`: PASS.
- 148 archivos: `web = dist = Android`.
- R6 Events: PASS.
- R7 Atmospheric Hero: PASS.
- R8 Urban Warriors Jiu-Jitsu Event: PASS.
- R9 Visual Hero Correction: PASS.
- No se han cambiado tablas, migraciones, RPC, RLS, Edge Functions ni ownership de eventos.
