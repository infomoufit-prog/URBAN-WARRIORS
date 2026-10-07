# KOMBAX FIX17 acumulativo

Conserva FIX16 y añade las reparaciones de foto/banner públicos. Informe: docs/qa/AUDITORIA_PERFIL_PUBLICO_FIX17.md.

Coloca las partes .zip.001 a .004 junto a UNIR_KOMBAX_20178_FIX17.cmd. Ejecuta el reunificador, comprueba la integridad y extrae en una carpeta nueva. Conserva tu .git, variables privadas, configuración local Android y firma antes de sustituir código del repositorio.

Supabase: migración 20261007065536_direct_profile_public_media_path_fix17 aplicada. No vuelvas a ejecutarla si está registrada. La prueba manual Premium de Moufit ya existe en la base; no requiere ejecutar scripts adicionales ni modifica su verificación.

Frontend: requiere tu despliegue de Netlify. En Perfil público → Gestionar → Foto y banner públicos puedes subir ambas imágenes. Las imágenes administrativas se personalizan aparte.

No se desplegó producción ni se generó APK/AAB. Recursos Android sincronizados; para Play usa un versionCode nuevo y tu firma habitual.
