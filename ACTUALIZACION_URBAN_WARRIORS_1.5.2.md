# Actualización Urban Warriors 1.5.2

## Estrategia para conservar Netlify

No desplegar esta versión todavía. Primero se corrige y prueba el backend directamente en Supabase, lo que no consume un deploy de Netlify.

### Puerta 1 — Backend

Ejecutar `012_operational_integrity_v152.sql`. Después ejecutar `PRUEBA_REAL_BACKEND_V152.sql`. Solo continuar si el JSON devuelve `"ok": true` y todos los valores de `storage` son `true`.

### Puerta 2 — Único deploy web

Subir `urban-warriors-v1.5.2-parche-final.zip` a GitHub y esperar un solo deploy de Netlify. Probar en incógnito: grupo con dos horarios, alta directa, publicación con imagen, material con imagen, cuota/cobro/justificante, preinscripción/aprobación y portal familiar.

### Puerta 3 — Firebase y APK

Una vez superada web, añadir credenciales Firebase, validar push real y compilar/firma release. No se deben subir al repositorio público la cuenta de servicio, el keystore ni sus contraseñas.
