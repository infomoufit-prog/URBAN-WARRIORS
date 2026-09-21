# KOMBAX - Referencia comercial R72 / build 20123

Fuente ejecutable: `kombax_commercial.plan_pricing_r64`, `kombax_commercial.runtime_config_r64` y `web/js/core/commercial-pricing.js` como fallback de interfaz.

## Planes Club
- Club Básico: 29 EUR/mes Founder; 36 EUR/mes estándar; 363 EUR/año estándar; Showcase 15 productos incluidos; Commerce opcional 12 EUR/30 días; platform fee 1,5 %; Events y Ticketing puntuales.
- Club Premium: 47 EUR/mes Founder; 59 EUR/mes estándar; 595 EUR/año estándar; Showcase 25 productos incluidos; Commerce incluido; 2 Events/mes; platform fee 1,5 %.
- Club Enterprise: 79 EUR/mes Founder; 99 EUR/mes estándar; 998 EUR/año estándar; Showcase, Commerce, Events y Ticketing ilimitados/incluidos según configuración; platform fee 0 %; BI Enterprise.

## Planes Marca
- Brand Start: 39/49 EUR al mes; 494 EUR/año estándar; 25 productos incluidos; Commerce incluido; fee 1,5 %.
- Brand Growth: 69/89 EUR al mes; 897 EUR/año estándar; 100 productos incluidos; Commerce incluido; 2 Events/mes; fee 1,5 %.
- Brand Enterprise: 129/161 EUR al mes; 1.623 EUR/año estándar; catálogo ilimitado; fee 0 %.

## Federación
- 19 EUR/mes Founder; 24 EUR/mes estándar. Sin Showcase/Commerce en R72.

## Ampliación Showcase R72
- +25 productos activos durante 30 días: 8 EUR.
- Renovable y acumulable.
- Independiente de Commerce y de la platform fee.
- Los límites de 15/25/100 son capacidad incluida, no un límite destructivo.
- Enterprise/Brand Enterprise mantienen catálogo ilimitado y no necesitan el add-on.
- Al expirar capacidad adicional no se borran referencias: el excedente puede pasar a `fuera_capacidad` hasta renovar, ampliar, subir de plan o archivar.
- Archivar libera un slot y conserva historial/reputación.
- Eliminar físicamente solo se admite cuando no existe historial relevante; si existen pedidos o reseñas se retira la referencia conservando trazabilidad.

## Showcase reputación
- Valoraciones 1-5 estrellas, texto y fotografías.
- `Compra verificada` solo con pedido entregado atribuible al usuario y producto.
- Vendedor puede responder y reportar, no borrar reseñas legítimas de terceros.

## Events comunidad
- Comentarios, respuestas, fotografías/vídeos cortos y valoraciones vinculadas al evento.
- `Asistió al evento` solo cuando existe ticket KOMBAX utilizado/check-in real.
- Organizador puede responder y reportar; moderación final corresponde a KOMBAX.

## Servicios puntuales sin cambios
- Publicación Events: 7d 5 EUR; 15d 8 EUR; 30d 12 EUR; 60d 18 EUR.
- Destacar: 7d 3 EUR; 15d 5 EUR; 30d 8 EUR.
- Ticketing por capacidad: <=50 10 EUR; <=100 15 EUR; <=200 25 EUR; <=500 45 EUR; <=1000 75 EUR; >1000 personalizado.
- Fee fijo al comprador por ticket: 0 EUR.

## Notas
- Founder es mensual y no se combina con anual.
- SaaS Billing automático de KOMBAX sigue fuera de R72. Las solicitudes de add-on del piloto no deben presentarse como cobro automático ejecutado.
- Compra comercial personal: 18+.
