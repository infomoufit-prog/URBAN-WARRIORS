# KOMBAX RC13 · build 20043

## Privacidad de Relaciones
- `Relaciones` deja de ser una superficie pública de KOMBAX Social.
- El perfil público no muestra lista de relaciones ni contador total.
- La afiliación verificada Club ↔ Miembro se mantiene independiente y puede seguir siendo visible según su configuración.
- La sección privada pasa a denominarse `Mis relaciones` y explica expresamente que la red no constituye una métrica pública de popularidad.

## Backend
- Nuevo RPC `app_kombax_relaciones_v068(uuid)` con control de identidad: solo una cuenta autorizada para actuar como esa identidad Social puede consultar su red.
- Nuevo perfil público `app_kombax_perfil_publico_v068(uuid)` que elimina por contrato la clave `relations`.
- Se revoca `EXECUTE` a clientes autenticados sobre los RPC históricos de perfil/relaciones que podían saltarse la nueva regla de privacidad.
- `anon` no puede ejecutar los RPC 068.

## QA
- Nueva regresión `test-kombax-20043-relations-privacy.mjs`.
- Se actualizan únicamente las regresiones históricas que exigían versiones RPC concretas incompatibles con el nuevo contrato de privacidad, conservando el resto de garantías funcionales.
- La suite completa RC4→20043 debe permanecer PASS antes de empaquetado final.
