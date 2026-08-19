# RC13 Build 20039 · Implementation Report

## Objetivo
Separar la ayuda del alumno de la guía administrativa del Club y crear una experiencia breve, contextual y extensible por tipo de perfil.

## Arquitectura implementada
- `CLUB_MANUAL`: se conserva como catálogo completo para roles del Club.
- `MEMBER_MANUAL`: nuevo catálogo exclusivo del perfil Alumno/Miembro.
- `manualDefinition()`: resuelve el catálogo, textos y feature flags en tiempo de ejecución.
- `bindInteractiveManual(items, detailSubtitle)`: buscador, filtros, modal y navegación utilizan el catálogo activo.
- No se crea contenido ficticio para perfiles futuros; Competidor/Federación/Marca podrán añadir un catálogo propio sin alterar el manual del Club ni el del Miembro.

## Cobertura del manual Miembro
1. Mi inicio.
2. Horarios, sesiones y check-in.
3. Mis cuotas, pagos y recibos.
4. Comunicaciones del club.
5. Eventos y actividades.
6. Material y solicitudes.
7. Comunidad del Club.
8. KOMBAX Social (feature flag + elegibilidad).
9. KOMBAX Showcase (feature flag).
10. Mis notificaciones.
11. Mis solicitudes deportivas.
12. Mi perfil, foto y evolución.
13. Instalar KOMBAX.

## Exclusiones deliberadas
No se exponen en el manual del Miembro rutas administrativas o de equipo: gestión de alumnos, solicitudes de altas administrativas, catálogo deportivo, sesiones administrativas, asistencia de grupo, seguimiento, avisos de cobro, archivo documental administrativo, equipo, ámbitos, configuración, archivo/papelera o administración KOMBAX.

## Validación
- Regresión específica 20039: PASS.
- Suite histórica completa: se ejecuta antes del empaquetado final.
- Build determinista: `web = dist = Android`.
- Android preflight: 4/5; pendiente únicamente firma local JKS/keystore.properties.
