# KOMBAX 20.058 · INTERVENCIÓN 2 · HEADER ACTIVITY SPLIT

Estado: **CANDIDATA DE VALIDACIÓN MANUAL · NO FREEZE**

Base: KOMBAX 20.058 · Intervención 1, derivada de 20.057 SUPABASE CONSOLIDATION.

## Alcance implementado

- Cabecera con tres accesos independientes, fuera del menú lateral:
  - **Notificaciones KOMBAX**.
  - **Notificaciones del Club**.
  - **Mensajes**.
- Badges independientes para los tres centros.
- El centro del Club conserva la infraestructura operativa y push ya existente.
- KOMBAX y Mensajes no activan push en este bloque.
- Actividad KOMBAX de cabecera contabiliza únicamente actividad real accionable disponible hoy:
  - solicitudes pendientes de Mi red KOMBAX / relaciones privadas;
  - solicitudes de contacto pendientes de aceptación.
- Mensajes contabiliza únicamente mensajes no leídos de chats **aceptados**; no mezcla la solicitud inicial pendiente con un chat abierto.
- Un único RPC agregado alimenta KOMBAX + Mensajes para evitar múltiples consultas periódicas.
- Si falla el centro de avisos del Club, KOMBAX/Mensajes se refrescan de forma independiente.
- Un fallo transitorio de red no pone artificialmente los badges a cero; solo una sesión expirada limpia esos contadores.
- La navegación global y la resiliencia de sesión de la Intervención 1 se conservan.

## Supabase · migración live

Proyecto: `poggsobhtutbuagjiydc`

- Migración local: `supabase/migrations/103_kombax_header_activity_20058.sql`
- Registro live: **20260820014149 · kombax_header_activity_20058**
- RPC: `public.app_kombax_header_activity_v103()`
- Rollback: `supabase/rollbacks/103_kombax_header_activity_20058_rollback.sql`
- Verificación: `supabase/verification/verify_103_kombax_header_activity_20058.sql`

Controles live verificados:

- función presente: **true**;
- `authenticated EXECUTE`: **true**;
- `anon EXECUTE`: **false**;
- `SECURITY DEFINER`: **true**;
- `search_path` fijo `public, auth`: **true**.

Smoke live transaccional con identidad Dirección existente:

- `kombax_pending = 0`
- `relation_requests = 0`
- `contact_requests = 0`
- `message_unread = 1`

No se generaron datos QA persistentes.

## Advisors Supabase

### Security Advisor

La nueva función aparece como WARN de `authenticated_security_definer_function_executable`, esperado para este endpoint cliente intencional. Se verificó explícitamente que `anon` no puede ejecutarla, que usa identidad/autorización del usuario actual y que el `search_path` está fijado.

Permanecen los avisos ya clasificados en 20.057, incluido **Leaked Password Protection Disabled**, configuración manual de Auth todavía pendiente de cierre estricto.

### Performance Advisor

Tras la migración 103 no aparece una categoría nueva de problema. Permanecen INFO ya clasificados en 20.057:

- FKs de actor/auditoría sin índice deliberadamente no sobreindexadas;
- índices aún no usados por tráfico bajo o inexistente.

La migración 103 no crea tablas, FKs ni índices.

## Pruebas automáticas

- `npm test`: **PASS**.
- Test específico `test-kombax-20058-header-activity.mjs`: **PASS**.
- `npm run build`: **PASS**.
- El build vuelve a ejecutar la suite completa antes de sincronizar assets.

Regresiones específicas cubiertas:

- tres accesos independientes KOMBAX / Club / Mensajes;
- badges independientes;
- RPC agregado único;
- diferenciación solicitudes KOMBAX vs chats aceptados;
- deep-link a actividad Social correspondiente;
- refresco KOMBAX aunque falle Club;
- conservación de badges ante fallo transitorio;
- cierre explícito de RPC a `anon`;
- rollback disponible.

## Sincronización de superficies

Comparación SHA-256 independiente después del build:

- `web`: **65** archivos;
- `dist`: **65** archivos;
- Android `assets/www`: **65** archivos;
- faltantes: **0**;
- extras: **0**;
- diferencias de hash: **0**.

SHA-256 agregado del árbol web:

`975bbb037e1ad097a24f4708cb09111d5a3128b132ae9182afecfeffb1f1bc0b`

## Android preflight

Resultado: **4/5**.

OK:

- applicationId estable `com.urbanwarriors.app`;
- `versionCode 20058`;
- aplicación web embebida en `assets/www`;
- Firebase presente para push del Club.

Pendiente deliberado/local:

- `android/keystore.properties` / firma release local.

## Secret audit

- valores secretos detectados por patrones fuertes: **0**;
- JKS / keystore / P12 / PFX / claves privadas en paquete: **0**;
- `android/keystore.properties` real: **0**.

## Límite deliberado de esta intervención

Esta intervención **no declara terminada la 20.059**. En particular, todavía no se ha cambiado el chat actual a realtime ni se ha retirado su límite histórico de 20 mensajes; tampoco se han implementado todavía comentarios inline/respuestas ni la separación contextual completa Social/Showcase del sistema de conversación.

Esos cambios se abordarán en el siguiente bloque después de auditar contratos, Realtime, RLS y compatibilidad.

## Resultado

**20.058 · Intervención 2: PASS automático + Supabase live verificado.**

Permanece como candidata de validación manual; no se etiqueta como freeze final.
