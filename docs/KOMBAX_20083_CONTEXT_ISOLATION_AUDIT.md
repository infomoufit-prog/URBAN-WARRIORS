# KOMBAX RC13 build 20083 · Auditoría de aislamiento de contexto

## Incidencia reportada

Una misma cuenta con capacidad Owner/gestión puede administrar varias identidades KOMBAX (por ejemplo un club y una federación). Al entrar en el workspace privado de un club, la bandeja de mensajes y otros elementos privados podían incorporar actividad perteneciente a otra identidad gestionada por la misma cuenta.

## Causa raíz confirmada en producción (solo lectura)

1. `app_kombax_social_mis_perfiles_v051(p_club_id)` filtraba por `p_club_id` únicamente cuando `sujeto_tipo='club'`. Los `perfil_directo` (Federación/Marca/Competidor) seguían disponibles en el selector dentro de un club.
2. `app_kombax_contactos_v133()` deriva de `app_kombax_contactos_v107()`, que reúne contactos para **todos** los IDs retornados por `app_kombax_my_social_actor_ids_v106()`.
3. `app_kombax_contact_mensajes_v106()` y `app_kombax_contact_mark_read_v106()` autorizaban un hilo si cualquiera de las identidades gestionables por la cuenta era parte del contacto; no estaban ligados a la identidad activa del workspace.
4. `app_kombax_header_activity_v107()` agregaba solicitudes/mensajes no leídos de todas las identidades gestionables y `app_kombax_header_summary_v107(p_club_id)` combinaba esas métricas globales con las notificaciones del club.
5. La pantalla reutilizaba estado UI (`kombax_social_view`, `kombax_social_open_contact`) sin un namespace explícito de workspace. Esto podía mantener una intención de UI antigua tras cambiar de contexto, aunque el principal problema era el dataset global del RPC.
6. `selectedSocioId` se persistía en la clave local global `uw2_selected_socio`; aunque el switch de club intentaba limpiarla, 20.083 la convierte en `usuario + club` y elimina la clave legacy para evitar estados residuales al cerrar sesión/reabrir con otro contexto.
7. El registro push de servidor ya está separado por `club_id + perfil_id + token`; 20.083 añade también una marca local por club para que Android no omita la sincronización del nuevo contexto por haber sincronizado el mismo token en otro club.

## Alcance de seguridad observado

- Las tablas `kombax_social_perfiles`, `kombax_social_contactos` y `kombax_social_contacto_mensajes` tienen RLS activo.
- `anon` y `authenticated` no tienen SELECT/INSERT/UPDATE directos sobre esas tablas.
- Los RPC inspeccionados no son ejecutables por `anon` y sí por `authenticated`.
- `app_kombax_my_social_actor_ids_v106()` limita el conjunto a identidades que el usuario autenticado puede gestionar.
- Las tablas privadas auditadas de alumnos, matrículas, cuotas, pagos, recibos, grupos, disciplinas, documentos, sesiones, asistencias, notificaciones, configuración y equipo tienen RLS activo y políticas con ámbito de club.
- Las vistas financieras `v_estado_cuenta_socio`, `v_finanzas_detalle`, `v_finanzas_metricas_anuales` y `v_finanzas_metricas_mensuales` están creadas con `security_invoker=true`.
- En la estructura Owner activa se confirmó, sin leer contenidos privados, un caso de 2 actores gestionables: 1 actor del workspace de club y 1 perfil directo. La consulta histórica global alcanzaba 6 hilos privados y el scope de club 5: 20.083 excluye el hilo ajeno al workspace.

Conclusión: el hallazgo confirmado es un **cruce de contexto entre identidades autorizadas de la misma cuenta**, no una evidencia de lectura de cuentas ajenas no autorizadas. La corrección 20083 añade también controles contra IDOR contextual para que un `contacto_id` de otra identidad no pueda reutilizarse desde el workspace actual.

## Corrección 20083

La migración `147_kombax_workspace_context_isolation_20083.sql` añade:

- `private.kombax_workspace_club_access_v147`
- `private.kombax_workspace_actor_allowed_v147`
- `app_kombax_workspace_actor_ids_v147`
- `app_kombax_workspace_social_profiles_v147`
- `app_kombax_contactos_contexto_v147`
- `app_kombax_contact_mensajes_contexto_v147`
- `app_kombax_contact_mark_read_contexto_v147`
- `app_kombax_header_activity_contexto_v147`
- `app_kombax_header_summary_v147`
- `app_kombax_relaciones_contexto_v147`
- mutaciones contextuales para chat y Mi red
- `app_kombax_context_isolation_audit_v147`

### Regla de workspace de club

Dentro de un club solo pueden ser actores privados:

1. El perfil Social del **club actual**, si el usuario puede actuar como ese club.
2. El perfil **Miembro** del propio usuario cuyo `club_origen_id` sea exactamente el club actual.

No entran en el workspace privado del club:

- Federación
- Marca
- Competidor / otro perfil directo
- Club distinto
- Miembro de otro club

Los perfiles directos continúan disponibles en el workspace global de KOMBAX; no se eliminan ni se modifican.

## Chats

Cada operación de chat en workspace de club liga simultáneamente:

`auth.uid + club_id + active_social_id + contacto_id`

El `active_social_id` debe pertenecer al club actual y ser una de las dos partes del contacto. Si no:

- lectura: `KOMBAX_CONTACT_CONTEXT_FORBIDDEN`
- decisión de solicitud: `KOMBAX_CONTACT_DECISION_CONTEXT_FORBIDDEN`
- identidad: `KOMBAX_WORKSPACE_ACTOR_FORBIDDEN`

No se borran ni migran mensajes históricos.

## Cabecera y badges

`app_kombax_header_summary_v147` recibe también la **identidad activa** y deja de sumar mensajes de otra identidad aunque pertenezca al mismo login. Federación/Marca/otro club quedan fuera de Warriors. Para una sesión Owner/support sin membresía real, la parte de notificaciones del club falla cerrada (0) en vez de sustituirse por actividad global; la actividad Social sigue limitada a actores válidos del workspace.

## Mi red

Las lecturas y cambios de estado de relaciones se validan contra un actor permitido del club. Una relación de una Federación gestionada por el mismo login ya no es accionable desde Warriors.

## Frontend

`web/js/core/context-isolation-20083.js` se carga **antes de `app.js`** y reemplaza únicamente los repositorios privados cuando existe `club_id`:

- identidades propias
- contactos
- mensajes
- leído
- aceptar/rechazar
- enviar/cerrar/eliminar
- Mi red
- header summary ligado a identidad activa

En contexto global KOMBAX conserva los RPC globales históricos.

## Smoke test posterior a instalar 147

1. Entrar en Warriors como Dirección/Gestor.
2. Abrir KOMBAX Social → identidad: solo Warriors/Miembro de Warriors si procede.
3. Abrir Mensajes: no aparece ningún hilo cuyo actor propio sea Federación, Marca, Competidor u otro club.
4. Cambiar a identidad Miembro del mismo club: el inbox cambia al actor seleccionado.
5. Copiar un `contacto_id` perteneciente a otro actor y solicitarlo con RPC contextual: debe devolver `KOMBAX_CONTACT_CONTEXT_FORBIDDEN`.
6. Revisar badge superior: debe coincidir solo con los actores válidos del workspace.
7. Cambiar de club y repetir: no debe conservarse el hilo anterior ni el alumno seleccionado del otro club.
8. En Android, confirmar que el token push se registra para el club actual sin reutilizar una marca local de otro club.
9. Abrir KOMBAX global: los perfiles directos propios vuelven a estar disponibles de forma intencionada.

## No incluido

No se cambia el carácter global del feed público, directorio público ni Showcase. Ver publicaciones públicas de una Federación dentro de KOMBAX Social no es una mezcla de datos privados; actuar como esa Federación o ver su inbox dentro del workspace Warriors sí lo era y queda bloqueado.
