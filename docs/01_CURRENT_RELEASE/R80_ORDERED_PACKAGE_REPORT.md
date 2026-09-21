# KOMBAX R80 build 20131 · Informe de reorganización del paquete

## Objetivo
Ordenar el ZIP acumulativo R80 sin eliminar funcionalidad, código, documentación ni trazabilidad histórica.

## Resultado
- Archivos sueltos en raíz antes: **1.031**.
- Archivos esenciales en raíz después: **6**.
- Carpetas principales en raíz después: **10**.
- La documentación histórica ha sido movida a `docs/` y clasificada por finalidad.
- No se ha eliminado documentación histórica.
- Se conserva un mapa de movimientos en `docs/08_MANIFESTS_LOGS/ROOT_REORGANIZATION_MAP_R80.json`.

## Archivos que permanecen en raíz
- `.gitignore`
- `README.md`
- `package.json`
- `pnpm-lock.yaml`
- `netlify.toml`
- `PAYMENTS_R61_ENV.example`

## Carpetas principales
- `web/` — frontend/PWA fuente.
- `dist/` — build web.
- `android/` — proyecto Android y web embebida.
- `supabase/` — backend, migraciones y Edge Functions.
- `scripts/` — QA, build, auditorías y utilidades.
- `docs/` — documentación actual e histórica ordenada.
- `qa/` — evidencias QA estructuradas preservadas.
- `maintenance/` — documentación de mantenimiento.
- `load/` — recursos de pruebas de carga.
- `artifacts/` — artefactos históricos preservados.

## Validación posterior a la reorganización
- `npm test`: **PASS / EXIT 0**.
- `node scripts/build.mjs`: **PASS**.
- Paridad de build: **465 archivos · web = dist = Android**.
- Android preflight: **4/5**.
- Único pendiente Android: `android/keystore.properties` local de firma, deliberadamente no distribuido.

## Compatibilidad
Las referencias documentales usadas por scripts de prueba se actualizaron a sus nuevas rutas. La lógica funcional de KOMBAX R80 no se modificó.

## Continuidad
Este ZIP ordenado debe utilizarse como nueva base R80 build 20131 para cualquier fase posterior, sustituyendo al paquete R80 anterior desordenado.
