# KOMBAX 20.101 R33 · Changelog

## Federación, licencias y documentación
- Nuevo dominio transversal de licencias federativas, separado de los datos privados de Club.
- Un Club puede mantener múltiples relaciones federativas privadas.
- Mi Federación incorpora federados, licencias, vencimientos, clubes relacionados y revisión administrativa.
- Mi Club incorpora Federaciones y licencias, creación/envío de expedientes y documentación.
- Mi Competidor incorpora Mis licencias e histórico por temporada.
- Profesional/Manager solo obtiene licencias expresamente compartidas o cubiertas por delegación válida.
- Documentos federativos en Storage privado con PDF/JPEG/PNG, 10 MB y URL firmada temporal.
- Compartir documento es una acción explícita: subir no comparte automáticamente.

## Equipo de Mi Federación
- Roles: Presidencia, Secretaría, Tesorería, Coordinación, Junta Directiva y Colaborador/a.
- Invitación personal por email, aceptación/rechazo desde Mi Cuenta y revocación inmediata.
- Capabilities por rol; Secretaría puede tramitar licencias sin heredar Tesorería.
- `invite-email` ampliada sin retirar los flujos históricos de Club/alumno.

## Seguridad
- Privacidad cross-federation validada en backend real.
- RLS activo en las nueve tablas R33.
- RPCs v200 autenticadas, sin EXECUTE para anon y `search_path` fijo.
- Hardening de índices FK añadido en migración 209.

## Plataforma
- Cache PWA `20101r33` / `media-r33`.
- Android conserva `com.urbanwarriors.app`, versionCode 20101 y Firebase.
- No se ha introducido pago federativo ni datos clínicos.
