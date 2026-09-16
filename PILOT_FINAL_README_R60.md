# KOMBAX 20.110 R60 · PILOT FINAL

Paquete final de trabajo para validación de piloto de KOMBAX sobre la línea R60 / `versionCode 20110`.

## Alcance integrado

- Estabilización visual responsive PWA / Android / tablet.
- Safe areas y corrección de overflow móvil.
- Barra inferior móvil oculta; navegación móvil principal mediante menú lateral.
- KOMBAX Events: apertura de eventos optimizada con caché, prefetch, deduplicación, continuidad de scroll y feedback de carga sin recargar la cartelera.
- Álbumes de perfiles: fotografías y vídeos ampliables a pantalla completa manteniendo proporción original.
- Ajuste de encuadre del hero de KOMBAX Social: mantiene al peleador ligeramente a la derecha y abre el plano para recuperar los acompañantes.
- KOMBAX Assist y KOMBAX Migrations con identidad visual propia, heroes y avatar de asistente local.
- Capa `Conversaciones KOMBAX` con canales separados: Social, Showcase, Assist, Migrations y Soporte.
- Social > Mensajes abre una capa independiente de chat.
- Showcase > Me interesa abre conversación contextual propia.
- KOMBAX Assist: nueva línea IA de gestión para Club, Federación y Marca, en solo lectura durante el piloto.
- KOMBAX Migrations: línea especializada para Club/Federación, con archivos, análisis, vista previa y confirmación obligatoria.
- Soporte KOMBAX: se conserva como vía técnica/formal con ticket, chat guiado activado por Soporte y posibilidad de verificación/revisión humana.
- Límites de consumo de IA aplicados en backend y mostrados en frontend.

## Límites de KOMBAX Assist

| Plan | Conversaciones/mes | Primer mes | Mensajes del usuario por conversación |
| --- | ---: | ---: | ---: |
| Club Basic | 10 | 20 | 10 |
| Club Premium / Marca profesional | 25 | 40 | 12 |
| Federación | 40 | 60 | 14 |

KOMBAX Migrations mantiene su cupo independiente y sus límites específicos de mensajes/documentos.

## Backend live

Proyecto Supabase: `poggsobhtutbuagjiydc`.

- Migración live: `kombax_pilot_management_assist_r60`.
- Migración live: `kombax_support_guided_management_split_r60`.
- Edge Function `kombax-assist-r38`: ACTIVE, versión 7.
- `app_kombax_support_guided_status_r60`: solo `authenticated`; no `anon`.
- `app_kombax_assist_dashboard_v227`: solo `authenticated`; no `anon`.
- `app_kombax_assist_turn_reserve_v227`: solo `authenticated`; no `anon`.
- `app_kombax_customer_ops_mutate_v233`: solo `authenticated`; no `anon`.

## Estado QA

- `npm test`: PASS completo.
- `npm run build`: PASS, `web = dist = Android`, 197 archivos.
- Gate legal: PASS.
- Test específico Pilot Final: 28/28 PASS.
- Android preflight: 4/5; el único pendiente es `android/keystore.properties`, que debe existir únicamente en el entorno local de firma.

## Importante

Este paquete queda preparado como candidato final de piloto. No se declara producción definitiva: siguen pendientes la firma Android local, la validación manual autenticada en dispositivos reales y el cierre global de los advisors históricos de Supabase antes de una salida general a producción.
