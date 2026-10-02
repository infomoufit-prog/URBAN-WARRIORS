# KOMBAX R117 · build 20171 · Pilot Hotfix 1

## Identidad de release

- Release: `2.0.0-rc.13-r117-pilot-hotfix-1`
- Android `versionCode`: `20171`
- Package: `com.urbanwarriors.app`
- Base acumulativa: R117 build 20170 Golden Pilot.
- Ámbito: estabilización del piloto, sin reconstrucción desde versiones anteriores.

## Cambios funcionales cerrados

### 1. Alta Club Piloto sin código

La entrada al programa Club Piloto es autoservicio durante la ventana configurada y mientras queden plazas. No existe requisito de `pilot_code`. La generación de códigos del programa piloto queda deshabilitada. Esto no elimina los códigos de acceso/invitaciones de alumnos, familias o equipo, que permanecen como vías opcionales de vinculación.

### 2. Elite Social independiente de la membresía privada

Se separan tres capacidades:

1. Perfil público/red.
2. Álbum y medios del perfil.
3. Publicación en el feed Social.

Un Miembro/Practicante puede crear y conservar su perfil público aunque todavía no tenga club. Puede usar avatar, banner, bio, información deportiva y álbum. El contenido del álbum no crea una publicación del feed. La publicación como Miembro exige una membresía real y activa confirmada por el club y conserva las reglas de edad/consentimiento.

El Espectador dispone de perfil público básico, avatar, banner e información pública, pero no dispone de álbum ni puede publicar en el feed Social.

Los perfiles directos de KOMBAX disponen de una presencia pública básica; la verificación continúa siendo una capacidad adicional y no se confunde con el derecho a existir en la red. El permiso de publicación sigue sujeto a las reglas específicas de cada identidad.

### 3. Red, mensajes y compra

La propiedad/gestión de un perfil público se separa del permiso de publicar. Un perfil básico puede formar parte de Mi Red y realizar interacciones habilitadas. El chat directo conserva la barrera de edad 18+ donde corresponde.

No se ha añadido una barrera de membresía a Showcase ni Events. Comprar, consultar productos o utilizar superficies públicas continúa sujeto a las reglas de edad, checkout, vendedor y pago, no a pertenecer a un club.

### 4. Vinculación fácil con clubes

Se conservan varias vías, sin imponer una sola:

- invitación o código personal del club;
- solicitud de vinculación desde la cuenta al encontrar el club;
- autorización directa de Dirección/Secretaría/Coordinación;
- autorización familiar/tutor vinculando la cuenta a un alumno concreto.

Rechazar una solicitud de club no elimina ni bloquea el perfil público KOMBAX. Al aprobar una membresía se enlaza la misma identidad social, evitando crear otro perfil.

La vinculación al club es la que habilita la capa privada: ficha de alumno, cuotas/cobros, asistencia, documentos, comunicaciones internas y gestión según rol.

### 5. Continuidad Android

`MainActivity` incorpora persistencia/restauración de estado de WebView y última URL interna segura. El frontend deja de forzar Inicio tras recuperar una sesión. El objetivo es conservar pantalla/ruta ante llamadas, multitarea, bloqueo de pantalla y recreación de Activity.

El cambio requiere un AAB nuevo porque afecta código Android y assets web empaquetados.

## Backend aplicado en el piloto

Las migraciones equivalentes quedan consolidadas en:

- `302_kombax_pilot_social_read_and_member_interest_r117.sql`
- `303_kombax_pilot_open_registration_no_code_r117.sql`
- `304_kombax_public_profiles_member_spectator_r117.sql`
- `305_kombax_pilot_easy_linking_elite_social_network_r117.sql`
- `306_kombax_elite_social_universal_public_profiles_r117.sql`

El backend piloto activo ya contiene estos hotfixes. No ejecutar automáticamente `supabase db push` sobre ese proyecto únicamente para desplegar build 20171; primero habría que reconciliar el historial de migraciones local con el historial aplicado mediante operaciones de hotfix.

## QA ejecutado

- R115 onboarding/member gate: 11/11 PASS.
- R116 Golden Pilot freeze: 12/12 PASS.
- R117 perfiles/alta abierta: 7/7 PASS.
- R117 build 20171 Pilot Hotfix: 15/15 PASS.
- Contrato frontend/backend: PASS.
- Netlify pilot release gate: 62 PASS, 5 P2 de i18n históricos conocidos, 0 fallos nuevos.
- Paridad `web = dist = android/app/src/main/assets/www`: verificada por `build.mjs`.
- I18N full product audit: 241 unresolved, por debajo de la base R117 original comprobada (246); sin regresión neta. El copy nuevo del hotfix usa fallback inglés fuera de ES hasta curación nativa completa.
- Android preflight: 7/8 en este entorno; falta la clave de firma local, que no se incluye en el ZIP por seguridad.
- Compilación Android en este entorno: no completada porque el entorno no dispone de acceso de red a `services.gradle.org` para descargar Gradle 8.11.1. El código fuente, assets y preflight están preparados para compilar en el PC de release.

## Google Play

No cancelar la revisión actual. Build 20171 utiliza el mismo package `com.urbanwarriors.app` y debe firmarse con la misma clave. Cuando Play Console permita la actualización del track cerrado, subir `KOMBAX_20171_R117_PILOT_HOTFIX_GOOGLE_PLAY.aab`.

## Regla de cierre

Este ZIP pasa a ser la base acumulativa de trabajo del hotfix cuando se verifique en el PC de release:

1. build Android debug;
2. prueba de llamada/multitarea en dispositivo real;
3. AAB release firmado;
4. deploy Netlify build 20171;
5. smoke test web/Android de Auth, Social, Showcase y Events.
