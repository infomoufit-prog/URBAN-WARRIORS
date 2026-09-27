# KOMBAX Fase 0 · Package Report · R81 build 20134

## Identidad

- Release funcional: R81
- Fase: 0 · auditoría / freeze base
- Build: 20134
- Base de entrada: `KOMBAX_20133_R81_TAP_TO_PAY_ANDROID_IPHONE_ACCUMULATIVE_FINAL.zip`
- SHA-256 base de entrada: `423e4b7293edd868011433eb08916e3357c5754c98e8bc0d54179c298c7f6f96`

## Cierre

- Corrección `BuildConfig.DEBUG`: aplicada.
- Gate Fase 0: 11/11 PASS.
- Gate R81: 41/41 PASS.
- `npm run release:build`: PASS.
- Build: 466 archivos con paridad exacta `web = dist = Android assets`.
- I18N: 0 unresolved; 8 idiomas preservados.
- Secret/signing scan: PASS, 0 secretos/piezas privadas detectadas.
- Android preflight: 4/5; firma local excluida por diseño.
- Swift source parse: PASS.
- Supabase: contratos R81 live + health build 20134 verificados.

## Manifest

El manifest SHA-256 cubre todos los archivos del proyecto salvo el propio archivo de manifest. La cantidad final se rellena en el cierre previo al empaquetado.

- Archivos finales del proyecto: 4176
- Entradas SHA-256 del manifest: 4175

El checksum del ZIP se entrega como archivo `.sha256` externo para evitar autorreferencia.
