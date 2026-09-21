# KOMBAX RC13 · Build 20.094

## Live + Results + Highlights + History

Build 20.094 consolida KOMBAX Eventos como superficie pública transversal sin reutilizar ni copiar `Mi Club > Eventos`.

### Implementado
- Estados temporales públicos: AHORA / PRÓXIMOS / RESULTADOS / FINALIZADO.
- Lifecycle de resultados: pendiente, provisional, oficial y anulado.
- Ruta exclusiva `event.fight.result.set`; `event.fight.save` ya no puede escribir resultados.
- Álbum/highlights en bucket privado `kombax-events-media`.
- URLs firmadas de 15 minutos mediante `event-media-url`.
- Historial oficial público en perfiles Competidor, limitado a KOMBAX Eventos finalizados.
- Deep-link anónimo real antes de iniciar sesión.
- Hardening ACL: asset resolver interno exclusivo de `service_role`.
- Índices FK específicos de resultados/media.
- Health productivo actualizado a build 20094.

### Compatibilidad
- Finanzas, Social, Showcase, Mi Club y flujos previos mantienen sus contratos.
- Espectador permanece deshabilitado hasta gate específico de edad/privacidad.
