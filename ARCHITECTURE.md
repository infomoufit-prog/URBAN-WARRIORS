# Arquitectura · KOMBAX / Urban Warriors RC13 build 20025

## Capas

1. Puerta pública KOMBAX y selección de club.
2. Auth global Supabase y resolución de contextos propios.
3. Shell privado del tenant, con tema, permisos, estado y caché por `club_id + perfil_id`.
4. Comunidad del Club, siempre interna al tenant.
5. KOMBAX Social, capa global opcional con identidad pública separada.
6. KOMBAX Showcase, catálogo global informativo separado.
7. Repositorios frontend, backend versionado, RPC seguras, RLS y Storage.

La fuente es `web`; `dist` y Android se generan, nunca se editan como fuentes independientes.

## Escrituras

- Negocio histórico del club: `UI → repositories → backend.mutate → contrato → app_mutate_v160`.
- KOMBAX Social: `UI → repositories → backend.writeRpc → app_kombax_social_mutate_v041`.
- Showcase: `UI → repositories → backend.writeRpc → app_kombax_showcase_mutate_v042`.

Los tres flujos usan `request_id`, validan la respuesta antes de actualizar la UI y no conceden permisos desde el frontend.

## Contexto multiclub

`app_mis_contextos_kombax_v040` resuelve clubes y perfiles directos propios. El cambio de club exige membresía activa, invalida caché/estado del tenant anterior y vuelve a validar el contrato. Los recursos privados conservan `club_id`; los dominios globales usan un sujeto público normalizado.

## Dominios 037–042

- 037: lectura consistente de notificaciones compartidas/individuales.
- 038: activo/archivo/papelera y recuperación de contenido no financiero.
- 039: temas cerrados y branding versionado.
- 040: puerta, directorio público limitado, perfiles directos, suscripciones y entitlements.
- 041: perfiles/feed/likes/contactos/denuncias/moderación de KOMBAX Social.
- 042: marcas/categorías/fichas/gestores de KOMBAX Showcase.

## Separaciones invariantes

- Comunidad del Club no se publica automáticamente en KOMBAX Social.
- Identidad pública no contiene expediente, finanzas, asistencia, documentos o familia.
- Perfil directo, membresía, suscripción y entitlement son conceptos diferentes.
- Showcase no comparte modelo con `material_catalogo` ni con finanzas del club.
- Datos DEMO no conceden acceso ni se insertan en producción.

## Rendimiento

Feeds y directorios tienen cursor/límite; los índices siguen tenant/estado/fecha; la caché incluye tenant y usuario; las métricas cliente registran P50/P95 y cargas superiores a cinco segundos. Los fixtures/K6 preparan la medición, pero no certifican capacidad sin ejecución real.

## Android

`com.urbanwarriors.app`, versionCode 20025, SDK 36, Java 17 y aplicación web embebida desde origen HTTPS virtual. La firma y Firebase se inyectan localmente.
