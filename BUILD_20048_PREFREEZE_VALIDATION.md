# KOMBAX RC13 build 20048 · PRE-FREEZE validation

Fecha de cierre técnico: 2026-08-19

## Estado

**PRE-FREEZE CANDIDATE**, pendiente de validación visual/funcional final por el usuario en CMD y móvil antes de declarar `KOMBAX BASE FREEZE`.

No se ha realizado deploy en GitHub/Netlify, no se ha firmado APK/AAB y no se ha publicado en Google Play.

## Baseline

Fuente de trabajo: build 20047 `MEMBER_PROFILE_ENRICHMENT`.

Antes del primer cambio de 20048:

- `npm test`: PASS.
- `npm run build`: PASS.
- builder: 62 archivos y `web = dist = Android`.

La 20.047 se mantiene como punto de retorno; no se modifica.

## Objetivo de 20048

Cerrar la arquitectura de identidad y la navegación visual del Club antes del freeze:

1. Un único perfil visible para el Miembro: su perfil KOMBAX Social canónico.
2. Incorporar información deportiva opcional como secciones del mismo perfil, sin crear una segunda identidad.
3. Mantener la continuidad del mismo Social ID al evolucionar a Competidor verificado.
4. Retirar de la navegación activa el antiguo `Perfil deportivo compartido` sin borrar todavía datos legacy.
5. Unificar Comunidad del Club/directorio/`Mi perfil` para abrir siempre el mismo `social_id` KOMBAX.
6. Sustituir la portada/campaña como fondo global por un fondo negro con logo del Club desenfocado y muy sutil.
7. Revalidar seguridad, privacidad, edad, build web/PWA/Android y ausencia de secretos.

## Arquitectura de perfil canónico

### Identidad visible

Para un Miembro, `Mi perfil` y el perfil que abren otras personas son la misma identidad pública KOMBAX Social.

Incluye:

- banner;
- avatar;
- nombre público;
- bio/presentación;
- afiliación confirmada al Club;
- álbum personal;
- publicaciones/actividad Social;
- información deportiva pública opcional.

Campos deportivos canónicos añadidos a `identidades_sociales`:

- `apodo_deportivo`;
- `disciplinas_publicas`;
- `experiencia_anos`;
- `guardia`;
- `tecnica_favorita`;
- `especialidad`;
- `trayectoria_declarada`;
- `objetivos`.

Estos campos son **declarados por el Miembro** y no equivalen a resultados, licencias o datos deportivos verificados oficialmente.

### Miembro != Competidor verificado

El Miembro sigue sin badge KOMBAX. La evolución a Competidor utiliza el mismo Social ID y añade las capacidades/verificación correspondientes. No crea una segunda persona.

### Capa privada del Club

Continúan separadas y privadas:

- asistencia;
- cuotas/cobros;
- documentos;
- seguimiento;
- fotografía privada de cuenta;
- fecha de nacimiento y datos protegidos;
- información administrativa.

La foto privada del Club nunca se publica automáticamente como avatar Social.

## Legacy `perfiles_deportivos`

La tabla y módulo históricos se **preservan por compatibilidad y recuperación**, pero no son superficie activa en 20048.

Verificado en frontend actual:

- 0 imports activos de `sports-profile.js`;
- Portal no abre perfil deportivo legacy;
- Comunidad del Club resuelve autores a `social_id` KOMBAX;
- directorio del Club devuelve perfiles KOMBAX canónicos;
- el sincronizador actual de Miembro contiene 0 referencias a `perfiles_deportivos`.

Preflight de datos antes de migración 094:

- 1 fila legacy;
- 0 filas con datos deportivos de texto;
- 1 fila con foto legacy;
- 2 identidades Social Miembro activas.

La migración 094 solo rellena un campo canónico cuando el valor Social está vacío. No sobrescribe información Social más reciente. La foto legacy no sustituye un avatar Social existente.

La tabla no se elimina físicamente en este build. Hacerlo antes de retirar compatibilidad con clientes antiguos sería innecesariamente arriesgado.

## Migraciones Supabase aplicadas

Proyecto: `poggsobhtutbuagjiydc`.

- `20260819002604 · kombax_canonical_member_profile_20048` (094)
- `20260819002821 · kombax_club_social_directory_20048` (095)

### 094

- campos deportivos canónicos;
- backfill conservador;
- sincronizador Miembro desligado del perfil deportivo legacy;
- `app_kombax_identity_mutate_v094`;
- `app_kombax_perfil_publico_v094`;
- Relaciones eliminadas explícitamente de la respuesta pública;
- ACL: authenticated permitido, anon cerrado.

Smoke transaccional de edición como Brian:

- escritura de todos los nuevos campos: PASS;
- verificación dentro de la transacción: PASS;
- `ROLLBACK`: PASS;
- 0 datos de prueba persistidos.

### 095

`app_kombax_club_social_directory_v095` devuelve únicamente identidad pública canónica para personas del mismo Club.

Live Urban Warriors:

- Urban Warriors -> Social Club;
- BRYAN RIVERA GREY -> Social Miembro;
- Sheila Azogue -> Social Miembro.

No devuelve Relaciones ni datos administrativos.

Prueba negativa con identidad autenticada sin membresía:

- resultado esperado `CLUB_MEMBERSHIP_REQUIRED`: PASS.

Actualmente solo existe un Club real en los datos de prueba, por lo que no se fingió una prueba real Club A -> Club B. La prueba negativa se ejecutó con una identidad autenticada simulada sin membresía.

## Continuidad Miembro -> Competidor

Smoke live dentro de transacción con fixture temporal y `ROLLBACK`:

- Social ID inicial de Brian: `b6503c0c-d47c-45f7-beaa-f325211ed70b`;
- activar Competidor verificado + servicio -> mismo Social ID: PASS;
- sujeto pasa a `perfil_directo`: PASS;
- badge/verificación activa: PASS;
- desactivar servicio -> mismo Social ID: PASS;
- vuelve a `miembro`: PASS;
- badge retirado: PASS;
- 0 duplicados: PASS;
- fixture Competidor, suscripción y evento de verificación eliminados por rollback: PASS;
- Brian restaurado exactamente como Miembro: PASS.

## Fondo global del Club

El antiguo shell podía reutilizar `portada_url` como background global, mostrando campañas/ropa detrás de navegación.

20048 cambia el shell común:

- negro dominante `#050608`;
- solo `--uw-logo-image` como marca de agua;
- opacidad muy baja;
- grayscale;
- blur;
- centrado y tamaño limitado;
- ajustes específicos de móvil;
- contenido por encima del background con z-index controlado.

Verificado:

- `.content-shell::before`: logo, no cover;
- `.store-hero::after`: logo, no cover;
- 0 referencias CSS activas a `--uw-cover-image`;
- la portada sigue disponible en banner público y editor/preview de branding, donde sí corresponde.

## Privacidad y condiciones

El perfil canónico no redirige al manual.

`Privacidad y condiciones` llama a `openPrivacyConditions()` y muestra el centro legal del Club. La ayuda explica expresamente que perfil Social público y expediente privado del Club son capas distintas.

## Edad y privacidad backend

Verificación viva posterior a 094/095:

- activación del Miembro requiere fecha de nacimiento de Club: PASS;
- edad mínima Social usa `app_edad_min_comunidad_general_v036`: PASS;
- enforcement de mínimo Social en backend: PASS;
- contrato Contacto 18+ presente en backend: PASS;
- Relaciones sin SELECT directo authenticated: PASS;
- documentos de verificación sin SELECT directo authenticated: PASS;
- perfil deportivo legacy sin SELECT directo authenticated: PASS.

## Hardening 20.046 revalidado después de 094/095

Contrato global: todo PASS.

- owner KOMBAX activo;
- Relaciones privadas;
- documentos de verificación privados;
- bucket de verificación privado;
- bucket de multimedia restringida privado;
- 0 tautologías RLS detectadas;
- todos los `SECURITY DEFINER` públicos con `search_path` fijado;
- 0 funciones trigger ejecutables por clientes;
- feed/mutate Social antiguos cerrados;
- APIs actuales Social 085 abiertas solo según contrato;
- 094/095 ACL correctas;
- sincronizador Miembro desligado del legacy;
- tabla legacy preservada y privada.

## Supabase Security Advisor

Se volvió a ejecutar después de 094/095.

Los avisos restantes se clasifican en:

1. **Endpoints públicos intencionados** para catálogo/búsqueda/Showcase y compatibilidad de código de acceso.
2. **Gateways authenticated SECURITY DEFINER actuales**, incluidos 094/095, con guards/ACL probados.
3. **Helpers usados por RLS**, que no pueden revocarse indiscriminadamente sin romper policies.
4. Tablas RLS sin policy directa que están diseñadas como deny-by-default detrás de RPCs.

No se detectó una nueva ruta no controlada introducida por 094/095.

### Pendiente manual antes de producción

**Leaked Password Protection continúa desactivado en Supabase Auth.** El conector disponible no expone un ajuste seguro para activarlo. Debe habilitarse en consola antes de release de producción y después repetir alta/login/recuperación de contraseña.

## Performance Advisor

Reejecutado. Mantiene deuda histórica, entre ella:

- FKs sin índice;
- `auth_rls_initplan`;
- policies permisivas múltiples;
- índices no usados;
- un índice duplicado en `material_pedidos`.

No es una regresión de 20048 ni un hallazgo de confidencialidad. **Se aplaza deliberadamente la optimización masiva** para no introducir riesgo de regresión en la última fase previa al freeze.

## Regresión y build final

Después de todos los cambios y migraciones:

- `npm run build`: PASS.
- suite completa histórica + 20048: PASS.
- builder: `OK build 62 archivos · web = dist = Android`.

Comparación independiente SHA-256:

- web: 62 archivos;
- dist: 62 archivos;
- Android assets/www: 62 archivos;
- missing: 0;
- extra: 0;
- content diff: 0;
- SHA agregado en los tres árboles: `780a95246cdd67952fafc175fdba1d4be2957d63e6a1ca71cdd17abc3c655a9a`.

## Android preflight

Resultado: **4/5**.

PASS:

- applicationId `com.urbanwarriors.app`;
- versionCode `20048`;
- assets `www` presentes;
- Firebase configurado.

PENDIENTE intencionado:

- firma local. No se incluyen `keystore.properties`, JKS ni contraseñas en el paquete fuente.

No se ha generado release APK/AAB en este cierre.

## Escaneo de secretos

Antes del empaquetado:

- filenames de riesgo reales: 0;
- private key headers: 0;
- AWS access keys: 0;
- GitHub PAT/tokens: 0;
- Google private key JSON: 0;
- service-role JWT literal detectado: 0.

Se conserva `keystore.properties.example` como plantilla sin secreto y `google-services.json` como configuración Firebase esperada.

## Criterio de freeze

20048 **no se declara todavía BASE FREEZE**. Primero debe superar la validación manual final por CMD/móvil del usuario.

Orden recomendado para esa validación:

1. login alumno;
2. `Mi perfil` canónico;
3. editar banner/avatar/bio/información deportiva;
4. álbum;
5. Privacidad y condiciones;
6. Comunidad del Club -> clic autores/directorio;
7. KOMBAX Social -> clic Brian/Sheila/Club;
8. sesión gestor;
9. Club: alumnos, asistencia, cuotas, recibos, comunicaciones, material, documentos, notificaciones;
10. Administración KOMBAX;
11. móvil/responsive/background.

Si aparece una incidencia, se clasifica antes de freeze. Ningún fallo desconocido se dará por aceptado.
