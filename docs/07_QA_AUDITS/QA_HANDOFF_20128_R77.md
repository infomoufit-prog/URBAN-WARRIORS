# QA HANDOFF · KOMBAX R77 / build 20128

## Base

Usar exclusivamente el ZIP final R77/build 20128 como base del siguiente trabajo. No volver a R76 salvo rollback explícito.

## Smoke prioritario de piloto

1. Dirección/Coordinación → Mi Showcase → comprobar proveedor del club activo.
2. Cambiar de club → comprobar que productos/pedidos/analytics/reports cambian de tenant.
3. Explorar Showcase → confirmar catálogo público independiente.
4. Mi Showcase → validar 1:1 producto en PC, tablet y móvil.
5. Estadísticas → probar 7d, 30d, mes actual, mes anterior, trimestre, año y personalizado.
6. Generar PDF general, ventas, productos y finanzas; comprobar logo correcto y mismo periodo que pantalla.
7. Events → Analytics → Resultados → Informes.
8. Generar PDF de tickets, asistencia y resultados; comprobar organizador/cartel y resultados reales.
9. Probar estado vacío sin ventas/resultados.
10. Android firmado localmente → smoke de navegación, safe areas, PDFs y caché build 20128.

## No desplegado

GitHub, Netlify, Google Play y release firmada permanecen sin desplegar.

## Pendiente conocido

`android/keystore.properties` debe existir únicamente en el entorno local de firma. No incorporarlo al ZIP ni al repositorio.
