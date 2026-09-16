# Packaging Certification · KOMBAX 20.101 R32

## Contenido obligatorio
- código fuente web/PWA;
- `dist` construido;
- assets Android sincronizados;
- proyecto Android;
- migraciones locales R29-R31 y trazabilidad live R28;
- pruebas R28-R32;
- logs de regresión, build, smoke y Android preflight;
- Plan Maestro PDF y transcripción Markdown;
- planes de implementación R28-R32;
- documentación de continuidad y QA.

## Exclusiones de seguridad
El paquete final NO debe contener:
- `.git`;
- `node_modules`;
- `android/keystore.properties`;
- `*.jks` / `*.keystore`;
- `.env`;
- `*.pem` / `*.p12`;
- outputs firmados generados con secretos locales.

## Certificación
- tests: PASS;
- build: PASS;
- paridad: PASS;
- smoke local: PASS;
- backend RLS/grants/RPC: PASS dirigido;
- Android preflight: 4/5, pendiente únicamente firma local;
- Android físico: pendiente del propietario;
- GitHub/Netlify: no ejecutados.

El SHA-256 del ZIP se entrega como archivo compañero externo, porque incrustar el hash del propio ZIP dentro de él modificaría el hash.
