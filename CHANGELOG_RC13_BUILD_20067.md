# KOMBAX 2.0 RC13 · build 20067

## Integración final Owner password-only

- Mantiene todas las correcciones funcionales de la rama previa 20066.
- Integra el acceso de Administración global Owner mediante correo autorizado + contraseña.
- Elimina Email OTP únicamente del flujo Owner; no altera registro ni recuperación de contraseña.
- Mantiene challenge temporal v108, validación de contraseña reciente y sesión administrativa ligada a la sesión Auth mediante v110.
- Mantiene cierre de administración y timeout de inactividad de 15 minutos.
- Versionado sincronizado a 20067 en Web/PWA y Android.

## Preparación de entrega

- La prueba específica 20067 queda incorporada a `npm test`.
- Se incluyen migración/rollback/verificación v110 como fuente reproducible; Supabase LIVE ya dispone de v110 y no requiere reaplicación para este deploy.
- `npm run build`: PASS.
- `web`, `dist` y assets Android sincronizados.
- Firma Android deliberadamente externa: usar el JKS histórico local.
