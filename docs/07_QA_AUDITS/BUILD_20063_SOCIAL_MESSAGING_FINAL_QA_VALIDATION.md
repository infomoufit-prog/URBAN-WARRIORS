# KOMBAX 20.063 · SOCIAL MESSAGING FINAL QA · VALIDATION

Fecha: 2026-08-20
Base: KOMBAX 20.062
Estado: **CANDIDATA DE VALIDACIÓN MÓVIL · NO FREEZE**

## Implementado

- `Cerrar chat` eliminado de la UI; `X` conserva hilo y limpia sincronización visible.
- `Eliminar conversación` como acción destructiva explícita.
- Comentarios inline sin segundo modal.
- Contact Gate frontend 10–500.
- `Mi red` / `Añadir a mi red` en UX Social.
- Mensajes con acceso superior independiente y badge.
- Bandeja con filtros Todos/Social/Showcase.
- Showcase con contexto visual de producto en bandeja y conversación.
- CTA de contacto desde Showcase.
- Backend v107 preparado para hilo por pareja+producto y badge por conversaciones no leídas.
- Fallback v107→v106/v104 para mantener Social operativo antes de activar 107.

## Pruebas automáticas

- `scripts/test-kombax-20063-social-messaging-final.mjs`: **PASS**.
- `npm test`: **PASS**.
- `npm run build`: **PASS**.
- Builder: **66 archivos · web = dist = Android**.
- Paridad independiente: 66 / 66 / 66.
- Missing/extras: 0.
- Diferencias SHA-256 web→dist: 0.
- Diferencias SHA-256 web→Android: 0.
- Web tree SHA-256: `e867bdf47a9f6c4be50eb3a51f283f6747334eccb36725fa62ae082d53661952`.

## Android

- applicationId: `com.urbanwarriors.app` — OK.
- versionCode: `20063` — OK.
- versionName: `2.0.0-rc.13`.
- assets/www — OK.
- Firebase — OK.
- Firma local — PENDIENTE por diseño; el JKS y `keystore.properties` real no se empaquetan.
- Preflight: **4/5**.

El contenedor de trabajo dispone de Java pero no tiene Gradle 8.11.1 cacheado y no puede descargarlo por restricción de red. Por tanto no se afirma ni se adjunta un APK signed generado en este entorno. El proyecto Android está preparado para generarlo localmente con el JKS existente.

## Secret audit

- JKS/keystore/P12/PFX/PEM/KEY empaquetados: 0.
- `android/keystore.properties` real: ausente.
- plantilla `.example`: se conserva.

## Supabase

Auditoría live de solo lectura antes de 107:

- `app_kombax_social_network_mutate_v104`: existe.
- `app_kombax_contactos_v106`: existe.
- `app_kombax_header_summary_v106`: existe.
- tablas Contactos/Showcase: existen.
- índice histórico de pareja abierta: existe.
- `canal`: todavía no existe live en el momento de la auditoría.
- contactos existentes: 5.
- mensajes existentes: 19.
- no se detectaron parejas abiertas duplicadas en el preflight.

La migración 107 está preparada con preflight/verificación/rollback, **pero no se aplicó live en este cierre** para no modificar silenciosamente el backend compartido mientras 20.062 permanece como referencia desplegada.

## Netlify

**No se realizó deploy de 20063.** La 20.062 debe permanecer como versión web de referencia durante la validación de la APK 20063.

## Validación manual pendiente

- dos cuentas reales A/B;
- chat Social X/reapertura/historial;
- eliminación;
- badge y marcado leído;
- comentarios inline;
- Mi red;
- activar 107 de forma controlada;
- Showcase producto A y producto B con hilos separados;
- imagen/nombre/marca persistentes;
- pérdida/recuperación de red;
- regresión web 20062 tras activar 107;
- APK signed física.
