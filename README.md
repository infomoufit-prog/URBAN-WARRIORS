# KOMBAX R110.1 · build 20164 · Pilot release gate + Android preflight

## R110.1 release gate

Netlify queda desbloqueado mediante baseline de no regresión (255 R79 / 242 runtime), sin desactivar los audits estrictos. Android usa build 20164 y añade `npm run android:pilot-release` para generar/verificar APK + AAB con la firma existente. La firma definitiva no se incluye en el repositorio.

Esta entrega acumulativa parte de R109 y añade la vía excepcional **Alta como Club Piloto** para un máximo de 4 clubes autorizados. La vía piloto no modifica ni sustituye la arquitectura oficial de verificación: durante la ventana temporal, un código de acceso de un solo uso permite crear y validar un Club KOMBAX real sin solicitar CIF, documentos ni evidencias al usuario. El Club recibe el beneficio `PILOT_ACCESS` con capacidades Premium, queda marcado como fundador elegible y conserva el mismo `club_id`, miembros, historial y datos después del cierre del piloto.

La ventana de registro piloto permanece abierta hasta el final del **15/11/2026** y el seguimiento operativo se mide desde el **05/10/2026**. Tras el cierre se retira únicamente la puerta especial de alta; los Clubes no se desactivan ni requieren una segunda verificación. Los beneficios fundadores posteriores se asignan según el programa correspondiente, sin inventar un único beneficio universal.

Owner incorpora generación de accesos de un solo uso, control duro de 4 plazas y métricas por Club/agregadas de miembros, vinculaciones/tutores, invitaciones, solicitudes de vinculación, preinscripciones, sesiones, asistencias, Social, Events, migraciones, Assist, créditos y coste API. La integración reutiliza los flujos R58/R59 de membresía y tutoría.

Supabase incluye la migración aditiva `297_kombax_pilot_club_activation_owner_r110.sql`; Web/PWA y Android usan build `20164`. La migración R110 está aplicada en el proyecto Supabase activo. R110.1 no modifica esquema: corrige el release gate de Netlify sin ocultar la deuda i18n heredada y refuerza la validación Android.

> Estado de cierre: **PASS CON VALIDACIÓN ANDROID EXTERNA PENDIENTE**. QA R110 32/32, gates de identidad/membresía/discovery/i18n verdes y build web/dist/Android-assets sincronizado. La compilación Gradle real no puede ejecutarse en este entorno porque Gradle 8.11.1 no está cacheado y no hay acceso a `services.gradle.org`.

## Historial acumulativo

# KOMBAX R109 · build 20162 · Cierre pre-piloto de identidad y permisos

Esta entrega acumulativa parte de R108 y aplica el último ajuste de identidad/perfiles previo al piloto real: Competidor autónomo verificado sin dependencia obligatoria de Club, publicación Social de Competidor/Profesional desacoplada de membresía, onboarding de Competidor desde cuenta personal y verificación proporcional de Media/Creador. Mantiene R100-R108, Miembro ligado a membresía, Promotor/Organizador como especialidad Profesional y la separación identidad/capability/plan/Stripe.

Supabase incluye la migración aditiva `296_kombax_prepilot_identity_permissions_r109.sql`; Web/PWA y Android usan build `20162`. Los informes técnicos R109 están en `informes-tecnicos/`.

> Estado de cierre: **PASS CON OBSERVACIÓN**. Los cambios R109 y sus regresiones específicas están verdes; permanecen deudas QA/i18n heredadas de R108 y un hueco histórico R28 en los archivos locales de migración, documentados sin inventar ni duplicar migraciones.

## Historial acumulativo

# KOMBAX R104 · build 20156 · Logo público del club

Esta entrega acumulativa conserva R102 y versiones anteriores. Assist y Migrations
utilizan el mismo monedero por entidad, con consumo basado en el uso oficial de la
API, precisión de milésimas, reserva por ejecución y panel Owner de costes. La
interfaz de los agentes muestra únicamente Créditos IA. El piloto y el primer
mes pagado mantienen sus créditos específicos.

Consulta [la auditoría, implementación y límites de QA R103](docs/releases/R103_AI_CREDITS_CLOSURE.md).

## Historial anterior

# KOMBAX R102 · build 20154 · Insignias por verificación y pago

Esta es la entrega acumulativa R102. Incluye las fuentes web, Android, iOS,
base de datos, documentación y pruebas de las versiones anteriores. Media / Creador
dispone de Mi contenido; Miembro y Competidor conservan identidades Social
diferenciadas; Competidor verificado puede abrir Mi Showcase y solicitar su
verificación como vendedor cuando su plan incluye Showcase. Las cuentas gratuitas no muestran insignia oficial, salvo Competidor verificado.
Club, Marca y Federación la muestran tras confirmar el pago de su suscripción. Consulta
[el informe R102](docs/releases/R102_VERIFIED_BADGES.md),
[el informe R101](docs/releases/R101_PROFILE_SPACES.md) y
[el informe R100](docs/releases/R100_ACCOUNT_IDENTITY_POLICY.md).

El historial que sigue describe entregas anteriores y se conserva como referencia.

# KOMBAX R92 · build 20145 · Centro KOMBAX

## R92 · Biblioteca y guías de uso

- Las 19 guías temáticas públicas se presentan como tres volúmenes completos: club, federaciones/licencias/interclubs y eventos. Los 18 temas originales se conservan dentro de los volúmenes; la antigua guía de lectura se integra en la orientación de la nueva biblioteca.
- Las 19 fichas territoriales se consultan desde un selector, sin ocupar 19 tarjetas en la pantalla inicial.
- Nueve guías de uso explican tareas de Club, Federación, Marca, Competidor, Profesional, Espectador, Alumno/Miembro, Familia y Media/Creador. Cada una dispone de lectura web y PDF generados desde el mismo contenido editable.
- Recursos KOMBAX reúne uso, conocimiento, territorios y Consultoría en una sola ventana de acordeones. Los perfiles directos también tienen acceso al centro.
- KOMBAX Social recibe un icono cuadrado con halo LED en la barra lateral.
- El manual premium privado de gestión de clubes permanece fuera de los assets públicos.
- Esta entrega actualiza la interfaz y las fuentes empaquetadas. No incluye una migración de base de datos ni realiza despliegues remotos.

## R91 · Biblioteca pública R100.1

- 38 guías públicas profesionales R100.1 integradas en KOMBAX Guías.
- Las 19 guías territoriales sustituyen la duplicación territorial anterior en la interfaz pública.
- El Manual KOMBAX de Gestión de Clubes queda preparado como producto privado: incluido en Premium y precio individual de referencia de 6 €.
- El PDF completo del manual NO se publica en `web`, `dist` ni Android hasta activar control de acceso comercial.
- No se implementa en R91 ningún dossier de alumnado, formador, banco de preguntas, LMS ni capa formativa de Claude R100.

## Base acumulativa vigente

Este paquete es la **base acumulativa completa de KOMBAX R92 build 20145** y sustituye a R91/R90/R89/R88/R81 y a cualquier ZIP anterior como fuente de continuidad.

Versión runtime:

- Web/PWA: `2.0.0-rc.13-r92-resource-center`
- Android `versionCode`: `20145`
- Android `versionName`: `2.0.0-rc.13-r92-resource-center`
- Android `compileSdk`: `36`
- Android `targetSdk`: `36`
- Supabase health en el paquete: build `20145`

R91 conserva íntegramente R89 y añade una entrada post-login premium basada en assets oficiales de KOMBAX, accesos persistentes a KOMBAX Guías y KOMBAX Consultoría, portadas premium para ambos recursos y apertura/descarga robusta de PDFs también desde Android WebView mediante puente nativo y FileProvider.

## Estructura principal

| Ruta | Uso |
|---|---|
| `web/` | Fuente frontend/PWA |
| `dist/` | Build generado para Netlify |
| `android/` | Proyecto Android para APK/AAB |
| `ios/` | Fuente iOS |
| `supabase/` | Migraciones y Edge Functions |
| `scripts/` | QA, build, Android y release gates |
| `docs/` | Handoff, QA, manifests e historial |
| `artifacts/` | Material documental e histórico |
| `netlify.toml` | Build/headers/redirects de Netlify |
| `package.json` | Comandos de validación y release |

## Supabase y migraciones

R91 no necesita una nueva migración de base de datos: reutiliza la arquitectura live ya cerrada en R89. El directorio `supabase/migrations/` conserva el historial acumulativo completo. La cadena final de la fase anterior incluye R83→R89:

- `20260921154230_kombax_r83_showcase_cart_checkout.sql`
- `20260921161213_kombax_r84_finance_multientity_context.sql`
- `20260921161247_kombax_r85_consulting_workflow.sql`
- `20260921161329_kombax_r86_private_training_foundation.sql`
- `20260921192549_kombax_r87_active_cart_stock_reconciliation.sql`
- `20260921193108_kombax_r88_training_access_fk_hardening.sql`
- `20260921193615_kombax_r87_event_finance_subject_context.sql`
- `20260921212710_kombax_r89_inventory_lifecycle_events_sidebar.sql`

No vuelvas a ejecutar manualmente migraciones que ya figuren aplicadas en el proyecto Supabase. Para un entorno nuevo utiliza el flujo normal de migraciones del proyecto.

## Certificación local

Regresión acumulativa completa:

```bash
npm test
```

Build de release completo:

```bash
npm run release:build
```

El build reconstruye `dist/` y sincroniza los assets Android. El gate final exige paridad entre `web`, `dist` y `android/app/src/main/assets/www`.

## Home premium y recursos KOMBAX

La primera pantalla autenticada utiliza assets oficiales de `web/assets/brand-heroes/` con tratamiento premium/neón para Social, Showcase, Events y Mi espacio. KOMBAX Guías y KOMBAX Consultoría permanecen accesibles desde:

- la portada post-login;
- el bloque permanente **Recursos KOMBAX** de la sidebar;
- el hub de Mi Club cuando corresponde.

No sustituyen a las cuatro funciones principales ni saturan el menú de producto.

## Guías PDF

El runtime incluye el catálogo completo de guías y PDFs. En navegador/PWA cada ficha ofrece **Abrir PDF** y **Descargar PDF**. En Android, la WebView delega en el puente nativo:

- `openBundledPdf(...)`: copia de forma segura la guía a caché privada y la abre con el visor PDF del dispositivo mediante `FileProvider`;
- `saveBundledPdf(...)`: usa el selector nativo para guardar una copia.

El `FileProvider` solo expone la carpeta de caché `shared-pdf/`.

## GitHub

El contenido de este paquete puede utilizarse como nueva raíz del repositorio KOMBAX.

Antes del push:

```bash
npm test
npm run release:build
```

No subas claves privadas ni firma local. `.gitignore` excluye `.env`, `android/keystore.properties`, `*.jks`, `*.keystore`, `*.apk`, `*.aab` y artefactos locales de firma.

## Netlify

`netlify.toml` ejecuta:

```toml
[build]
command = "npm run release:build"
publish = "dist"
```

Por tanto, el repositorio puede desplegarse en Netlify usando el build acumulativo R91. No se incluyen credenciales del proyecto Netlify.

## Android Studio · APK de pruebas

Abre `android/` en Android Studio o ejecuta:

```bash
npm run android:debug:qa
```

Cuando Gradle esté disponible, el helper genera:

`artifacts/KOMBAX_20144_R91_PILOT_QA_DEBUG.apk`

## Google Play · AAB

Para Google Play usa AAB:

1. Copia `android/keystore.properties.example` como `android/keystore.properties`.
2. Completa ruta y credenciales de tu clave de subida local.
3. Mantén el JKS fuera del repositorio.
4. Ejecuta:

```bash
npm run android:preflight
npm run android:aab:play
```

El helper AAB ejecuta primero `release:build`, exige el preflight y después `bundleRelease`.

El AAB queda en:

- `android/app/build/outputs/bundle/release/app-release.aab`
- `artifacts/KOMBAX_20144_R91_PILOT_GOOGLE_PLAY.aab`

## Firma

La firma no forma parte del ZIP acumulativo. El paquete contiene `android/keystore.properties.example`, pero no JKS/keystore real, contraseñas, certificados Apple, `.p12` ni perfiles de provisioning.

## Estado Android de esta certificación

Los gates estáticos Android, versionado, assets, Firebase, puente PDF y FileProvider pasan. En este entorno puede no ser posible descargar Gradle 8.11.1 desde `services.gradle.org`; la compilación/firma definitiva debe ejecutarse en el ordenador local con Android Studio/Gradle y la clave de subida.

Antes de subir a Play confirma que `npm run android:preflight` termina 5/5 y `bundleRelease` finaliza correctamente.

## Documentación de release

Empieza por:

- `docs/01_CURRENT_RELEASE/R91_BUILD_20144_PUBLIC_GUIDES_R100_1_REPORT.md`
- `docs/01_CURRENT_RELEASE/R91_BUILD_20144_MANIFEST_SHA256.txt`
- `docs/01_CURRENT_RELEASE/R92_BUILD_20145_RESOURCE_CENTER_REPORT.md`
- `docs/01_CURRENT_RELEASE/R92_BUILD_20145_MANIFEST_SHA256.txt`

La documentación R89 y anterior se conserva como historial y evidencia, no como base vigente.

## Regla de continuidad

**R92 build 20145 es la base acumulativa válida para cualquier cambio posterior.**

Para cada nueva entrega: partir de este paquete, mantener todo lo acumulado, incrementar versionado si cambia runtime, ejecutar regresión/release build, verificar Supabase/Netlify/Android, excluir secretos/firma y generar ZIP + manifest + CRC + SHA-256 nuevos.
