# KOMBAX i18n · Checklist manual de dispositivo

Ejecutar antes de activar FR/PT/IT/DE/TH/FIL o declarar release comercial internacional completo.

## Matriz mínima

- Desktop: Chrome/Edge, 1440px y 1024px.
- Tablet: 768–900px.
- Móvil/PWA: 360–430px con safe areas.
- Android: APK/AAB firmado localmente, WebView real.
- Idiomas prioritarios de stress: FR, DE, TH. Muestras adicionales PT/IT/FIL.

## Visual

- Selector de idioma, navegación, tabs, cards, tablas y modales sin overflow crítico.
- Botones FR/DE envuelven texto sin cortar acciones.
- Thai: glifos completos, line-height, inputs, modales y wrapping correctos.
- Cabeceras y barras respetan safe areas.
- No reducir fuentes globalmente para “hacer caber”.

## Funcional

- Login, registro, recuperación y cambio de idioma sin logout.
- Club, federación, alumno, menor/tutor y multiclub.
- Social: feed, red, likes, comentarios, privacidad, media y chat.
- Showcase/Commerce: catálogo, carrito/compra, pedido, vendedor, Stripe.
- Events/Ticketing: evento, ticket, QR y acceso; comprobar que QR/token no cambian al cambiar idioma.
- Finanzas, Assist, Migrations, email y push.
- Confirmar que contenido creado por usuario permanece original.

## Criterio de activación

No activar idioma si existe: missing key visible, error crítico, overflow crítico, login/navegación rota, fallo Social/Showcase/Events/Ticketing, fallo Android/PWA o alteración de IDs técnicos.
