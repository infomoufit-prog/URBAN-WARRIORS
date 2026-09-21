# Guía QA · Evento ejemplo 20.101

## Objetivo
Usar `Noche de Impacto · Barcelona · DEMO QA` como evento comercial y de QA exactamente igual que un evento real.

## Primera apertura recomendada
1. Abre 20.101 con tu cuenta Owner/Gestor.
2. Entra en `KOMBAX Events`.
3. El evento ya debe aparecer en la cartelera normal.
4. En la primera entrada Owner, si el álbum aún está vacío, KOMBAX intentará hidratar automáticamente las 10 imágenes demo al bucket privado.
5. Si la hidratación no termina por conexión, usa el panel QA Owner y pulsa `Instalar / actualizar demo`; es idempotente y puede repetirse.
6. Abre la tarjeta del evento: debe usar el mismo detalle normal que cualquier evento público.

## Recorrido comercial recomendado
### Portada/listado
- comprobar gran formato;
- cartel del evento;
- estado temporal;
- inscripciones abiertas;
- entradas a la venta;
- recinto y Barcelona;
- teaser del Main Event.

### Detalle
Revisar:
- Información;
- Main Event;
- Fight Card;
- Peleadores;
- Organización;
- Álbum/Highlights;
- entradas e inscripción externas;
- ubicación.

### Fight Card
- Hugo “Raven” Salvatierra vs Darío “Atlas” Moreno;
- Vera “Tempest” León vs Nerea “Venom” Rivas;
- 4 combates undercard.

### Álbum
Tras hidratar:
- cuadrícula real del álbum;
- filtros Previo / Evento / Posterior;
- apertura en lightbox;
- navegación anterior/siguiente;
- signed URL temporal;
- cuota visible dentro de 15 fotos / 5 vídeos.

## Deep-link
Tras desplegar la build en `kombax.es`, probar:
`https://kombax.es/?event=noche-de-impacto-barcelona-demo`

El mismo slug funciona con el lector público normal y no requiere una ruta demo.

## Qué mostrar a clubes/federaciones
Explicar que el ejemplo contiene el ciclo completo:
1. publicación del evento;
2. organizador + aval;
3. promoción previa / press day;
4. Fight Card y participantes;
5. entradas e inscripciones;
6. álbum vivo;
7. highlights y resultados;
8. histórico posterior.

## Limpieza
El evento está marcado `DEMO QA`. No borrar manualmente filas parciales. Para limpieza controlada usar `app_kombax_demo_event_cleanup_v177()` desde una sesión Owner y después retirar del bucket los paths devueltos si existen.
