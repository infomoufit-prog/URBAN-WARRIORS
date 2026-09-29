# R104.6 · Moufit Showcase y alta de vendedor

Fecha: 2026-09-28.

Compilación: 20157. La versión web/PWA y Android aumenta el identificador de release para renovar el contenido de la aplicación.

## Estado comprobado en Supabase

- El club demo conserva el beneficio Enterprise temporal. El gestor probado puede administrar el catálogo y el plan ofrece capacidad ilimitada.
- Se alineó el nombre del espacio de Showcase con el nombre actual del club: `CLUB MOUFIT DEMO`.
- La ruta de imágenes de Showcase cumple las condiciones de la política de inserción para ese gestor. No se hizo una subida binaria desde Android; esa prueba sigue pendiente.
- La solicitud de vendedor falla con `KOMBAX_BASE_VERIFICATION_REQUIRED`, confirmado en el código de la RPC y en registros recientes de Postgres. No existe una solicitud de verificación del club ni una solicitud de vendedor para este proveedor. El indicador heredado `verificada` de la marca no constituye la verificación base exigida por el alta de vendedor.
- No se concedió verificación de identidad ni se habilitaron cobros. La cuenta Stripe sigue sin estar preparada para ventas.

## Corrección incluida

- Los errores conocidos del alta de vendedor muestran una explicación específica en vez del mensaje genérico.
- El Centro de vendedor no presenta el envío como disponible mientras falte la verificación base. Explica que el catálogo se puede preparar desde `Añadir producto` y que la venta directa requiere revisar la identidad real del club.
- Se conserva la corrección R104.5 del formulario de producto: el identificador se genera desde el nombre cuando queda vacío.
- Se corrigió el bloqueo al pulsar `Añadir producto`: el editor referenciaba `CTA_LABELS`, que no existía. Ahora construye las opciones desde el catálogo de acciones vigente y abre el formulario.
- La selección de fotografías de producto acepta los formatos móviles HEIC, HEIF y AVIF cuando el navegador puede decodificarlos; se convierten a WEBP o JPEG antes de Storage. El archivo final sigue sujeto al límite de 5 MB. El mensaje distingue un formato no admitido de una foto que el dispositivo no puede decodificar.

## QA

- Comprobación de permisos de catálogo e inserción de medios en contexto del gestor del club: PASS.
- Lectura de estado del Centro de vendedor: identidad pendiente y venta no activa, coherente con las reglas del backend.
- En los registros de Storage de las últimas 24 horas no aparece una solicitud directa reciente de carga de imágenes de Showcase de este proveedor; el bloqueo observado ocurre antes de que llegue un archivo a Storage. No se afirma que una subida binaria en el dispositivo del usuario haya pasado.
- Guardado transaccional de ficha de producto probado en R104.5 y revertido, sin dejar producto demo adicional.
- Prueba de apertura del editor con campos de imagen principal y galería: PASS.
- Alta real de vendedor y cobro: BLOCKED por ausencia de verificación base, datos comerciales auténticos y Stripe Connect listo.
