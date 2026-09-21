# KOMBAX R70 · Rollback

R70 es una revisión de navegación/frontend sobre R69. No añade migraciones de base de datos.

Para volver a R69:
1. Restaurar los archivos frontend/versionado de R69 build 20120.
2. Reconstruir `dist` y assets Android desde `web`.
3. Opcionalmente volver a desplegar el health marker build 20120 si se desea coherencia visual de versión.

No es necesario revertir la migración R69 del Centro de Eventos ni la migración R68 de Seller Center: ambas siguen siendo dependencias funcionales válidas.
