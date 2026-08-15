# Base de datos · RC13 build 20018

## Principio

Evolución incremental y reversible. Toda escritura de negocio nueva pasa por `app_mutate_v160`; las lecturas sensibles usan RLS o RPCs de campos explícitos. `club_id` sigue delimitando los recursos tenant cuando corresponde.

## Cadena

| Migración | Dominio | Estado real conocido |
|---|---|---|
| 023–030 | hardening histórico / multiclub / media / finanzas | auditadas previamente |
| 031 | recibos + desglose financiero | aplicada y verificada |
| 032 | perfiles deportivos + likes | aplicada y verificada |
| 033 | eventos + participantes + combates | aplicada y verificada |
| 034 | notificaciones accionables | **pendiente Supabase real** |
| 035 | perfil público de club + identidad normalizada | **pendiente Supabase real** |
| 036 | edad/alta social/UGC/moderación | **pendiente Supabase real** |

## 034

Objetos principales:
- `notificaciones_revisiones`;
- `app_notificacion_requiere_accion_v034`;
- `app_notificaciones_accionables_v034`;
- operación `notificacion.revisar`.

Las operaciones históricas `notificacion.leer`, `leer_grupo` y `leer_todas` quedan endurecidas para excluir avisos que siguen requiriendo acción.

## 035

`perfiles_club_publicos` almacena solo información que el club decide exponer. No concede SELECT directo a `authenticated`; se consume por `app_perfil_club_publico_v035`. `web_publica`, redes, logo y portada tienen constraints HTTPS y el seed no arrastra URLs administrativas con otros esquemas.

`app_buscar_identidades_publicas_v035` devuelve una forma normalizada sin exponer las tablas privadas de origen.

## 036

Objetos:
- `identidades_sociales` (solo tipo `miembro` en esta fase);
- `bloqueos_comunidad`;
- `reportes_comunidad`;
- `moderacion_accesos_sociales`;
- `app_comunidad_general_estado_v036`;
- `app_comunidad_bloqueados_v036`;
- `app_comunidad_reportes_v036`;
- `app_puede_moderar_comunidad_v036`.

La activación social registra una aceptación en `aceptaciones_legales` contra `textos_legales` `comunidad_general` versión `1.0.0`. La edad mínima se lee de `config_club.edad_min_comunidad_general` con suelo 14. Una identidad suspendida/cerrada no se auto-reactiva desde el perfil.

## Regla futura

Urban Warriors no se trata como ID especial. Los triggers 035/036 dejan plantilla/estructura preparada para un futuro tenant sin desplegar aún selector ni UX multiclub. Los futuros competidor/federación/marca/tienda tendrán modelos propios y se normalizarán en la capa de identidad pública.
