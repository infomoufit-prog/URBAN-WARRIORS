# Supabase audit · KOMBAX Events 20.101 R3

Fecha: 2026-08-27
Proyecto: `poggsobhtutbuagjiydc`

## Migración productiva
Aplicada:
- `20260827123220 · kombax_events_visual_editor_hardening_20101`
- archivo local: `supabase/migrations/178_kombax_events_visual_editor_hardening_20101.sql`

## Esquema añadido
En `kombax_eventos_publicos`:
- `cartel_focus_x` 0..100;
- `cartel_focus_y` 0..100;
- `banner_focus_x` 0..100;
- `banner_focus_y` 0..100.

No se añadió un dominio paralelo de demo ni se modificó Mi Club > Eventos.

## Contratos v178
- discovery público v178;
- detalle por UUID v178;
- detalle por slug v178;
- mutation gateway v178;
- seed Owner v178.

Mutation v178 delega primero en v175 y conserva las protecciones anteriores. Solo añade persistencia de focales y el invariante de un único Main Event destacado.

## ACL verificada
| RPC | anon | authenticated |
|---|---:|---:|
| `app_kombax_eventos_publicos_v178` | EXECUTE | EXECUTE |
| `app_kombax_evento_publico_slug_v178` | EXECUTE | EXECUTE |
| `app_kombax_eventos_mutate_v178` | NO | EXECUTE |
| `app_kombax_demo_event_seed_v178` | NO | EXECUTE |

## Evento de validación
- UUID: `d9886aba-0cc4-4269-a7c5-7708f63f31f4`
- nombre público: `Noche de Impacto · Barcelona`
- slug técnico: `noche-de-impacto-barcelona-demo`
- organizador: `Club Fénix Elite`
- aval: `Federación Nova Combat`
- Main Event: Hugo “Raven” Salvatierra vs Darío “Atlas” Moreno
- total Fight Cards: 6
- Fight Cards destacadas: exactamente 1
- `cartel_focus_x/y`: 50 / 45
- `banner_focus_x/y`: 50 / 42

El lector por slug v178 devuelve el nombre limpio, focales, Main Event, 6 fights y 2 entidades.

## Advisors
Security Advisor y Performance Advisor ejecutados. Persisten avisos históricos del proyecto. Ninguno se atribuye a una FK/index nuevo de migración 178, ya que esta migración no añade FKs ni índices. Se mantiene como backlog separado:
- políticas RLS/InitPlan históricas;
- varias FKs sin índice en tablas heredadas;
- índices no usados;
- índice duplicado previo en `informes_financieros`.

No se modificaron tablas financieras, de membresía ni otros dominios para resolver avisos ajenos a Events.
