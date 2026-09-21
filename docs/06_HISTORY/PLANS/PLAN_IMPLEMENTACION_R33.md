# PLAN IMPLEMENTACIÓN R33 — FEDERACIONES · LICENCIAS · FEDERADOS · DOCUMENTACIÓN

## Base
- Fuente única: KOMBAX_20101_R32_PROFILE_MATRIX_PILOT_RC.
- No se modifican applicationId/versionCode sin autorización.
- No se hace push a GitHub ni publicación Play. Netlify solo se validará/desplegará si el usuario lo autoriza expresamente.

## Alcance
1. Dominio transversal de licencias federativas reutilizable por Club, Federación, Competidor y Profesional autorizado.
2. Relaciones Club↔Federación multi-federación con privacidad cross-federation estricta.
3. Mi Federación: clubes relacionados, federados, licencias, revisión/validación y documentación.
4. Mi Club: Federaciones y Licencias, sin hacer pública automáticamente la afiliación.
5. Mi Competidor: Mis Licencias.
6. Profesional/Manager: lectura o gestión solo por relación/delegación/compartición explícita.
7. Equipo de Federación: Presidencia, Secretaría, Tesorería, Coordinación, Junta Directiva y Colaborador, con invitación/aceptación/revocación y capabilities separadas.
8. Storage privado para PDF/JPG/JPEG/PNG y acceso autorizado, sin URLs públicas permanentes.
9. Notificaciones reutilizando el sistema global.
10. Auditoría, RLS, RPC, GRANTs y pruebas cross-tenant.

## Fuera de alcance
- Pasarela de pago de licencias.
- Fiscalidad/facturación federativa.
- Historias clínicas o datos de salud.
- Competencia pública entre federaciones.
- Hacer visibles automáticamente las federaciones de un club.
- Planes Pro finales/precios.

## Riesgos
- Filtración cross-federation.
- Escalada de permisos por roles de equipo.
- Duplicidad con documentos de socios existentes.
- Uso indebido de URLs de Storage.
- Regresión en Club, Events, Finanzas, Social, Showcase o Android.

## Estrategia de implementación
- Reutilizar perfiles directos y capability registry R28–R32.
- Añadir tablas R33 independientes de las tablas privadas de Club.
- RPCs SECURITY DEFINER con search_path fijo y sin EXECUTE para anon.
- RLS real; no confiar en filtros frontend.
- Extender invite-email para equipo federativo sin romper invitaciones Club.
- Frontend por repositorios/RPCs, no DML directo.

## QA obligatorio
- Federación A/B + Club X afiliado a ambas.
- A no descubre B ni licencias/documentos B.
- B no descubre A.
- Competidor solo ve sus licencias.
- Manager sin delegación: denegado; aceptado: alcance mínimo; revocado: denegado inmediato.
- Secretaría de Federación puede tramitar licencias y no obtiene Tesorería.
- Revocación de equipo inmediata.
- npm test, build, paridad web=dist=Android assets, smoke local y preflight Android.

## Cierre
R33 se considera candidata a piloto cuando backend real, tests, build, paridad, advisors y documentación estén cerrados. APK/AAB signed requiere la clave local del usuario y prueba real de Android.
