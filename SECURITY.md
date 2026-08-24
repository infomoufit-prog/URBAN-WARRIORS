# Seguridad · KOMBAX / Urban Warriors RC13 build 20070

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
- Activación voluntaria con normas versionadas.
- Likes sin identidad pública.
- Contacto protegido por aceptación previa y bloqueos; la mensajería conserva canal y contexto de producto.
- Backend bloquea contacto con perfiles personales menores de 18 años.
- Bloqueo, denuncia, suspensión y moderación dejan trazabilidad; suspender Social no suspende el club.

## Showcase

- Lectura mediante RPC de campos explícitos.
- Gestión por gestor o perfil marca verificado con entitlement.
- Alta/verificación/destacado reservados a moderación global.
- Solo URLs HTTPS; sin datos ni funciones de transacción comercial.

## Android/web

- `usesCleartextTraffic=false` y origen WebView HTTPS virtual.
- Netlify define CSP restrictiva, HSTS, aislamiento de apertura, bloqueo de frames y caché desactivada para runtime.
- La telemetría 20070 elimina claves sensibles y solo acepta incidencias autenticadas con límite de frecuencia.
- Firma release solo desde configuración local/entorno.

## Administración y verificación

- El acceso Owner requiere contraseña reciente, challenge y sesión administrativa ligada a la sesión Auth; no usa OTP por correo.
- Moderación de contenido y acceso a documentos privados son permisos separados.
- Los documentos de verificación solo pueden leerlos su propietario, un verificador activo o una sesión Owner activa.
- El panel de piloto mantiene `NO-GO` hasta registrar evidencia individual de SMTP, legal, MFA, backup, restauración, monitorización y respuesta a incidentes.

## Pendiente externo

Completar SMTP propio, identidad jurídica, MFA Owner, backup externo y simulacro, monitorización, Data Safety/UGC en Play Console, firma Android y carga real antes de afirmar producción. Supabase Pro queda expresamente fuera de esta build.
