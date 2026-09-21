# KOMBAX R79 build 20130 · Video fullscreen exit fix

Base obligatoria: `KOMBAX_20130_R79_I18N_COMPLETION_PILOT_FREEZE_CANDIDATE_FINAL.zip`.

## Alcance
Corrección aislada del comportamiento de vídeo en KOMBAX Social y álbumes. No se ha iniciado ni mezclado trabajo SEPA.

## Cambios
- KOMBAX Social reutiliza el visor inmersivo común en lugar del modal fullscreen independiente.
- El visor inmersivo muestra una acción explícita para cerrar/reducir la vista a pantalla completa.
- Al volver al vídeo pequeño se conserva el segundo de reproducción, volumen, mute y velocidad.
- Si el vídeo pequeño estaba reproduciéndose antes de ampliar, se reanuda al reducir; si estaba pausado, permanece pausado.
- El álbum público/privado del club incorpora botón de ampliación de vídeo y retorno al vídeo embebido.
- Se mantiene soporte `playsinline` y controles nativos para web/PWA/Android WebView.
- `dist/` y `android/app/src/main/assets/www/` se regeneraron desde `web/` mediante el build determinista existente.

## Archivos fuente modificados
- `web/js/ui/components.js`
- `web/js/modules/kombax-social.js`
- `web/js/modules/club-profile.js`
- `web/css/kombax-premium.css`

Los equivalentes de `dist/` y Android fueron regenerados automáticamente por `scripts/build.mjs`.

## Validación
- `npm test`: PASS completo.
- Auditoría i18n R79 estricta: 0 unresolved.
- R79 fases 6–10: 26/26 PASS.
- Build determinista: 455 archivos, `web = dist = Android`.
- Android preflight: 4/5 OK. Único pendiente: `android/keystore.properties` local para firma de release; no es una regresión del código ni se incluye por seguridad en el ZIP.

## Continuidad
Este ZIP conserva R79 build 20130 íntegro y añade únicamente la corrección de navegación/reducción de vídeo. Debe usarse como base acumulativa para la siguiente fase de cobros SEPA.
