# KOMBAX 20178 · R118 FIX07 — Servicios y administración

Entrega acumulativa sobre FIX06. Esta guía sustituye los estados de entrega anteriores. Las guías FIX01–FIX06 quedan como historial. No se hizo push, despliegue Netlify, publicación Play ni cobro real.

## Qué incorpora

- Mi Espacio → Mis servicios: eventos/seminarios, ticketing, vendedor/Showcase/e-commerce y servicios de organización. Las cuentas gratuitas y Club Básico pueden solicitar servicios puntuales con identidad responsable verificada; no se exige una suscripción de club para preparar eventos o solicitar Commerce.
- Crear el perfil público gratuito y activar una suscripción son procesos distintos. Club, Marca y Federación pasan por verificación antes de contratar la prueba comercial de 30 días con tarjeta, consentimiento de renovación y Stripe. Los clubes piloto conservan su circuito separado, sus cuatro plazas y el alta autorizada verbalmente por Owner.
- Vendedor: identidad, verificación de vendedor, políticas y Stripe Connect son obligatorios antes de vender. Capacidad de catálogo y Commerce son derechos separados. El catálogo gratuito no recibe capacidad ilimitada. Se conserva la capacidad de referencias existentes; los bloques puntuales requieren autorización. Un perfil profesional conserva sus ofertas de servicios sin checkout de productos físicos; la cuenta gratuita debe usar una identidad vendedora compatible para productos.
- En piloto, las solicitudes puntuales de catálogo/Commerce siguen requiriendo revisión y activación por Owner. Solicitar no cobra, no aprueba automáticamente y no habilita ventas.
- Suscripción: Checkout recoge el método de pago; el retorno del navegador no concede servicios. Webhook firmado, idempotencia, precio consentido inmutable, prueba única, periodos de acceso, impagos y cancelación. Mis servicios permite al pagador gestionar su suscripción aunque pierda el vínculo con el club. El perfil público permanece independiente de la suscripción.
- Owner Social/Showcase: día, semana, autor/perfil/vendedor, club y tipo de perfil, incluido Competidor. Filtros en servidor antes de paginar; acordeones de diez contenidos con vista multimedia, edición y moderación.

## Comprobado

La puerta local de Netlify pasó 77 suites y compatibilidad de Linux: 364 archivos JavaScript, 855 importaciones; web, dist y assets Android iguales. Persisten tres P2 heredados de traducción, enumerados en el informe; npm test estricto todavía falla por esos P2. Los nuevos textos pasan los ocho idiomas.

Pruebas aisladas de base de datos: 19 filtros, 37 facturación y 22 servicios puntuales; 18 pruebas de los handlers reales de Stripe con dependencias simuladas. Navegador Chrome con datos simulados: 18 accesos, 18 moderación y 9 vendedor, sin errores de página. Estas pruebas no son altas, compras o correos reales de usuarios.

En Supabase se aplicaron cuatro migraciones nuevas y se desplegaron las dos funciones Billing. Se corroboró que no hay planes comerciales publicados ni suscripciones Billing de la aplicación y que el registro piloto existente permanece. No se editó contenido real de Social/Showcase.

En «Entorno de prueba de KOMBAX» se creó una suscripción trialing de 30 días con tarjeta ficticia guardada y factura inicial pagada de 0 €, además de una suscripción separada con factura de prueba pagada de 23,90 €. Esta última no demuestra la renovación de la prueba de 30 días. No se pudo avanzar el reloj ni ejecutar cancelación/impago reales por las herramientas disponibles. Esos cambios de estado sí se probaron aisladamente contra SQL. El flujo completo aplicación → Checkout → webhook aún no está certificado.

## Pendiente antes de habilitar facturación pública

Definir los precios oficiales (especialmente Marca/Federación), crear/seleccionar sus Stripe Price mensuales y publicar cada plan solo después de verificar moneda, importe y fiscalidad. La prueba de 23,90 € es un producto QA aislado y no configura los planes de la aplicación.

Configurar STRIPE_BILLING_SECRET_KEY, STRIPE_BILLING_ACCOUNT_ID, STRIPE_BILLING_WEBHOOK_SECRET y STRIPE_BILLING_TAX_READY en el entorno elegido; KOMBAX_APP_URL debe apuntar al origen HTTPS correcto de la aplicación. Registrar el destino /functions/v1/stripe-billing-webhook, con eventos Checkout/subscription/invoice, y configurar Customer Portal para cancelación y actualización del método de pago. Las claves de cobro Billing se separan de Stripe Connect. No poner secretos en GitHub. Habilitar Tax solo con configuración y registro fiscal verificados. Las funciones están desplegadas, pero no se han conectado ni certificado estas credenciales/destinos. Sin ello los botones no cobran ni activan suscripciones.

Para verificar extremo a extremo: contratar en sandbox desde una organización verificada, comprobar el webhook y sus permisos reales, avanzar 30 días con Test Clock, corroborar la factura de renovación, cancelar antes del fin y provocar un fallo de tarjeta. El acceso y las notificaciones de cada caso deben verificarse también en la aplicación antes de producción.

## Android

Se entrega el proyecto Android actualizado y sincronizado, no una APK/AAB compilada. El intento actual de Gradle falló con «Unable to establish loopback connection». El preflight pasó 7/9: faltan google-services.json real y la firma del proyecto. Mantener el keystore original; no crear otra identidad de firma para actualizar Play. Si 20178 ya está usado en Play, la actualización necesita un versionCode superior antes de compilar. No se comprobó el estado actual de revisión de Play en esta entrega.

## Reunir y reemplazar

Descargar las cuatro partes .001–.004 y UNIR_KOMBAX_20178_FIX07.cmd en la misma carpeta. Ejecutar el CMD: reúne el ZIP y comprueba SHA-256. Extraer el ZIP completo, nunca cada parte por separado. El paquete incluye proyecto web, dist, Supabase y Android.

Antes de reemplazar la carpeta de GitHub, conservar una copia y resolver/abortar cualquier merge pendiente según su estado. Copiar el contenido de KOMBAX_20178_R118_FIX07 a la raíz del checkout conservando .git y los secretos locales. No copiar una carpeta adicional anidada. Revisar git status/diff, instalar con npm ci y verificar con npm run release:build (la orden de Netlify; también disponible como node scripts/release-netlify-r104-3.mjs). Después realizar tu commit y push. No se incluyen .git, node_modules, claves privadas, Firebase real ni archivos de firma.

Las cuatro migraciones FIX07 usan los mismos identificadores que Supabase. Las migraciones históricas conservan sus nombres originales: no aplicar indiscriminadamente todos los SQL antiguos ni duplicar migraciones ya aplicadas. Esta base Supabase ya recibió FIX07.

Las reglas automáticas de moderación de FIX06 siguen siendo reglas de texto con limitaciones; esta entrega no añade una IA visual universal ni borrado físico automático de Storage. Los avisos internos existen; recepción de push/email en dispositivos reales sigue pendiente.
