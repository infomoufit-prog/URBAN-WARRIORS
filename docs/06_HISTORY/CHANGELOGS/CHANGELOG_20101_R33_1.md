# KOMBAX 20.101 R33.1 · Federation UX All Profiles

Base: `KOMBAX_20101_R33_FEDERATION_LICENSES_ADMIN`.

## Corrección principal
R33 ya contenía el dominio federativo, pero parte de sus pantallas no quedaban alcanzables desde la navegación real. R33.1 cierra esa integración UX sin ampliar permisos backend.

## Mi Club
- Nueva entrada lateral **Federaciones y licencias** para Dirección, Coordinación y Secretaría.
- Nueva entrada **Mis licencias** en Mi Cuenta para todos los roles/miembros autenticados.
- La administración del Club sigue usando el backend R33 y mantiene privadas las relaciones con múltiples Federaciones.

## Mi Federación
- Módulos visibles: Administración federativa, Mis federados, Licencias, Clubes relacionados y Equipo de Federación.
- Cada tarjeta navega al bloque correspondiente del workspace federativo.
- Añadida herramienta separada **Mis licencias personales** de la cuenta; no concede permisos a la Federación.

## Mi Competidor
- **Mis licencias** queda visible de forma estable y consulta únicamente las licencias vinculadas a esa identidad/cuenta conforme al backend.

## Mi actividad / Profesional
- **Mis licencias** propias visible.
- **Licencias autorizadas** solo se muestra con capability efectiva `professional.licenses.read_authorized`.

## Mi Marca
- No obtiene administración federativa.
- Puede consultar **Mis licencias personales** como herramienta de cuenta, separada de la Marca.

## Mi perfil / Espectador
- No obtiene administración federativa.
- Puede consultar **Mis licencias personales** como herramienta de cuenta.

## Miembro / Alumno / Familia / resto de roles Club
- **Mis licencias** aparece en Mi Cuenta.
- No se les añade la administración federativa del Club salvo los roles autorizados anteriores.

## Backend
- Migración 210 actualiza la matriz de módulos de `app_kombax_managed_profile_hub_v197` a R33.1.
- No se crean tablas nuevas ni se modifican las fronteras RLS de R33.
- El RPC continúa sin EXECUTE para `anon` y con EXECUTE para `authenticated`, con comprobaciones internas de sujeto gestionado.

## PWA/Android assets
- Cache web: `20101r331`.
- Cache media: `media-r331`.
- Paridad web/dist/Android verificada tras build.
