# Final Packaging Certification · KOMBAX 20.101 R3

## Contenido esperado
- fuente web/PWA 20.101 R3;
- `dist/` generado;
- assets Android sincronizados;
- tests y build scripts;
- migraciones Supabase hasta 178;
- assets del evento de validación;
- documentación R3;
- JKS existente solicitado en `LOCAL_RELEASE_SIGNING/`.

## Material excluido deliberadamente
- `.env` reales;
- `node_modules`;
- `android/keystore.properties` real;
- contraseñas de firma;
- PEM/P12/PFX y claves privadas adicionales.

El JKS existente es la excepción explícita solicitada por el propietario para traslado de PC. No se genera ni sustituye.

## Estado de release
- `npm test`: PASS.
- `npm run build`: PASS.
- `web = dist = Android`: 132 archivos.
- legal gate: PASS.
- Android preflight: 4/5 por credenciales locales.
- Supabase migración 178: aplicada.
- Netlify: no desplegado.
- Google Play: no publicado.

## Manifiesto
- archivos regulares del paquete final, incluido el propio manifiesto: 1469;
- entradas SHA-256 cubiertas: 1468;
- el manifiesto se excluye a sí mismo para evitar autorreferencia;
- verificación `sha256sum -c`: PASS antes de crear el ZIP.
