# KOMBAX 20.101 R19 · Showcase Urban Warriors Products

## Base
KOMBAX 20.101 R18 · Urban Warriors Realism.

## Implementado
- Urban Warriors utiliza su marca Showcase real como vendedor de tres productos ficticios de demostración.
- Producto 1: Casco Integral Urban Warriors Pro · Protecciones · 79,90 EUR.
- Producto 2: Guantes Integrales Urban Warriors Elite · Equipamiento · 64,90 EUR.
- Producto 3: Whey Protein Recovery Blend Urban Performance · Nutrición deportiva · 49,90 EUR.
- Cada ficha utiliza `cta_tipo=contact` y `Me interesa`, manteniendo el flujo comercial interno de Showcase por producto.
- Se conservaron las reglas no transaccionales: KOMBAX no procesa el pago de estos productos.
- Las tres imágenes se guardaron en `kombax-public-media` y también se empaquetaron en Web/Dist/Android para continuidad de build.
- El producto de nutrición se marca explícitamente como demo y no atribuye a la imagen generada macros/composición legal no verificados.

## Backend real
- Migración idempotente: `185_kombax_showcase_urban_warriors_demo_products_20101_r19.sql`.
- Aplicada al Supabase principal.
- 3/3 productos vinculados al club Urban Warriors.
- 3/3 publicados.
- 3/3 imágenes públicas HTTPS distintas.
- 3/3 CTA de contacto.
- 0 productos R19 vinculados a otro club.

## Storage
Objetos persistentes en el bucket público `kombax-public-media` bajo el namespace de Urban Warriors / Showcase / R19 demo.

## Frontend / paquetes
- Cache bust: `20101r19` / `media-r19`.
- Assets locales añadidos en `web/assets/demo-showcase/urban-warriors/`.
- Build determinista: Web = Dist = Android.

## No implementado
- No se añadió checkout, cobro o pasarela de pago.
- No se generó una APK Signed nueva dentro de esta intervención: falta restaurar localmente `android/keystore.properties`.
- No se generó un ejecutable Windows nativo; la versión PC incluida es la PWA/web estática.
