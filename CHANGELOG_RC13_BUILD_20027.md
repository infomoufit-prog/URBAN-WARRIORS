# Changelog · KOMBAX / Urban Warriors RC13 build 20027

Fecha: 2026-08-17

## Añadido

- Cuenta e identidad global KOMBAX separadas del tenant.
- Perfiles directos Competidor, Marca, Federación y Profesional/Representante.
- Solicitudes y workflow de verificación.
- Documentos privados de verificación.
- Álbum KOMBAX y álbum Club: avatar/banner + 10 fotos + 3 vídeos de 15 s.
- KOMBAX Social ampliado: comentarios, una respuesta, guardados, compartir, reportes y bloqueos.
- Relaciones verificadas sin modelo de seguidores.
- Contacto estructurado por motivos y tipo de perfil.
- Showcase global Club/Marca, 15/30 fichas y galería adicional.
- Gestión Showcase de Marca sin membresía artificial de Club.
- Solicitudes trazables de eliminación de cuenta/perfil/club.
- Página pública `/delete-account` con autenticación y solicitud real.
- Denuncia de comentarios y cola/acciones de moderación UGC.
- Pruebas específicas build 20027 y evolución de tests históricos para gateways vigentes.

## Seguridad / privacidad

- Competidor y Profesional directos no pueden activar Social únicamente por estar verificados: requieren edad verificada por Club.
- Social afiliado mantiene la regla 14+ con edad verificada por Club.
- Espectador continúa muy limitado y sin contacto privado.
- Documentación de verificación permanece fuera del contenido público.
- Sin chat libre, seguidores, pagos KOMBAX ni marketplace.
- Sin JKS, `keystore.properties`, `google-services.json` real ni `.env` incrustados.

## Backend

Nuevos ciclos SQL: 043, 044, 045, 046, 047, 048, 049 y 050, cada uno acompañado por controles de despliegue/validación/rollback según corresponda.

## Android/PWA

- `versionCode`: 20027.
- `applicationId`: `com.urbanwarriors.app` sin cambios.
- `compileSdk` / `targetSdk`: 36.
- Build final: 66 archivos idénticos en `web`, `dist` y `android/app/src/main/assets/www`.

## QA local final

- `npm test`: PASS.
- `npm run build`: PASS.
- SQL 043–050 auditado estáticamente: 0 incidencias en controles estructurales ejecutados.
- Android release-preflight: 3/5; pendientes Firebase real y configuración local de firma.

## Estado

**Candidato de release / preparado para validación.** No es todavía una release de producción Google Play certificada.

## Corrección SQL post-validación · 2026-08-17

- Corregida la firma `RETURNS TABLE` de `app_kombax_album_v043`: la columna de salida `position` ahora va entre comillas dobles para evitar el error PostgreSQL `42601 syntax error at or near "position"`.
- Corregido preventivamente el mismo patrón en `app_kombax_club_album_v046`.
- No cambia la lógica, nombres de tablas, datos, permisos, RLS ni contratos funcionales; es una corrección sintáctica de las firmas SQL.
- El build Android/PWA continúa siendo 20027; cambia únicamente el paquete fuente SQL validado.
