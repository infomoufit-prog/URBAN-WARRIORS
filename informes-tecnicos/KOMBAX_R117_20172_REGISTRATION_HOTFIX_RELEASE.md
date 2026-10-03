# KOMBAX R117 · build 20172 · Pilot Hotfix 2 · Registro/Auth

## Identidad

- Release: `2.0.0-rc.13-r117-pilot-hotfix-2`
- Android `versionCode`: `20172`
- Package: `com.urbanwarriors.app`
- Base inmediata: R117 build 20171 Pilot Hotfix 1.
- Ámbito: estabilización de altas, identidad, fecha de nacimiento y coherencia frontend/backend durante piloto.

## Incidencia que origina el hotfix

Una cuenta nueva podía mostrar el campo Fecha de nacimiento en la interfaz y, aun así, fallar antes de crear `auth.users`. El backend exigía `raw_user_meta_data.fecha_nacimiento`, mientras determinadas rutas frontend no lo enviaban al `signUp`. El error específico terminaba convertido en un mensaje genérico.

La cuenta de prueba `sheilaazogue@gmail.com` no llegó a persistirse en Auth, por lo que no quedó una cuenta parcial que limpiar.

## Contrato de registro consolidado

Toda creación de cuenta nueva utiliza fecha de nacimiento privada y normalizada como `YYYY-MM-DD`. La validación se realiza tanto en frontend como en el trigger de Auth. La fecha se conserva en `kombax_account_private_r117` y no forma parte del perfil público.

Se han cubierto las entradas de registro global, Miembro/Practicante, Familiar/Tutor, invitación de alumno, invitación de equipo y Club Piloto. Los perfiles directos parten de una cuenta ya creada y reutilizan su contexto de edad, aplicando además las reglas específicas cuando corresponda.

## Cuentas históricas

No se inventan fechas. El backend realiza backfill únicamente cuando las fuentes canónicas existentes coinciden en una única fecha. Si una cuenta antigua sigue sin DOB, el frontend abre un flujo privado de completado de una sola vez mediante RPC autenticado.

Tras el backfill seguro en el backend piloto: 14 cuentas Auth / 14 perfiles; 6 cuentas con DOB canónica y 8 históricas pendientes de aportarla. Esas ocho no se rellenan artificialmente.

## Identidades y capacidades

Se conserva la arquitectura del Hotfix 1:

- Miembro/Practicante sin club: Perfil Social, avatar, banner, información pública, álbum y Mi Red; sin publicación de feed.
- Miembro confirmado por club: misma identidad; publicación Social habilitable conforme a edad/consentimientos.
- Espectador: perfil público básico, avatar/banner/info/red; sin álbum y sin feed.
- La pertenencia a club desbloquea la capa privada de alumno: ficha, cuotas/cobros, asistencia, documentos y comunicaciones internas.
- La navegación/compra pública de Showcase y Events no depende de pertenecer a un club; conserva reglas de edad y pago.
- Taxonomía backend alineada e incluye Media.

## Club Piloto

Durante la ventana y plazas configuradas, Club Piloto es autoservicio: sin código específico del programa piloto y sin autorización manual previa. Las invitaciones/códigos de alumnos y familias siguen existiendo como vía opcional de vinculación y no deben confundirse con el alta del Club Piloto.

## Errores y sesión

Se añaden mensajes concretos para DOB obligatoria/inválida, edad mínima y email ya registrado. Se mantiene la limpieza del contexto de sesión y el flujo de login/recuperación como parte del smoke test. No se expone DOB públicamente.

## Android acumulativo

Se conserva la reparación de continuidad de build 20171: WebView state/última URL interna segura y recuperación de ruta tras llamada, multitarea o recreación de Activity. Build 20172 empaqueta los nuevos assets web y requiere un nuevo AAB para que Android incorpore la corrección de registro.

## Backend canónico incluido

Migraciones R117 acumulativas:

- 302 `pilot_social_read_and_member_interest`
- 303 `pilot_open_registration_no_code`
- 304 `public_profiles_member_spectator`
- 305 `pilot_easy_linking_elite_social_network`
- 306 `elite_social_universal_public_profiles`
- 307 `pilot_club_direct_self_service`
- 308 `registration_birth_date_contract`

El backend piloto activo ya contiene los hotfixes funcionales equivalentes. No ejecutar `supabase db push` automáticamente sobre ese proyecto sin reconciliar el historial.

## QA ejecutado

- R115 onboarding/member gate: **11/11 PASS**.
- R116 Golden Pilot freeze: **12/12 PASS**.
- R117 perfiles/alta abierta: **7/7 PASS**.
- R117 build 20172 Registro/Auth: **34/34 PASS**.
- Build/paridad: **624 archivos · web = dist = Android**.
- Netlify pilot release gate: **63 PASS, 5 P2 i18n históricos conocidos, 0 fallos nuevos**.
- I18N full-product audit: **241 unresolved**, por debajo del baseline permitido del gate; no hay regresión nueva provocada por este hotfix.
- Android preflight: **7/8** en este entorno; falta exclusivamente la clave privada de firma local, que no se distribuye dentro del ZIP.
- Build Android debug intentado: **no completado por restricción de red del entorno** al resolver `services.gradle.org` para Gradle 8.11.1; no es un fallo de compilación del código verificado. El log queda en `artifacts/R117_20172_ANDROID_DEBUG_BUILD.log`.

## Pendiente de validación externa

1. Deploy de `dist` en el sitio correcto de Netlify/KOMBAX.
2. Smoke test real de creación de una cuenta nueva, incluyendo confirmación de email.
3. Compilar APK debug y validar en dispositivo las rutas de alta y continuidad Android.
4. Generar AAB 20172 firmado con la misma upload key.
5. Subirlo al mismo track cerrado de Google Play cuando corresponda, sin cancelar innecesariamente una revisión existente.

Hasta completar estas validaciones externas, la fuente queda preparada y verificada, pero no se debe afirmar que el deploy web o el AAB 20172 estén publicados.
