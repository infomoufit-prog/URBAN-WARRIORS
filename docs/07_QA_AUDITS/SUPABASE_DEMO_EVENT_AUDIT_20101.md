# Supabase Audit · KOMBAX Events Demo Showcase · 20.101

## Proyecto
`poggsobhtutbuagjiydc`

## Migración productiva
`177_kombax_events_demo_showcase_20101.sql` / `kombax_events_demo_showcase_20101`.

## Evento real de QA
- event_id: `d9886aba-0cc4-4269-a7c5-7708f63f31f4`
- slug: `noche-de-impacto-barcelona-demo`
- nombre: `Noche de Impacto · Barcelona · DEMO QA`
- visibilidad: pública
- estado: inscripciones abiertas
- participantes aceptados: 12
- combates activos: 6
- Main Event destacados: 1

La lectura `app_kombax_evento_publico_slug_v173(slug)` devuelve el mismo objeto compuesto que utiliza el producto: `event`, `entities`, `participants`, `fights`, `main_event`, `media`, `engagement` y permisos derivados.

## Organizaciones ficticias
Se usan entidades externas soportadas por el dominio Events:
- `Club Fénix Elite · DEMO` — organizador principal.
- `Federación Nova Combat · DEMO` — avala.

No se crean clubes/federaciones productivos falsos en los dominios privados de gestión interna. El ownership técnico del seed está protegido por Owner.

## Seed / rollback
`app_kombax_demo_event_seed_v177()` es idempotente: localiza el slug y reconstruye participantes/Fight Card del ejemplo sin crear un dominio alternativo.

`app_kombax_demo_event_cleanup_v177()` elimina el evento normal y devuelve los `storage_paths` asociados para que un Owner pueda completar la limpieza del bucket si procede.

Ambas funciones:
- revocadas a `public`/`anon`;
- ejecutables por `authenticated`;
- validan internamente `kombax_platform_admins.nivel='owner'` y `activo=true`.

## Álbum / Storage
Al cierre de backend, `media=0` hasta que una sesión Owner de 20.101 hidrate los assets incluidos. Esto es deliberado: no se ha extraído ni persistido JWT/service-role del usuario para realizar una subida fuera de su sesión.

La hidratación usa:
- bucket privado `kombax-events-media`;
- `backend.upload(...)` por la capa autorizada;
- `app_kombax_eventos_mutate_v175` para registrar media;
- UUIDs de media fijos e idempotentes;
- reglas de cuota 20.099.

## Invariantes preservados
- no acceso directo público a Storage;
- no `service_role` expuesto al cliente;
- no RLS debilitada;
- no mezcla Urban Warriors/Federación;
- no mezcla KOMBAX Events con `Mi Club > Eventos`;
- no procesamiento de pagos/tickets por KOMBAX.
