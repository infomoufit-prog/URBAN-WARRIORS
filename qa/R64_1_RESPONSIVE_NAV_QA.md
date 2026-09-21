# KOMBAX R64.1 · Navegación y distribución responsive

Fuente: R64 comercial. Cambios locales; sin despliegue, push ni cargos.

## Resultado

| Formato | Tamaño usado | Botón fijo | Menú desplegable | Contenido a ancho disponible |
| --- | ---: | :---: | :---: | :---: |
| PC | 1440 × 900 | PASS | PASS | PASS |
| Tablet horizontal | 1180 × 820 | PASS | PASS | PASS |
| Tablet vertical | 820 × 1180 | PASS | PASS | PASS |
| Móvil horizontal | 844 × 390 | PASS | PASS | PASS |
| Móvil vertical | 390 × 844 | PASS | PASS | PASS |

Probador visual local: `/qa/responsive-matrix.html`. Es una maqueta aislada que usa las hojas de estilo reales y fija las dimensiones de cada marco; no equivale a una prueba en hardware físico. La vista real autenticada de Events y Assist se verificó además en el navegador local de escritorio: menú cerrado, apertura, fondo oscurecido, cierre y botón fijo a 11 px del borde superior tras más de 1.200 px de scroll.

La barra inferior se conserva para la navegación móvil hasta 820 px de ancho; el menú global se muestra a cualquier ancho, incluido móvil apaisado de 844 px.

## Regresiones

- `test-kombax-20112-r64-1-global-responsive-navigation.mjs`: PASS.
- `test-kombax-20112-r64-1-legal-assist-specialists.mjs`: PASS (contrato de código, no prueba de backend desplegado).
- `test-kombax-20110-r60-global-back-close-navigation.mjs`: 16 PASS.
- `test-kombax-20110-r62-5-showcase-events-ticketing.mjs`: PASS.
- `test-kombax-20110-r62-4-stripe-connect-hardening.mjs`: FAIL legado: prohibía `application_fee_amount`, introducido posteriormente por el esquema comercial R64. No se ha alterado la arquitectura de cobros para satisfacer una aserción obsoleta. Requiere actualizar la prueba al contrato comercial vigente antes de certificar toda la suite.

## Pendiente de certificación

La aceptación legal usa ahora las versiones exigidas por el servidor, en vez de enviar siempre versiones antiguas, pero no se ha repetido una aceptación real de una cuenta pendiente tras el cambio. Las ocho especialidades de Assist aparecen en el frontend; la función Edge modificada todavía no está desplegada. No se certifica Stripe TEST ni piloto por este ajuste visual.
