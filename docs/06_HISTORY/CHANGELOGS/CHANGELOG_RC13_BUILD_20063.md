# KOMBAX RC13 · Build 20063

## SOCIAL MESSAGING FINAL QA

- Eliminada la acción visible `Cerrar chat`; la X sale sin alterar el hilo.
- `Eliminar conversación` queda como acción destructiva explícita.
- Comentarios pasan a escritura inline en el contexto de la publicación.
- Contact Gate frontend aplica 10–500 caracteres.
- UX Social normalizada de `Relaciones` a `Mi red` y `Añadir a mi red`.
- Acceso `Mensajes KOMBAX` con badge independiente y navegación directa.
- Bandeja de Mensajes diferencia `Social` y `Showcase`.
- Showcase inicia conversaciones asociadas al producto; imagen, nombre y marca acompañan el hilo.
- Preparada migración Supabase 107 para separar canales y permitir un hilo Showcase por pareja+producto.
- Contratos 106/104 conservan compatibilidad con la build 20062 durante la QA móvil.
- Frontend 20063 incluye fallback de Social si 107 aún no está activo; Showcase comercial no se falsea con fallback incorrecto.
- `versionCode` Android: 20063.
- `npm test`: PASS.
- `npm run build`: PASS.
- 66 archivos web/dist/Android, hashes idénticos.
- Netlify 20063: NO desplegado.
- Migración 107 live: NO aplicada al cierre de este paquete.
- APK signed 20063: pendiente de generación local con JKS existente.
