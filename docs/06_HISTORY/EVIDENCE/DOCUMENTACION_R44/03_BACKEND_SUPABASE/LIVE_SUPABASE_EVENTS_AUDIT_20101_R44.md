# LIVE SUPABASE EVENTS AUDIT · R44

Proyecto auditado: `poggsobhtutbuagjiydc`
Modo: solo lectura. R44 no aplicó DDL ni mutaciones de eventos en producción.

## Inventario vivo
- 3 eventos totales.
- 3 demos (`slug` terminado en `-demo`).
- 0 eventos no-demo.
- 2 eventos propiedad del Club Urban Warriors (`11111111-1111-4111-8111-111111111111`).

## Integridad
### Noche de Impacto · Barcelona
- organizador principal: 1
- Main Event: 1
- combates rotos: 0
- media rota: 0
- participantes aceptados: 12

### Urban Warriors · Interclub de Jiu-Jitsu · Palafolls
- organizador principal: 1
- Main Event: 1
- combates rotos: 0
- media rota: 0
- participantes aceptados: 10
- combates totales: 5

### Seminario Pro de Muay Thai · Adrián Serrano
- organizador principal: 1
- Main Event: 0 (coherente con seminario)
- combates rotos: 0
- media rota: 0
- participantes aceptados: 1

## RPC / ejecución
Comprobación viva de privilegios:
- `app_kombax_eventos_mutate_v191(text,jsonb,uuid)`: authenticated=true; anon=false.
- `app_kombax_evento_contexto_gestion_v171(uuid,uuid)`: authenticated=true; anon=false.
- `app_kombax_event_visibility_v236(uuid)`: authenticated=true; anon=false.
- `app_kombax_event_visibility_mutate_v236(uuid,jsonb)`: authenticated=true; anon=false.
- `app_kombax_eventos_visible_page_v236(...)`: authenticated=true; anon=false.
- `app_kombax_evento_bundle_v189(uuid,uuid)`: authenticated=true; anon=true.

El bundle conserva permiso de lectura anónima conforme al modelo público de Events; las mutaciones y gestión permanecen restringidas a usuario autenticado.

## Limitación de la comparación solicitada
No hay en la base viva un evento normal/no-demo creado desde portal. Por ello no se puede documentar un A/B empírico entre “seed directo” y “evento creado por Urban Warriors” sin crear un registro real de prueba, acción que no se realizó para evitar contaminar producción. La revisión de código sí confirma que ambos flujos comparten los componentes donde se encontraron los defectos generales.
