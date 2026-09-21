# QA Validation · KOMBAX 20.101 R19

## Criterio de aceptación
R19 no se considera cerrada por la mera existencia de SQL o imágenes. Deben quedar demostrados datos reales, Storage público, salida del RPC de Showcase, aislamiento por club, build completa y paquete Android consistente.

## Backend / Supabase
### Marca y proveedor
- Marca Showcase real: Urban Warriors.
- Sujeto: club.
- Club: `11111111-1111-4111-8111-111111111111`.
- Perfil Social proveedor activo, visible, verificado y con contacto habilitado.

### Seed real
Migración aplicada: `kombax_showcase_urban_warriors_demo_products_20101_r19`.

Prueba tras aplicación y segunda ejecución idempotente:
- total_rows = 3
- unique_slugs = 3
- unique_images = 3
- urban_rows = 3
- published_rows = 3
- contact_rows = 3
- foreign_club_rows = 0

### RPC público
`app_kombax_showcase_list_v054` devuelve los tres productos con:
- `marca_nombre = Urban Warriors`
- categoría correcta
- precio EUR correcto
- `cta_tipo = contact`
- `cta_label = Me interesa`
- `proveedor_social_id` de Urban Warriors
- URL pública de imagen

### Permisos
- Listado Showcase: anon EXECUTE permitido, como corresponde al escaparate público.
- Mutación Showcase: anon EXECUTE denegado; authenticated permitido.

## Storage
Los tres objetos fueron comprobados físicamente en `storage.objects` con MIME `image/webp`.

Prueba HTTP real de las tres URLs públicas:
- Casco: HTTP 200 · image/webp
- Guantes: HTTP 200 · image/webp
- Whey demo: HTTP 200 · image/webp

La función temporal usada únicamente para la carga inicial fue neutralizada: exige JWT y responde `410 disabled`; no queda una ruta anónima de subida operativa.

## Test dedicado R19
`node scripts/test-kombax-20101-showcase-urban-products-r19.mjs`

Resultado: PASS 14/14.

Incluye comprobaciones de:
- 3 assets locales.
- hashes distintos.
- paridad Web/Dist/Android.
- vendedor Urban Warriors.
- 3 categorías.
- 3 slugs idempotentes.
- precios.
- CTA de contacto.
- aviso nutricional y ausencia de macros inventados.
- conversación Showcase vinculada al producto.
- modelo no transaccional preservado.
- aislamiento por club.
- cache R19.
- R18 Urban Realism preservado.

## Regresión completa
`npm run build`

Resultado final: PASS.

Salida de build:
`OK build 165 archivos · web = dist = Android`

Toda la cadena heredada R7–R18 y R19 dedicado pasó después de actualizar únicamente las expectativas históricas de cache para aceptar R19.

## Android preflight
`npm run android:preflight`

Resultado: 4/5.
- package identity `com.urbanwarriors.app`: PASS
- versionCode 20101: PASS
- assets/www embebidos: PASS
- Firebase: PASS
- firma local: PENDING, falta `android/keystore.properties`

El JKS release permanece incluido en `LOCAL_RELEASE_SIGNING/`. No se incluyen contraseñas.

## Advisors Supabase
Security y Performance ejecutados después de la intervención.

R19 es una migración de datos, no crea nuevas tablas/RPC/RLS. Los advisors continúan mostrando avisos históricos/globales del proyecto (SECURITY DEFINER/search_path/RLS en arquitectura RPC, protección de contraseñas filtradas desactivada, foreign keys sin índice, índices sin uso y un índice duplicado en Finanzas). No se declara el proyecto “limpio”.

Referencia de remediación:
https://supabase.com/docs/guides/database/database-linter

## Estado de validación
VALIDADO técnicamente en backend, Storage, RPC, tests y build.

PENDIENTE de aceptación visual del usuario en:
- PWA/PC desplegada.
- APK generada desde R19 e instalada en dispositivo.

No se afirma aprobación visual en dispositivo hasta realizar esas pruebas.
