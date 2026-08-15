# Arquitectura · Urban Warriors 2.0.0-rc.13 · build 20020

## Principio

Urban Warriors sigue siendo el entorno único del MVP. Esta RC **no** crea todavía la experiencia multiclub general, pero toda nueva estructura evita depender de Urban Warriors como excepción. Las reglas de evolución permanente están en `PLATFORM_EVOLUTION_RULES.md`.

## Capas

1. `web/js/core/supabase.js`: Auth, PostgREST, RPC y Storage.
2. `web/js/core/backend.js`: sesión, contrato, gateway, diagnóstico, subida/descarga y push.
3. `web/js/core/repositories.js`: API de dominio consumida por UI.
4. `web/js/core/state.js`: estado UI mínimo.
5. `web/js/modules/*` + `web/js/ui/*`: experiencia por rol.
6. Supabase: RLS + RPC de lectura segura + `app_mutate_v160` como única puerta de negocio.

Flujo de escritura:

`UI → repository → backend.mutate() → contrato runtime → app_mutate_v160 → validación backend → respuesta versionada → render`

## Contrato

- Backend: `1.6.0`
- Schema epoch: `160`
- Gateway: `app_mutate_v160`
- Cada migración 032–036 envuelve y conserva la función anterior.
- El cliente build 20020 exige 19 capacidades acumuladas nuevas sobre el contrato previo; un backend incompleto se rechaza explícitamente.

## Dominios RC13

### 031 Finanzas

Cuota/material/otro, recibos y estado de cuenta derivados de las fuentes contables existentes. No se crea contabilidad paralela.

### 032 Perfil deportivo + likes

`perfiles_deportivos` está separado del expediente administrativo. Visibilidad y moderación son estados distintos. El cliente no puede enumerar quién dio like.

### 033 Eventos/Competiciones

Eventos, requisitos, participantes internos/externos e interacciones de combate manual. Participantes y combates sensibles se leen por RPC segura.

### 034 Notificaciones accionables

`app_notificacion_requiere_accion_v034` decide con estado vivo del objeto si un aviso sigue exigiendo acción. Lectura masiva/grupo solo afecta informativas. `notificacion.revisar` registra apertura/revisión en `notificaciones_revisiones`.

### 035 Perfil público de club

`perfiles_club_publicos` es una proyección pública independiente de `clubes`. No reutiliza CIF, email, teléfono o dirección administrativa. Dirección/Coordinación pueden editar por gateway. Los campos URL públicos aceptan únicamente HTTPS y el render vuelve a sanitizarlos defensivamente.

La función `app_buscar_identidades_publicas_v035` normaliza por ahora `club` + `miembro` para que UI/búsqueda no dependan del modelo de tablas de cada tipo. Competidor, federación, marca y tienda llegarán como modelos propios y podrán añadirse a esta capa.

### 036 Base social opcional + seguridad UGC

La identidad social de un miembro (`identidades_sociales`) es distinta de su expediente del club. Solo existe el tipo actual `miembro`; no se meten futuros tipos en una tabla genérica.

- autorregistro autónomo alumno: 16+;
- elegibilidad social: rol alumno + socio activo + DOB verificada + umbral configurable en `config_club` (suelo 14);
- activación voluntaria con aceptación legal versionada;
- familia/tutor no activa identidad social;
- denuncia y bloqueo por gateway;
- reportes por RPC segura;
- suspensión/reactivación social auditada en `moderacion_accesos_sociales`;
- una suspensión social no bloquea la gestión administrativa del club.

No existe todavía feed de Social Community / Comunidad General.

## Comunidad del Club vs futura Social Community / Comunidad General

Son ámbitos diferentes. Las publicaciones actuales siguen siendo del club y no se vuelven globales por defecto. Dentro de Comunidad del Club, el **nombre del club** abre la ficha pública de Urban Warriors.

## Storage

Se conservan los buckets históricos privados/públicos según dominio. Las nuevas estructuras 034–036 no exponen secretos ni añaden DML directo desde frontend.

## Android

- package/namespace: `com.urbanwarriors.app`
- build: `20020`
- versionName: `2.0.0-rc.13`
- compile/target SDK: `36`
- web embebida servida desde origen HTTPS virtual.

La compilación nativa release/AAB requiere toolchain Android externo a este entorno.

## Organización semanal de sesiones

La persistencia de recurrencias no cambia. La UI filtra por semana natural (lunes–domingo), permite navegar a semana anterior/siguiente y, en la semana actual, ordena primero la próxima sesión y luego las siguientes; las sesiones ya pasadas permanecen detrás como contexto. El mismo criterio se aplica al portal de alumno/familia.

## Identidad visual de club

Los logos de club se presentan dentro de marcos circulares sin obligar a que el archivo fuente ya tenga esa forma. La PWA usa iconos maskable y Android usa adaptive icons para evitar dobles marcos o un cuadrado visible dentro del círculo del launcher.
