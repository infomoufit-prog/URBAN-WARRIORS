# KOMBAX RC13 · build 20040 · Social Affiliation + Contacto KOMBAX

## Alcance implementado

- Afiliación pública verificada Miembro ↔ Club basada en membresía real y activa (`identidades_sociales` + `socios`), no en texto libre.
- Control de visibilidad pública de la afiliación por el propio Miembro.
- Publicación voluntaria canónica de afiliación verificada.
- Feed, directorio y perfil público enriquecidos con afiliación y enlace al perfil Social del Club.
- Evolución de solicitudes de contacto a **Contacto KOMBAX** profesional de solo texto.
- Máximo **20 mensajes totales por hilo**, incluido el mensaje inicial.
- Máximo 500 caracteres por mensaje; sin multimedia, archivos, grupos, presencia, estado online ni indicador de escritura.
- Auto-cierre al mensaje 20 y cierre manual previo por cualquiera de los participantes.
- Barrera 18+ para perfiles personales de contacto, conservando KOMBAX Social 14+ como capa separada.
- Bloqueo bilateral: un bloqueo impide iniciar o continuar el contacto.
- Acceso a mensajes limitado a participantes autorizados; moderación no obtiene lectura privada global implícita.
- Normas KOMBAX Social 1.2.0 alineadas con la función nueva.

## Backend desplegado

- Migración 065: `065_kombax_social_affiliation_contact_20040.sql` — APLICADA.
- Migración 066: `066_kombax_contact_index_hardening_20040.sql` — APLICADA.
- Normas `comunidad_general` 1.2.0: vigentes.
- Normas 1.1.0: no vigentes.

### Hilo histórico Urban Warriors ↔ Bryan Rivera

El contacto aceptado existente se migró conservando su solicitud como mensaje 1/20.
Tras todas las pruebas transaccionales y rollbacks de QA, el hilo real quedó:

- estado: `aceptada`
- límite: `20`
- mensajes persistentes: `1`
- último ordinal persistente: `1`

No quedaron mensajes QA persistentes.

## Validaciones de backend real

- Afiliación de Bryan Rivera devuelve Urban Warriors con `verificada=true` y fuente `membresia_club`.
- Envío Urban Warriors → Bryan: PASS en transacción con rollback.
- Envío Bryan → Urban Warriors: PASS en transacción con rollback.
- Mensaje 20: PASS; cierra automáticamente el hilo, deja 0 restantes y `puede_chat=false`.
- Intento mensaje 21: PASS; backend devuelve `KOMBAX_CONTACT_MESSAGE_LIMIT_20`.
- Bloqueo inverso Bryan → Urban Warriors: PASS; Urban Warriors no puede continuar el hilo (`KOMBAX_CONTACT_BLOCKED`).
- Tabla de mensajes: sin SELECT directo para `authenticated`.
- Helpers internos de autorización/bloqueo: sin EXECUTE directo para `authenticated`.
- RPC públicas de contactos/mensajes/mutación: EXECUTE autorizado para `authenticated`.
- 8/8 claves foráneas del agregado Contacto KOMBAX tienen índice de cobertura tras 066.

## Regresión y build

- `npm run build`: PASS.
- Suite histórica RC4 → build 20040: PASS.
- Regresión específica `test-kombax-20040-social-affiliation-contact.mjs`: PASS.
- Arquitectura: ningún módulo de UI/core introduce `fetch` directo fuera de la capa autorizada.
- Build determinista: `62 archivos · web = dist = Android`.
- Hash cruzado web/dist/Android: 0 faltantes, 0 extras, 0 diferencias.

## Smoke test local

Servidor aislado levantado con `node scripts/serve.mjs` en `127.0.0.1:4175`:

- index con assets `v=20040`: PASS.
- `config.js` build 20040: PASS.
- UI `Contacto KOMBAX`: PASS.
- UI `Afiliación verificada`: PASS.
- CSS de Contacto KOMBAX: PASS.

## Android

Preflight build 20040:

- applicationId `com.urbanwarriors.app`: OK.
- versionCode `20040`: OK.
- `assets/www`: OK.
- Firebase: OK.
- firma local JKS / `keystore.properties`: **PENDIENTE**.

Resultado Android: **4/5**. No se afirma ni se certifica APK/AAB release firmada en este paquete.

## Seguridad del paquete

Comprobado antes de empaquetar:

- 0 `.jks`.
- 0 `.keystore`.
- 0 `keystore.properties`.
- 0 `.p12` / `.pem`.
- 0 directorios `node_modules`.
- `android/app/google-services.json`: presente, como requiere el proyecto Firebase Android.

## Archivos operativos añadidos

- `supabase/verification/verify_065_kombax_social_affiliation_contact_20040.sql`
- `supabase/verification/verify_066_kombax_contact_index_hardening_20040.sql`
- `supabase/rollbacks/065_kombax_social_affiliation_contact_20040_rollback.sql`
- `supabase/rollbacks/066_kombax_contact_index_hardening_20040_rollback.sql`

El rollback 065 es deliberadamente marcado como destructivo para mensajes creados después de 065 y no fue ejecutado. El rollback 066 es no destructivo sobre datos y solo elimina índices.

## Deuda fuera de alcance

Los Advisors de Supabase siguen mostrando deuda histórica global de seguridad/rendimiento en tablas, vistas, funciones e índices anteriores a esta intervención. No se han realizado cambios masivos fuera del agregado Social/Contacto para evitar romper contratos estables. La deuda nueva detectada dentro del agregado Contacto se cerró en 066.
