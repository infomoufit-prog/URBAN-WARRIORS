# KOMBAX 20.110 R60 · Frontend UI Stabilization

Base: `KOMBAX_20110_R60_MIGRATIONS_GUIDE_HISTORY_QA_ANDROID_FIX`.

## Alcance aplicado

Esta corrección es exclusivamente frontend. Mantiene la identidad de release R60 / build 20110 y preserva el Android Gradle fix de la R60 corregida.

### 1. Safe areas y barras Android
- Se mantiene `viewport-fit=cover`.
- Se añade una capa CSS final y centralizada para consumir `--uw-safe-top` / `--uw-safe-bottom` (que ya combinan `env(safe-area-inset-*)` con los insets nativos del WebView Android).
- Cabecera móvil: reserva la barra de estado.
- Tab bar: reserva la navegación inferior del sistema.
- `main-view`: reserva tab bar + safe area + margen de respiración para que el último contenido siga siendo accesible.
- Se usa `100dvh` en el shell móvil.

### 2. Overflow horizontal
- Contención global de wrappers sin ocultar el scroll intencional de filtros.
- Showcase: categorías con scroll horizontal, inercia táctil, snap y degradado de continuidad.
- Events: pestañas de estado y navegación de detalle con scroll horizontal controlado.
- `Gestionar evento`: ancho máximo y comportamiento seguro en móvil.
- `MAIN EVENT`: crown, columnas y nombres largos pueden reducirse/wrap sin cortar el segundo combatiente.

### 3. Contenido tapado por tab bar
- La reserva inferior se resuelve en el layout central y cubre Social, Showcase, Events y el resto de vistas dentro de `main-view`.
- Se actualiza también la posición de los toast para no quedar detrás de la tab bar.

### 4. KOMBAX Migrations en Mi Club
- `.kx-migration-banner` recibe contenedor de tarjeta, separación real entre kicker/título/descripcion y CTA responsive.
- Corrige visualmente la concatenación `KOMBAX MIGRATIONS¿Vienes...` sin cambiar la lógica de Migrations.

### 5. Tema oscuro
- `.metric.metric-light` deja de introducir una tarjeta blanca dentro del shell oscuro.

### 6. Contraste
- Nuevo baseline `--kx-readable-muted: #aeb6c2` en los textos secundarios de superficies oscuras relevantes.
- Contraste medido: 8.70:1–9.91:1 sobre los fondos oscuros principales de KOMBAX, por encima de WCAG AA 4.5:1.

### 7. Navegación
**NO MODIFICADO por decisión del fundador.**
- No se cambia la tab bar.
- No se cambia el menú lateral.
- No se reagrupan entradas.
- No se modifica la jerarquía ni el routing.

### 8. Lenguaje de selección de perfiles
- Se eliminan textos de arquitectura/modelo de datos visibles al usuario.
- Descripciones centradas en lo que consigue Club, Competidor, Federación, Profesional, Marca, Media/Creador y Espectador.
- Se indica que una cuenta puede tener más de una identidad KOMBAX.

### 9. Entrada / onboarding
- La entrada principal se expresa por rol: `Gestiono un club` / `Soy deportista, profesional o marca`.
- `Conocer KOMBAX` sigue siendo opcional.
- El explicador opcional se reduce de 4 bloques a un máximo de 3; beneficios se integran en el tercer bloque.
- Se conservan los IDs y acciones existentes, por lo que no cambia funcionalidad.

### 10. Densidad y orden de perfiles
Orden visual:
1. Club
2. Competidor
3. Federación
4. Profesional
5. Marca
6. Media / Creador

Las tarjetas son más compactas en escritorio y móvil sin reducir los objetivos táctiles principales.

### 11. Estados de revisión
Se añade explicación visible dentro de cada solicitud para:
- Enviada
- En revisión
- Falta información
- Verificado
- Rechazado

No se inventa un SLA/plazo que no exista en operación.

### 12. Datos QA
No se encontraron en el frontend los literales:
- `QA-CLUB-001`
- `NORA VEGA`
- `COMPETIDORA QA`
- `[QA TEST]`
- `Vídeo de prueba`

Por tanto, no se ha ocultado ni borrado información procedente del backend. Esto respeta la restricción de no tocar backend.

## Archivos fuente runtime modificados
- `web/index.html`
- `web/css/kombax-ui-stabilization-r60.css` (nuevo)
- `web/js/core/profile-registry.js`
- `web/js/modules/gateway.js`
- `web/js/public-product-overview.js`

`dist/` y `android/app/src/main/assets/www/` son espejos regenerados de `web/` mediante `scripts/build.mjs`.
