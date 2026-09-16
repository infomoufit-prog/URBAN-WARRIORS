# KOMBAX 20.101 R18 · Urban Warriors Realism Pass

## Objetivo
Hacer que el evento ficticio Urban Warriors tenga una Fight Card coherente y realista usando el banco de 10 retratos ficticios generado para QA.

## Implementado
- 10 participantes activos con 10 retratos distintos.
- 5 combates totales: 4 Fight Card + 1 Main Event.
- Eliminados del demo actual Nico Serra e Ian Cruz para hacer coincidir cartelera y banco de imágenes.
- Exactamente un combate marcado como Main Event: Malik Benítez vs Bruno Sato.
- Las 10 fotografías se reutilizan en el álbum visible del evento.
- El gestor de álbum muestra esas mismas 10 fotos y las cuenta dentro del límite visual del demo.
- Los 10 WEBP están empaquetados en web, dist y Android assets/www.
- Seed backend v180 endurecido e idempotente para reconstruir 10/5/1.

## Backend
Migración aplicada en Supabase principal:
`184_kombax_events_urban_realism_20101_r18.sql`

El seed requiere autenticación; anon no tiene EXECUTE.

## Nota sobre el álbum demo
Las 10 fotos del álbum Urban Warriors son una capa demo local empaquetada en la build, no 10 filas nuevas de Storage. El flujo de álbum de eventos reales sigue usando el sistema oficial backend/Storage existente.
