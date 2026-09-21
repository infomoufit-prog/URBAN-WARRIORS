# KOMBAX R81 build 20133 · Informe de paquete acumulativo

## Propósito

Paquete final acumulativo preparado para:

- presentación a clientes;
- nueva base maestra de desarrollo;
- subida a GitHub;
- build/deploy en Netlify;
- apertura en Android Studio y generación APK/AAB;
- continuación del proyecto iOS en Xcode.

## Estructura

La raíz mantiene solo seis archivos de configuración/entrada y las carpetas funcionales del producto. La documentación histórica permanece ordenada dentro de `docs/`.

| Carpeta | Función |
|---|---|
| `web` | frontend/PWA fuente |
| `dist` | build listo para Netlify |
| `android` | app Android + Tap to Pay nativo + assets sincronizados |
| `ios` | base iOS WKWebView + Tap to Pay on iPhone |
| `supabase` | migraciones y Edge Functions backend |
| `scripts` | QA, build, i18n y release tooling |
| `docs` | documentación actual e histórica, guías y manifests |
| `qa` | evidencias QA acumulativas |
| `maintenance` | handoff/mantenimiento histórico |
| `load` | pruebas de carga |
| `artifacts` | artefactos históricos preservados |

## Inventario previo al manifest

- 4.159 archivos de contenido antes de crear el manifest final.
- 299 directorios.
- Tamaño de trabajo sin comprimir aproximado: 161 MB.
- `web`: 466 archivos.
- `dist`: 466 archivos.
- `android`: 502 archivos.
- `ios`: 7 archivos fuente/configuración.
- `supabase`: 673 archivos acumulativos.
- `docs`: 1.660 archivos acumulativos/históricos.

## Validación final

- R81 contract: 40/40 PASS.
- Full cumulative `npm test`: PASS.
- Exact Netlify command `npm run release:build`: PASS.
- `web = dist = Android`: 466/466/466 archivos del bundle web.
- Android preflight: 4/5; firma privada local excluida.
- Swift syntax parse: PASS.
- PDF R81: 14 páginas, preflight/render/visual PASS.
- Live Supabase R81: migration/RPC/tables/functions verified.
- Secret/signing scan: PASS.

## Elementos deliberadamente no incluidos

- `android/keystore.properties` real;
- JKS/keystore privado;
- `.env` real;
- Stripe secret keys;
- certificados/p12/provisioning Apple;
- credenciales de GitHub/Netlify/Supabase.

Estos elementos se mantienen fuera del paquete por seguridad y se restauran/configuran en el entorno autorizado de despliegue.
