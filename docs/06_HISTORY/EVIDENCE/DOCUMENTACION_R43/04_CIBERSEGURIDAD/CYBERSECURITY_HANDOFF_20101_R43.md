# KOMBAX R43 — Handoff de ciberseguridad

## Superficie modificada
- Navegación/visibilidad de Assist y Migrations.
- Banner de migración en perfiles gestionados.
- RPC de reserva de turno Assist.
- RPC de registro de archivo de Migration.
- Función interna de autorización organizativa.

## Controles introducidos
- Autorización backend independiente de la UI.
- Denegación por defecto para tenant refs desconocidos.
- Federación limitada a perfil directo activo de tipo federacion y propietario.
- Club limitado a membresía activa + rol organizativo permitido.
- El guard se ejecuta antes de la reserva de consumo/allowance.
- RPC sigue requiriendo usuario autenticado según el SQL versionado.

## Revisiones requeridas
- Privilegios efectivos de funciones SECURITY DEFINER.
- `search_path=''` y referencias fully-qualified.
- Posibles escaladas por alteración de rol/membresía.
- Aislamiento de tenant refs y ticket ownership.
- Storage paths y MIME/size restrictions de Migration.
- Rate limiting, abuse prevention y trazabilidad de costes OpenAI.
- Security/Performance Advisors de Supabase.

## Estado de evidencia
Escaneo local runtime: 888 archivos, 0 secretos detectados. Esto NO sustituye pentest, revisión independiente ni validación del backend vivo.
