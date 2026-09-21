# KOMBAX i18n · Rollback

1. No volver a una versión anterior del producto para “quitar i18n”. El ZIP final es acumulativo.
2. Para desactivar un idioma, retirarlo únicamente de `ENABLED_LOCALES` y de `LOCALE_ROLLOUT.enabled`; conservar catálogo y soporte.
3. Si una migración i18n no se despliega, el frontend conserva fallback local. No borrar columnas o tablas para revertir.
4. Migración `preferred_locale`: rollback operacional = dejar de escribir/leer la preferencia; no eliminar datos durante incidente.
5. Migración legal metadata: rollback operacional = ignorar campos nuevos; no borrar historial legal.
6. QR, ticket IDs, rutas técnicas, Stripe IDs y contenido de usuario no dependen del locale, por lo que no requieren rollback por idioma.
7. Ante regresión crítica, restaurar el ZIP completo inmediatamente anterior del pipeline y documentar la causa; nunca mezclar archivos sueltos de versiones distintas.
