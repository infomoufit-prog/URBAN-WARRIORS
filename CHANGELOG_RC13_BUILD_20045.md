# KOMBAX RC13 · build 20045

- Todos los perfiles KOMBAX Social activos pasan a ser públicos dentro de la red; no existe perfil privado de usuario.
- Avatar/logo y nombre de autor permiten abrir el perfil público desde las vistas Social relevantes.
- Publicaciones públicas por defecto (`Público · Todo KOMBAX`).
- Audiencias opcionales protegidas también en backend: `Solo mi club`, `Solo afiliados a mi federación` y, para Federación, `Solo clubes afiliados`.
- Marca permanece pública en esta fase; no se añade «solo Relaciones».
- Feed, perfil, comentarios y Guardados respetan audiencia mediante las nuevas RPC 083; rutas antiguas que podían saltarse el filtro quedan revocadas.
- Relaciones continúan privadas y fuera del perfil público.
- Portada/banner de perfil usa `cover` como excepción visual; el resto del contenido mantiene sus reglas de proporción.
- Las 4 publicaciones existentes se conservan y quedan clasificadas como públicas.
- Supabase migración 083 aplicada y validada transaccionalmente.
- Android versionCode 20045; web, dist y Android certificados idénticos tras build.
