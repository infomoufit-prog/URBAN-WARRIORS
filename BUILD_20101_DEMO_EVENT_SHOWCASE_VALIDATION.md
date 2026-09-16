# KOMBAX RC13 build 20.101 · Demo Event Showcase · Validación

## Objetivo
Cerrar un evento público ficticio de referencia que recorra exactamente el mismo dominio funcional que un KOMBAX Evento creado por un organizador real. El ejemplo debe servir para QA, demostración comercial y piloto con clubes/federaciones sin introducir una ruta, tabla o lector paralelo de demo.

## Evento instalado en Supabase real
- Nombre: `Noche de Impacto · Barcelona · DEMO QA`.
- Slug público: `noche-de-impacto-barcelona-demo`.
- UUID real: `d9886aba-0cc4-4269-a7c5-7708f63f31f4`.
- Visibilidad: `publico`.
- Estado actual: `inscripciones_abiertas`.
- Fecha: 18/10/2026.
- Recinto: `Palau Combat Barcelona`.
- Organiza visualmente: `Club Fénix Elite · DEMO`.
- Avala visualmente: `Federación Nova Combat · DEMO`.

El evento está almacenado en `kombax_eventos_publicos` y se lee por `app_kombax_evento_publico_slug_v173`, igual que cualquier evento público normal.

## Contenido deportivo real del modelo
- 12 participantes públicos aceptados.
- 6 combates programados.
- Main Event destacado: Hugo “Raven” Salvatierra vs Darío “Atlas” Moreno · Kickboxing Pro -75 kg.
- Co-main femenino: Vera “Tempest” León vs Nerea “Venom” Rivas · MMA Pro -57 kg.
- 4 combates de undercard.
- participantes y combates se guardan en las tablas normales de KOMBAX Events.

## Multimedia de demostración
La build incluye un banco local coherente con el evento en:
`web/assets/demo-events/noche-impacto-barcelona/`

Incluye portada, banner, Main Event, co-main, undercard, recinto/entradas, press day, Fight Card completa, promo del álbum, resultados, highlights, logos ficticios y 12 retratos de competidores.

### Estado de Storage al cierre
El evento ya existe en Supabase y es navegable públicamente. El álbum server-side permanece inicialmente en `0` porque la subida al bucket privado requiere una sesión autenticada autorizada de organizador/Owner; esas credenciales no se extraen ni se almacenan en el paquete.

20.101 resuelve esto sin ruta especial: en la primera entrada de un Owner a KOMBAX Events, si el evento existe y tiene menos de 10 media, `maybeAutoInstallDemoAlbum()` hidrata automáticamente 10 piezas desde los assets incluidos hacia `kombax-events-media` y las registra mediante `app_kombax_eventos_mutate_v175`. El botón Owner “Instalar / actualizar demo” queda como respaldo.

Una vez hidratado, el álbum usa exactamente:
- bucket privado `kombax-events-media`;
- cuota real 20.099 (15 fotos / 5 vídeos);
- URLs firmadas temporales;
- lector público normal;
- filtros y lightbox normales del evento.

## Backend / seguridad
Migración aplicada en producción:
- `177 · kombax_events_demo_showcase_20101`.

RPC:
- `app_kombax_demo_event_seed_v177()` — authenticated + comprobación Owner.
- `app_kombax_demo_event_cleanup_v177()` — authenticated + comprobación Owner.

ACL verificada:
- anon seed: `false`;
- authenticated seed: `true`;
- anon cleanup: `false`;
- authenticated cleanup: `true`.

No se crean tablas `demo`, no se relaja RLS, no se habilita escritura anónima y no se modifica el aislamiento de workspace 20.097.

## Arquitectura frontend
- El instalador solo crea/hidrata contenido.
- Después se ejecuta `openEvent(eventId)` normal.
- No existe `#demo-event` ni un renderer paralelo.
- La lectura de assets demo pasa por repositorio/backend; el módulo UI no introduce `fetch()` directo.
- Los enlaces públicos usan el slug normal y son compatibles con el deep-link de Events.

## QA
- `test:20101`: PASS.
- Contratos 20.099 / 20.100 / 20.101: PASS.
- `npm test`: PASS completo hasta 20.101.
- `npm run build`: PASS.
- salida final: `OK build 132 archivos · web = dist = Android`.
- legal gate: PASS.
- Android preflight: 4/5; único pendiente `android/keystore.properties` local con credenciales.
- Android versionCode: 20101.

## Producción / despliegue
- Supabase: migración 177 aplicada y evento base instalado.
- Netlify: NO desplegado por esta intervención.
- Google Play: NO publicado por esta intervención.
- `health` productivo no se ha adelantado a 20101.
- Los assets HTTPS `kombax.es/assets/demo-events/...` quedarán disponibles tras desplegar la frontend 20.101; en local la build utiliza los assets empaquetados para la hidratación del álbum.

## Criterio de cierre
20.101 queda cerrada cuando:
1. regresión y build permanecen verdes;
2. evento real responde por slug normal;
3. 12 participantes y 6 fights existen en Supabase;
4. seed/cleanup son Owner-only;
5. álbum puede auto-hidratarse al Storage privado con sesión Owner;
6. web/dist/Android son idénticos;
7. ZIP final contiene JKS solicitado pero no credenciales.
