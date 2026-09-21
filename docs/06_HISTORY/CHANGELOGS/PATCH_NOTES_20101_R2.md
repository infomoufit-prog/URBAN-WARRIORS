# PATCH NOTES · BUILD 20101 R2

Fecha: 2026-08-27

## Ajustes aplicados

1. **Tarjeta del evento**
   - Se elimina la visibilidad de la etiqueta / texto "Demo QA" y cualquier wording visible de "demo" en la experiencia principal del evento.
   - El evento sigue existiendo como ejemplo técnico, pero la presentación visual ya queda orientada a validación comercial y funcional.

2. **Main Event visible en cartelera**
   - Se corrige la lógica para resolver el combate estelar a partir del `main_event` o, si falta, a partir de la Fight Card real.
   - Ahora el bloque de **Combate Estelar** puede renderizarse tanto en la tarjeta/listado como en la vista pública y la vista de detalle.

3. **Organizadores visibles arriba en la cartelera**
   - Se añade visualización de **Organiza / Avala** en la zona principal del hero del evento.
   - También se añade un strip informativo de organización dentro de la tarjeta/listado.

4. **Imágenes de peleadores y hero en Social / Showcase / Events**
   - Se refuerza el componente compartido `brandHero` usando ruta de asset resuelta por módulo y un `<img>` explícito como capa visual.
   - Esto evita fallos de representación donde no se estaba viendo la imagen del peleador o el hero visual.

5. **Consistencia multiplataforma**
   - Cambios sincronizados en:
     - `web/`
     - `dist/`
     - `android/app/src/main/assets/www/`

## Ficheros tocados

- `web/js/modules/kombax-events.js`
- `web/css/kombax-events.css`
- `web/js/ui/brand-hero.js`
- `web/css/kombax-brand-heroes.css`
- Copias equivalentes en `dist/` y `android/.../www/`

## QA ejecutado

- `node --check web/js/modules/kombax-events.js`
- `node --check web/js/ui/brand-hero.js`
- `node scripts/test-kombax-20100-brand-heroes.mjs`
- `node scripts/test-kombax-20101-demo-event-showcase.mjs`

Resultado: **PASS**
