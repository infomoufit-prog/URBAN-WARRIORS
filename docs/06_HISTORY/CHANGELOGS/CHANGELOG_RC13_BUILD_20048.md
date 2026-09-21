# CHANGELOG · RC13 build 20048

## PRE-FREEZE: Canonical Member Profile + Club Visual Closure

- Unifica `Mi perfil` con KOMBAX Social para Miembros.
- Retira de la navegación activa el segundo `Perfil deportivo compartido`.
- Incorpora información deportiva declarada al perfil Social canónico.
- Migra datos legacy de forma conservadora, sin sobrescribir Social.
- Mantiene `perfiles_deportivos` privado y legacy para compatibilidad.
- Comunidad del Club y directorio abren por `social_id` KOMBAX.
- Nueva RPC `app_kombax_identity_mutate_v094`.
- Nueva RPC `app_kombax_perfil_publico_v094`.
- Nueva RPC `app_kombax_club_social_directory_v095`.
- Verificada continuidad Miembro -> Competidor -> Miembro con mismo Social ID y rollback.
- Fondo global Club: negro + logo desenfocado/sutil; la portada deja de usarse como background de navegación.
- `Privacidad y condiciones` abre el centro legal, no el manual.
- Revalidado hardening 20.046, edad, privacidad y ACL.
- Reejecutados Security Advisor y Performance Advisor; optimización de rendimiento masiva aplazada.
- Build 20048 / Android versionCode 20048.
- Suite completa PASS.
- web = dist = Android (62 archivos, 0 diferencias).
- Android preflight 4/5: firma local pendiente intencionadamente y fuera del paquete.
- GitHub, Netlify, APK/AAB y Google Play no modificados.
