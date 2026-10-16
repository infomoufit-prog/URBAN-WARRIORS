# KOMBAX R280 acumulativo · Reparación de compilación y agentes

Este paquete completo conserva R279. La interfaz web es idéntica a R279: no añade cambios visuales ni nuevas pantallas.

Corrige el bloqueo `source freshness web/js/modules/dashboard-catalog.js`: las huellas de fuentes ahora normalizan exclusivamente CRLF a LF. El mismo código pasa en ambos formatos y los cambios reales siguen siendo rechazados. No se ha desactivado el test.

Las mejoras de interpretación y lenguaje de Ayuda, Assist y Migrations ya están desplegadas en Supabase. No necesitan otro frontend para activarse.

Para reintentar el despliegue que falló:

1. Descarga las cuatro partes R280 y `REUNIFICAR_R280_DESCARGAS.cmd` en una misma carpeta, sin descomprimirlas.
2. Ejecuta el reunificador. Generará `KOMBAX_R280_BACKEND_Y_NETLIFY_ACUMULATIVO.zip` y verificará su SHA-256.
3. Conserva una copia del repositorio y su carpeta `.git`; actualiza el contenido con este acumulativo completo, incluidos `scripts` y `supabase/functions/_shared`.
4. Haz tú la actualización de GitHub y el reintento de Netlify. Se mantiene `npm run release:build` y la carpeta publicada `dist`.

No se ha hecho commit, push, merge, PR ni despliegue Netlify. No cambies los secrets ni vuelvas a aplicar la migración R278 ya aplicada.

Resultado de la comprobación completa: 134 grupos correctos, tres incidencias de traducción heredadas y cero fallos nuevos; compatibilidad y recursos Android sincronizados. No se incluye una APK/AAB nueva compilada.

Más detalles: `docs/ENTREGA_FINAL_R280.md` y `docs/VALIDACION_R280.log`.
