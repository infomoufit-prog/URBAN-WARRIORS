# Packaging Certification · KOMBAX 20.101 R35

Paquete de continuidad preparado para ser la siguiente base de trabajo.

## Estado certificado antes de comprimir

- R35: 39/39 PASS.
- R34: 33/33 PASS.
- R33.1: 27/27 PASS.
- R33: 52/52 PASS.
- R32: 36/36 PASS.
- `npm run build`: exit 0, 0 FAIL/Error en log final.
- `web = dist = Android`: 186/186/186; missing 0, extra 0, hash diff 0.
- Supabase R35 218/219: aplicado live y auditado.
- Android identity: `com.urbanwarriors.app`, versionCode 20101, versionName 2.0.0-rc.13.
- Android preflight: 4/5; firma local privada pendiente.
- Secret scan: sin JKS, keystore real, `.env` ni claves privadas empaquetadas.
- Netlify/GitHub/Google Play: no modificados por este cierre.

El SHA-256 exterior del ZIP se entrega en un archivo `.sha256` separado para evitar una referencia circular dentro del propio paquete.
