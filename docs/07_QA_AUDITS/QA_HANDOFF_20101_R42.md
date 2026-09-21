# KOMBAX R42 — QA / Work Handoff

## Base
- Base autoritativa: **R40**.
- R41: únicamente donor de dos deltas UI; no se hereda como árbol base.
- R42: reconstrucción selectiva y auditada.

## Alcance exacto a validar
1. Pantalla/explicador “¿Qué es KOMBAX?” en móvil:
   - sin overflow horizontal;
   - safe areas izquierda/derecha;
   - scroll vertical natural;
   - barra inferior/superior y orientación;
   - escritorio sin regresión.
2. Shell estructural:
   - watermark/fondo neutral KOMBAX;
   - no usar logo del club como fondo global;
   - logo/cover/tienda/perfil del club continúan mostrando identidad del tenant.

## No debe cambiar
- Social y sus audiencias/visibilidad.
- Events y sus audiencias/visibilidad.
- Relaciones / Mi red / chat.
- Federación, licencias, equipo, identidades.
- Finance y módulos de club.
- Auth, RLS, RPC, GRANT, migraciones y funciones backend.
- Navegación global.

## Gates automáticos ya superados
- Targeted R42: **24/24**.
- Full regression: **exit 0**.
- R40 inherited: **74/74**.
- Build: **exit 0**.
- Runtime parity: **189 archivos en cada runtime, 0 SHA diffs**.
- Android preflight: **PASS**.
- Backend immutability: **PASS**.
- Secret-pattern scan: **910 / 0 findings**.

## Matriz manual mínima recomendada
- Android: Chrome + APK/WebView, portrait/landscape, pantalla pequeña y moderna con cutout.
- iPhone/Safari: safe areas superior/inferior/laterales y rotación.
- Desktop: Chrome/Edge/Firefox en 1366×768 y ≥1920×1080.
- Zoom/accesibilidad: 125–200% y fuentes grandes cuando sea viable.
- Sesiones: usuario miembro, club, federación y perfiles/identidades múltiples.

## Pruebas críticas de aislamiento antes de datos reales
- Un club no accede a datos privados de otro club.
- Una federación no obtiene afiliaciones/relaciones que no deba conocer.
- Visibilidad de eventos/social respeta cada audiencia configurada.
- Cambio de identidad no conserva permisos de la identidad anterior.
- URLs/rutas directas no eluden permisos de UI/backend.
- Cargas/descargas de documentos respetan RLS/storage policies.

## Criterio de cierre PRE-QA
Cerrar únicamente cuando:
- no haya P0/P1 abiertos;
- todos los flujos de rol/tenant críticos estén aprobados;
- exista evidencia del backend vivo;
- ciberseguridad tenga el paquete de handoff;
- se autorice explícitamente la fase piloto de datos reales.
