# KOMBAX RC13 build 20.098 · Events Large Format Experience

## Plan previo obligatorio

Base inmutable: build 20.097 Events Workspace Isolation + local signing.

### Objetivo
Convertir KOMBAX Eventos en una experiencia editorial/promocional de gran formato, diferenciada de Showcase, manteniendo el dominio interno `Mi Club > Eventos` completamente separado.

### Alcance
1. Header KOMBAX coherente con Social/Showcase y banner propio de Eventos.
2. Feed de eventos en formato grande (una experiencia por fila en desktop; cartel cinematográfico en móvil).
3. Teaser del combate estelar en la portada sin duplicar la Fight Card.
4. Estados independientes: fase temporal, inscripciones y entradas.
5. Ventanas configurables de inscripción/venta por fechas.
6. CTA externos seguros para tickets, inscripción, streaming, web oficial y ubicación.
7. Detalle de evento en segundo nivel con hero, agenda/venue, CTA, Main Event, Fight Card, peleadores, organización, sponsors, álbum y resultados.
8. Mantener RPC-only, RLS y aislamiento de workspace de 20.097.
9. Migración aditiva; no renombrar ni eliminar columnas/funciones existentes.
10. QA específico + regresión completa + build determinista + Android/PWA + ZIP completo con JKS local.

### Riesgos controlados
- No mezclar tickets con procesamiento de pagos: KOMBAX solo enlaza venta externa.
- No inferir un estado único: entradas e inscripciones pueden coexistir.
- No leer tablas `eventos_competicion`, `evento_participantes`, `evento_combates`.
- No permitir que un workspace Club gestione otra identidad.
- URLs externas únicamente HTTPS.
- Mantener compatibilidad con estados legacy `inscripciones_abiertas/cerradas`.

### Criterios de cierre
- SQL aplicado/verificado en Supabase real.
- `anon` sin mutaciones.
- Urban Warriors/Federación QA siguen aislados.
- Test 20.098 PASS.
- Suite histórica completa PASS.
- `npm run build` PASS y `web = dist = Android`.
- ZIP completo, manifiesto SHA-256 y signing local preservado.
