# RC13 build 20025 · informe de implementación

## Alcance cerrado

KOMBAX Showcase informativo y preparación reproducible de ensayos multiclub sobre el checkpoint 20024. Mantiene `applicationId com.urbanwarriors.app`, `versionName 2.0.0-rc.13` y aumenta `versionCode` a 20025.

## KOMBAX Showcase implementado

- Modelo global de marcas, gestores, categorías y fichas informativas.
- Perfiles de marca directos desacoplados: una marca también puede ser creada y asignada por moderación global antes de habilitar el alta directa.
- Permiso de gestión por tabla de gestores o entitlement `showcase.publish` de un perfil marca activo y verificado.
- Búsqueda, categorías y cursor `(publicado_en,id)` con máximo de 24 resultados.
- Campos informativos: descripción, imagen/galería HTTPS, precio orientativo opcional, web, contacto y dónde encontrar.
- Estados de marca y ficha separados; publicar, archivar, suspender o cerrar no borra el historial.
- Seis fichas DEMO locales, inequívocamente ficticias, sin persistencia ni enlaces externos.
- UI KOMBAX rojo/negro/blanco responsive y panel de gestión para gestores autorizados.

## Exclusiones de dominio

- No existen carrito, checkout, pagos, pedidos, stock, envíos, devoluciones, comisiones ni marketplace.
- KOMBAX no cobra, confirma, entrega ni resuelve operaciones relacionadas con los elementos mostrados.
- Un precio es opcional y se etiqueta como orientativo.
- Los enlaces externos deben usar HTTPS y no se generan destinos ficticios.

## Preparación para 10 / 50 / 100 clubes

- Generador con valores admitidos cerrados a 10, 50 y 100.
- SQL protegido por `app.kombax_load_fixture_enabled=on` y advertencias de uso exclusivo local/QA.
- Por club: 3 disciplinas, 4 grupos, 40 socios, 112 sesiones, 1.120 asistencias, 20 notificaciones y 240 cuotas.
- K6 parametrizable con 10/35/70 usuarios virtuales, percentiles separados y umbral de error inferior al 1 %.
- Runbook para medir base, conexiones, recursos, `pg_stat_statements`, índices, RLS cruzada y recuperación.
- No se crean `auth.users`, UGC ni medios sintéticos sin identidades QA válidas.

## Evidencia local de cierre

- Test específico 20025: PASS.
- Tests 20024, arquitectura y responsive: PASS.
- Sintaxis JS, JSON y llaves CSS: PASS.
- Fixtures 10/50/100 generados con hashes diferentes y contenido determinista.
- Suite estática completa: 35 scripts, exit code 0.
- `scripts/build.mjs`: 60 archivos, hashes idénticos entre `web`, `dist` y Android.
- `git diff --check`: sin errores.

## Estados que no deben confundirse con validación real

- Migración 042 en Supabase real: **NO EJECUTADO**.
- Prueba SQL transaccional 042: **PENDIENTE DE ENTORNO**.
- Fixtures cargados en una base QA: **NO EJECUTADO**.
- K6 10/50/100, recursos y consultas lentas: **NO EJECUTADO**.
- Capacidad para 100 clubes: **NO CERTIFICADA**.
- Validación visual/manual: **PENDIENTE**.
- Gradle, firma JKS, APK/AAB e instalación física: **PENDIENTE**.
- Netlify: **NO DESPLEGADO**.

## Orden propuesto

Tras autorización: preflight 042 → migración 042 → verificación/prueba 042 → entorno QA aislado → carga 10 → K6 10 → revisión → 50 → revisión → 100 → informe de capacidad. No aplicar fixtures en producción.
