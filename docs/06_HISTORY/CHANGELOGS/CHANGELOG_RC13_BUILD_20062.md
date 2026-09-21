# KOMBAX RC13 · Build 20062

## COMPETITOR REOPEN + FOUNDERS PROMO

### Competidor

- Rehabilitada la identidad **Competidor** en el selector público de perfiles oficiales.
- Recuperado el flujo de alta tras autenticación.
- Se conserva la posibilidad de Competidor independiente o con continuidad desde Miembro.
- Se conserva revisión/verificación KOMBAX, documentación, ownership, unicidad por cuenta y controles de edad existentes.
- Profesional/Representante y Espectador continúan cerrados.

### Promoción de lanzamiento

- Añadido anuncio de **primeros 20 competidores fundadores** en Combat Social / feed de KOMBAX Social.
- Añadido anuncio de **primeros 20 clubes fundadores** en KOMBAX Showcase.
- Ambos anuncios evitan precio, importe, porcentaje y descuento concreto.
- La elegibilidad se comunica por orden de verificación KOMBAX.
- La trazabilidad técnica se apoya en `kombax_verificacion_eventos` y `kombax_solicitudes_alta`; no se añade esquema promocional.

### Build

- Build web/PWA/Android: **20062**.
- Nueva regresión: `scripts/test-kombax-20062-competitor-reopen-promo.mjs`.
- Pruebas históricas ajustadas únicamente para aceptar que la decisión MVP 20.055 de cerrar Competidor ha sido explícitamente supersedida.
