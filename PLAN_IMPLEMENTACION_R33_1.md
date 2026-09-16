# PLAN IMPLEMENTACIÓN R33.1 — INTEGRACIÓN UX FEDERATIVA EN TODOS LOS PERFILES

## Base
- Fuente única: `KOMBAX_20101_R33_FEDERATION_LICENSES_ADMIN`.
- No se cambia `applicationId` ni `versionCode`.
- No se publica en GitHub, Netlify ni Google Play en esta fase de corrección.
- Se preserva el backend R33, RLS, privacidad cross-federation y equipo federativo.

## Problema observado
La R33 contiene backend, repositorios y pantallas de licencias, pero la navegación de Mi Club no expone una entrada directa y el hub de perfiles directos sigue recibiendo del RPC v197 la matriz de módulos R29, por lo que varias funciones R33 pueden quedar invisibles para el usuario.

## Objetivo
Hacer visible y alcanzable el dominio federativo desde todas las identidades, sin convertir perfiles no federativos en administradores y manteniendo mínimo privilegio.

## UX por identidad
1. **Mi Club**
   - Entrada lateral `Federaciones y licencias` para Dirección, Coordinación y Secretaría, que son los roles autorizados por backend.
   - Entrada común `Mis licencias` para cualquier usuario autenticado del Club, mostrando únicamente sus propias licencias.
2. **Mi Federación**
   - Entradas visibles a Administración federativa, Mis federados, Licencias, Clubes relacionados y Equipo de Federación.
   - `Mis licencias personales` como herramienta de cuenta separada de los datos institucionales.
3. **Mi Competidor**
   - `Mis licencias` visible de forma estable, independiente de que el catálogo de módulos R29 esté desactualizado.
4. **Mi actividad / Profesional**
   - `Mis licencias personales`.
   - `Licencias autorizadas` solo cuando exista capability `professional.licenses.read_authorized`.
5. **Mi Marca**
   - No obtiene administración federativa.
   - Puede abrir `Mis licencias personales` como herramienta de la cuenta, dejando claro que no pertenece a la Marca.
6. **Mi perfil / Espectador**
   - No obtiene administración federativa.
   - Puede abrir `Mis licencias personales` como herramienta de cuenta.
7. **Miembro / Alumno / Familia**
   - Entrada `Mis licencias` dentro de Mi Cuenta. El RPC `app_kombax_self_licenses_v200(NULL)` limita el resultado a licencias vinculadas a `auth.uid()` o a sus registros de socio.

## Backend
- Actualizar `app_kombax_managed_profile_hub_v197` únicamente para que su matriz de módulos refleje R33.1.
- No ampliar permisos de lectura/escritura.
- No tocar RLS del dominio R33.
- Añadir migración local trazable 210 y aplicarla al Supabase principal.

## Riesgos
- Mostrar controles de Federación a perfiles sin autoridad.
- Confundir una licencia personal con una licencia perteneciente a una Marca/Federación.
- Regresión de navegación móvil de Mi Club.
- Duplicar tarjetas en hubs de perfiles.

## Mitigación
- Administración federativa solo para `federacion`.
- Licencias autorizadas solo si capability efectiva.
- `Mis licencias personales` se etiqueta explícitamente como herramienta de cuenta fuera de perfiles personales.
- Deduplicación de módulos frontend.
- QA estático + suite completa + build/paridad.

## Criterios de cierre
- Mi Club muestra `Federaciones y licencias` a Dirección/Coordinación/Secretaría.
- Todos los usuarios autenticados pueden alcanzar `Mis licencias` personales sin ampliar acceso.
- Mi Federación muestra sus cinco accesos R33.
- Competidor y Profesional muestran sus accesos correspondientes.
- Marca/Espectador no adquieren administración federativa.
- Backend v197 devuelve matriz R33.1.
- Tests R33 + R33.1 + regresión completa PASS.
- Build web/dist/Android con paridad y cache R33.1.
