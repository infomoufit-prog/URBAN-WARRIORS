# KOMBAX RC13 · Build 20042
## Validación de branding de la pantalla de entrada

Fecha de validación: 2026-08-18
Base: RC13 build 20041
Build resultante: 20042

## 1. Alcance

La 20042 modifica únicamente la experiencia visual de la pantalla inicial en la que el usuario elige entre:

- Entrar con mi club.
- Crear o acceder a un perfil KOMBAX.

No introduce migraciones Supabase ni modifica contratos backend.

## 2. Branding de fondo

La pantalla principal usa los assets KOMBAX oficiales ya empaquetados en el proyecto:

- `assets/brand/kombax-symbol-red.png`
- wordmark `KOMBAX` renderizado con el sistema tipográfico del producto.
- tagline `Connect · Compete · Grow`.

La marca ambiental está marcada `aria-hidden=true`, no intercepta eventos (`pointer-events:none`) y queda por debajo del contenido interactivo.

## 3. Escritorio / PWA

En viewport desktop:

- símbolo/wordmark de fondo con escala editorial de 330–610 px;
- halo rojo integrado en el hero;
- logo de esquina aumentado a 60×60 px;
- símbolo interior aumentado a 42×42 px;
- wordmark de cabecera aumentado a 23 px;
- marcas compactas de directorio/perfiles aumentadas a 50×50 px.

El contenido de acceso permanece en z-index superior y conserva sus dos rutas originales.

## 4. Tablet y móvil

Tablet:

- marca de fondo conserva presencia con menor opacidad;
- el bloque introductorio limita su ancho para mantener legibilidad.

Móvil:

- se conserva únicamente el símbolo ambiental;
- wordmark/tagline gigantes se ocultan;
- opacidad del símbolo se reduce a 0.10;
- los tamaños de cabecera móvil existentes se mantienen para no saturar el viewport.

No se ha usado una simple reducción proporcional del layout desktop.

## 5. Regresión automática

Nueva prueba:

- `scripts/test-kombax-20042-gateway-brand.mjs`

Verifica:

- build/versionCode/cache busting 20042;
- uso de asset oficial KOMBAX;
- presencia del escenario de marca;
- accesibilidad decorativa;
- jerarquía z-index y ausencia de interceptación táctil;
- tamaños desktop/PWA;
- adaptación tablet/móvil;
- conservación de las dos rutas de acceso originales.

Resultado:

- `KOMBAX BUILD 20042 GATEWAY BRAND STAGE: PASS`
- suite histórica RC4 → 20042: PASS.

## 6. Build determinista

`node scripts/build.mjs`:

- `OK build 62 archivos · web = dist = Android`

## 7. Smoke HTTP

Servidor local aislado:

- `http://127.0.0.1:4176`

Comprobado:

- `index` usa `v=20042`: OK
- markup `gateway-brand-watermark`: OK
- CSS `gateway-brand-watermark`: OK
- config `build: 20042`: OK

## 8. Android

Preflight:

- applicationId: OK
- versionCode 20042: OK
- web embebida: OK
- Firebase: OK
- firma release JKS: PENDIENTE LOCAL

Resultado: 4/5.

No se certifica APK/AAB firmada en este entorno.

## 9. Validación visual

La implementación queda cubierta por regresión estructural, responsive CSS y smoke HTTP. La validación estética final en PWA/ordenador y móvil corresponde al QA visual humano, especialmente para decidir si la opacidad/tamaño del watermark debe afinarse después de verla en los dispositivos reales.
