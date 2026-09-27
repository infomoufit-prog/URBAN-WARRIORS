# R104.1 — manifiesto acumulativo congelable

Base: R104/20156, sin reconstrucción de versiones anteriores.

Alcance de este incremento:

1. Verificador de backups con reintentos acotados (`supabase/functions/backup-verify-20077/index.ts`), desplegado en el proyecto Supabase piloto como versión 9.
2. Referencias de caché actualizadas en la página de eliminación de cuenta y sincronizadas en `web`, `dist` y `android/app/src/main/assets/www`.
3. Informe del gate técnico en `docs/releases/R104_1_PILOT_TECHNICAL_GATE.md`.

Las migraciones y el logo público canónico de R104 permanecen incluidos. El paquete no contiene credenciales, keystores ni archivos locales de configuración de firma. La ausencia de esos archivos requiere configuración privada antes de compilar un artefacto Android firmado.

Estado certificado: **NO-GO técnico** hasta completar MFA del propietario, restauración aislada y externa, controles de operación, alta y ensayo de entidades piloto, y pruebas de autorización y flujos reales. GitHub, Netlify y Google Play los ejecutará el propietario por separado.
