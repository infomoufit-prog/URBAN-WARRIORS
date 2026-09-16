# KOMBAX 20.101 R37 · Packaging Certification

## Fuente certificada
Raíz: `KOMBAX_20101_R37_CONTINUITY_SOURCE/`

## Gates superados antes del empaquetado
- R37 QA: PASS 62/62.
- Full regression: exit 0.
- Build: 189 archivos.
- Paridad: web = dist = Android assets/www, 189/189/189, 0 diferencias SHA-256.
- Android preflight: 4/5, pendiente exclusivamente firma local.
- Supabase R37 live: migraciones 223–226 equivalentes aplicadas y auditadas.
- RLS: tablas R37 protegidas; RPC privadas sin `anon`.
- Brand public projection: única superficie R37 explícitamente pública.
- Peso/preparación privada: no referenciada por RPC Brand R37.

## Seguridad del artefacto
- Sin `.env`.
- Sin `android/keystore.properties` real.
- Sin JKS/keystore privado.
- Sin symlinks.
- Sin nombres/rutas incompatibles con Windows detectados.
- Las credenciales privadas/secretas de backend no forman parte del paquete. La configuración cliente publicable necesaria para el runtime web no se considera una credencial privada.

## Acciones no ejecutadas
- No Netlify deploy.
- No GitHub push.
- No APK/AAB firmado.
