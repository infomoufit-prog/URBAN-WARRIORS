# KOMBAX 20.084 · Revisión de secretos y supply chain

## Revisión realizada

Búsqueda conectada en GitHub de patrones de alto riesgo:
- `service_role`: sin coincidencias indexadas.
- `BEGIN PRIVATE KEY`: sin coincidencias indexadas.
- `storePassword`: sin coincidencias indexadas.
- `UW_KEYSTORE_PASSWORD`: sin coincidencias indexadas.

El proyecto Android de referencia obtiene credenciales de firma desde `keystore.properties` o variables `UW_*`; no deben subirse valores reales al repositorio.

El `anonKey`/publishable key de Supabase sí está en el cliente por diseño. No es un secreto y su seguridad depende de RLS, grants y contratos del backend.

## Limitación

La búsqueda de GitHub puede no indexar todos los archivos/histórico. Por eso el control `secrets_repository_review` permanece **pending** hasta ejecutar, sobre el checkout completo utilizado para el release:
- búsqueda local del árbol y del historial relevante;
- revisión de `.env`, backups, ZIPs, logs y archivos de Android;
- comprobación de que JKS/keystore y sus contraseñas están fuera del repositorio;
- revisión de variables Netlify/Supabase/FCM sin imprimir sus valores.

No registrar secretos como “evidencia” dentro de KOMBAX. La evidencia debe ser un resultado de auditoría, fecha, commit/build o referencia interna, nunca la credencial.

## Escaneo del paquete 20.084 generado

En el árbol del candidato se comprobó además:
- 0 archivos `.jks`, `.keystore`, `.pem`, `.p12`, `.key` o `.env`.
- 0 literales de clave privada / `sb_secret_*` / valor de `service_role key` detectados por los patrones de control.
- 0 usos de `eval()` o `new Function()` en el hardening cliente 20.084.

Esto valida el **paquete**, no sustituye el escaneo del checkout completo que se usará para construir el release final.
