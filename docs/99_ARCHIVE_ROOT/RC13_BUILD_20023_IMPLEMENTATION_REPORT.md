# RC13 build 20023 · informe de implementación

## Alcance cerrado

Primera capa multiclub KOMBAX sobre el build estable 20022. Introduce una puerta pública y un modelo explícito de contextos sin alterar `applicationId com.urbanwarriors.app`, `versionName 2.0.0-rc.13`, nombre o icono instalados. No abre todavía perfiles directos, KOMBAX Social, Showcase ni cobros.

## Implementado

- Puerta general con presentación profesional de KOMBAX y dos accesos claramente separados.
- Entrada mediante club: directorio por nombre, ubicación o disciplina; selección persistente; soporte para `?club=slug` y enlace/QR.
- Entrada directa: categorías competidor, marca, federación, espectador y profesional vinculada al deporte, visibles como arquitectura futura y bloqueadas con `PRÓXIMAMENTE`.
- Directorio seguro mediante `app_buscar_clubes_kombax_v040`, con un contrato de salida que excluye CIF, teléfonos, correo, direcciones administrativas y referencias externas.
- Urban Warriors como único perfil operativo conocido y cinco clubes ficticios marcados DEMO. Los datos demo se encuentran en un fixture SQL separado y prohibido en producción.
- Modelo desacoplado para perfil directo, capacidades, suscripciones y entitlements, sin precios ni checkout.
- Selector de club autenticado solo para membresías activas; al cambiar de tenant invalida caché, estado y contrato anterior antes de cargar el nuevo contexto.
- Co-branding en login/registro y temas de vista previa sin mezclar datos entre clubes.
- Migración 040 con preflight, verificación de solo lectura, prueba transaccional y rollback conservador.

## Garantías y límites deliberados

- Una tarjeta DEMO no abre el login de un tenant ni simula un alta real.
- El frontend no concede acceso: la membresía y el contexto se resuelven en el backend.
- Los perfiles directos no tienen registro, publicación, suscripción ni pago en esta fase.
- La tabla de suscripciones es un estado de dominio preparado; no existe proveedor de pago ni precio inventado.
- KOMBAX Social y Showcase permanecen detrás de feature flags apagadas.
- El objetivo de 100 clubes es un criterio de diseño. No se declara capacidad certificada sin carga real, monitorización y evidencia de base de datos.

## Evidencia local de cierre

- Sintaxis de todos los módulos `web/js`: exit code 0.
- Suite estática completa: 33 scripts, exit code 0.
- `scripts/build.mjs`: 57 archivos, hashes idénticos entre `web`, `dist` y Android.
- `git diff --check`: sin errores.

## Estados que no deben confundirse con validación real

- Migración 040 en Supabase real: **NO EJECUTADO**.
- Prueba SQL transaccional 040: **PENDIENTE DE ENTORNO**.
- Validación visual manual del build 20023: **PENDIENTE**.
- Compilación Android Gradle: **PENDIENTE DE ENTORNO**.
- Firma con JKS y verificación pública: **PENDIENTE DE AUTORIZACIÓN / ENTORNO**.
- APK/AAB e instalación física: **PENDIENTE**.
- Netlify: **NO DESPLEGADO**.

## Orden de backend propuesto

Solo tras autorización y sobre una copia de seguridad verificada: preflight 040 → migración 040 → verificación 040 → prueba transaccional 040. El fixture `supabase/fixtures/040_demo_clubs.sql` es exclusivamente local/QA y no forma parte del despliegue de producción.
