# KOMBAX_20178_R120_FIX20 — acumulativo completo

Incluye FIX19, integración oficial Meta/Instagram preparada sobre Supabase Edge Functions y antigüedad/cuotas/pagos históricos. No es un parche. FIX19 se conserva intacto.

Lee docs/qa/AUDITORIA_META_INSTAGRAM_FIX20.md y docs/qa/ANTIGUEDAD_HISTORICO_FIX20.md antes de actualizar. Las dos migraciones y cuatro funciones nuevas NO están desplegadas. No hay secretos Meta reales. Instagram permanece desactivado hasta completar su activación y ensayo real.

Descarga las partes .001, .002, .003 y .004 en la misma carpeta junto a UNIR_KOMBAX_20178_FIX20.cmd. Ejecuta ese archivo: crea KOMBAX_20178_R120_FIX20.zip y comprueba SHA-256. Las partes son fragmentos binarios de un único ZIP; no se extraen individualmente.

Extrae en una carpeta nueva. Conserva tu .git, configuración local y firma Android fuera del ZIP; no reemplaces ni publiques credenciales. Instala dependencias con npm ci y usa npm run build. Actualiza GitHub y Netlify manualmente después de revisar el informe y la activación de Supabase.

No se entrega APK/AAB compilada. Los recursos Android están sincronizados. Para Google Play utiliza un código de versión nuevo; 20178 ya se utilizó anteriormente.
