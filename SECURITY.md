# Seguridad · KOMBAX / Urban Warriors RC13 build 20025

## Autoridad y secretos

- Auth real y `Authorization` de sesión.
- Ninguna `service_role` en frontend.
- JKS, contraseñas, `google-services.json`, `.env`, APK y AAB excluidos.
- La UI oculta acciones, pero SQL/RPC vuelve a validar sujeto, club, rol, gestor y entitlement.
- Mutaciones con `request_id` y respuesta verificable.

## Tenant

- Recursos privados con `club_id`, membresía activa y RLS.
- Cambio de club limpia estado y caché antes de aceptar el nuevo contrato.
- Directorio 040 devuelve solo nombre, marca pública, ubicación declarada, tema y disciplinas.
- Fixtures sintéticos nunca otorgan membresía real.

## Privacidad social

- Expediente, DOB, email, teléfono, domicilio, finanzas, documentos y familia no se proyectan al perfil público.
- Activación voluntaria con normas 1.1.
- Likes sin identidad pública.
- Contacto limitado a una solicitud de 10–500 caracteres; no crea hilo, presencia ni mensajería.
- Backend bloquea contacto con perfiles personales menores de 18 años.
- Bloqueo, denuncia, suspensión y moderación dejan trazabilidad; suspender Social no suspende el club.

## Showcase

- Lectura mediante RPC de campos explícitos.
- Gestión por gestor o perfil marca verificado con entitlement.
- Alta/verificación/destacado reservados a moderación global.
- Solo URLs HTTPS; sin datos ni funciones de transacción comercial.

## Android/web

- `usesCleartextTraffic=false` y origen WebView HTTPS virtual.
- Netlify añade cabeceras defensivas básicas, bloquea frames y evita caché del runtime; una CSP completa queda pendiente de validación contra Supabase/medios antes de producción.
- Firma release solo desde configuración local/entorno.

## Pendiente externo

Aplicar 037–042, probar RLS con cuentas reales, validar dispositivo/FCM, revisar privacidad/Data Safety/UGC en Play Console y ejecutar carga real antes de afirmar producción.
