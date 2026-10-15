# KOMBAX R271 acumulativo — identidades Social

Club, Marca, Federación y Media conservan identidades independientes. Miembro, Competidor, Profesional y Espectador de la misma persona se presentan como un perfil personal con capacidades separadas.

Los registros anteriores se conservan. No se han transferido propietarios, verificado perfiles automáticamente ni compartido Premium, servicios, Stripe o permisos entre entidades.

## Actualización
1. Guarda una copia de la carpeta actual.
2. Reunifica las cuatro partes con UNIR_KOMBAX_R271_IDENTIDADES.cmd. El archivo comprueba SHA-256 antes de confirmar.
3. Extrae el ZIP completo y actualiza manualmente tu repositorio con su contenido, conservando la carpeta .git.
4. Despliega el frontend en Netlify cuando estés listo. Estos cambios visuales todavía no están en la web publicada.
5. Las nuevas funciones de Supabase ya están aplicadas: no vuelvas a ejecutar todas las migraciones. El informe contiene sus nombres y versiones remotas. No hacer db push indiscriminado sobre las migraciones históricas.
6. Comprueba con tu cuenta la selección Persona / Club / Marca, perfil común, permisos y conversaciones. Las autorizaciones pendientes siguen pendientes.

La entrega incluye código y recursos Android sincronizados. No incluye APK/AAB nueva compilada. Google Play exige un código de versión no utilizado para la siguiente AAB.

El informe de QA distingue consultas reales, pruebas SQL aisladas y navegador con datos simulados. Las tres incidencias de traducción heredadas permanecen documentadas; no se han ocultado.

## Ampliaciones incluidas

Material y Showcase incluyen vistas compacta, grande y lista, conservando las imágenes cuadradas y la preferencia por cuenta.

La retirada del álbum Social conserva imágenes utilizadas por publicaciones. En los álbumes Club/directos se conserva prudentemente el archivo mientras el servidor no certifique que no está referenciado; retirar la entrada no garantiza liberar todo el almacenamiento. Material y Showcase mantienen sus controles existentes y el historial protegido. Véase `docs/qa/r271-identities/ELIMINACION.md`.

Migración de álbum aplicada: `social_album_shared_media_r271`, versión remota `20261014231852`. No volver a aplicarla. Las mejoras de frontend precisan tu actualización manual.

MOUFIT DEMO: corregido el estado que confundía club con persona y habilitada publicación demo mediante autorización privada separada de las plazas piloto. No se han borrado perfiles ni marcado verificación documental. Véase `docs/qa/r271-identities/MOUFIT_CONTEXTO.md`.
