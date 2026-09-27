# KOMBAX R104.1 — cierre técnico previo al piloto

Fecha de comprobación: 27 de septiembre de 2026. Base acumulativa: R104/20156. Proyecto Supabase: `poggsobhtutbuagjiydc` (`eu-west-1`). GitHub, Netlify y Google Play quedan fuera de esta comprobación por instrucción del propietario.

## Correcciones aplicadas

- `backup-verify-20077` versión 9: hasta tres intentos acotados cuando Storage devuelve un error transitorio al descargar un artefacto. La comprobación SHA-256 sigue siendo obligatoria y una discordancia de hash no se ignora.
- `web/delete-account.html`: las referencias de caché de los tres scripts pasan de 20154 a 20156. `node scripts/build.mjs` volvió a copiar los 615 archivos a `dist` y Android.

## Evidencia de recuperación

La copia `20077-2026-09-27T07-59-52-702Z` contiene 3 archivos de base de datos y 99 objetos de Storage, 84.186.880 bytes en total. Un primer intento de verificación devolvió 8 errores transitorios de descarga; un segundo intento confirmó 102/102 artefactos. Tras desplegar el verificador versión 9, una nueva ejecución confirmó otra vez 102/102, 0 fallos. Los tokens de capacidad temporales usados en la prueba fueron desactivados.

Esta copia está en un bucket privado del **mismo proyecto** Supabase. Por ello, verifica integridad de artefactos, pero no acredita recuperación ante pérdida del proyecto. No se hizo restauración en un entorno aislado. `backup_export` y `restore_drill` permanecen sin atestación en el gate oficial; no se alteraron sus valores.

## Pruebas locales

Pasaron `test-kombax-20084-security-go-live`, `test-kombax-20070-pilot-readiness`, `test-kombax-20077-backup-ops`, `test-kombax-verified-competitor-r102`, `release-legal-gate` y `node scripts/build.mjs`. Son pruebas de código y empaquetado; no certifican sesiones reales, concurrencia ni restauración.

## Bloqueos técnicos comprobados

1. **Owner MFA:** 0 factores verificados; el control `owner_mfa` sigue en falso. El propietario debe inscribir TOTP y comprobar AAL2 antes de exigirlo globalmente, para evitar bloquear la administración.
2. **Recuperación:** falta una copia fuera del proyecto y una restauración aislada con RPO/RTO medidos. La copia de hoy no cierra este requisito.
3. **Controles de operación:** los siete controles de `kombax_pilot_readiness_v117` siguen en falso. No se debe marcar SMTP, responsable legal, monitorización o runbook como verificados por la mera existencia de código/documentos.
4. **Ensayo con datos piloto:** `pilot_entities_r97=0`, `ai_wallets_r97=0`, `ai_usage_runs_r103=0`. Faltan cuatro clubes autorizados, la muestra de competidores y pruebas reales de Assist/Migrations y saldo compartido.
5. **Aislamiento y flujos:** la auditoría anterior cubrió rutas RLS/RPC dirigidas para dos clubes, pero aún faltan cuatro sesiones Auth, pruebas HTTP con IDs ajenos, menores, invitaciones y cargas de archivos, además de recuperación de cuenta y ensayo concurrente.
6. **Contraseñas filtradas:** el advisor de Supabase sigue avisando. La [documentación oficial](https://supabase.com/docs/guides/auth/password-security) limita esta protección a Pro o superior; la organización consultada está en Free. No se cambió el plan ni se generó un cargo.

## PILOT RELEASE VERDICT

**NO-GO técnico al 27/09/2026.** No hay P0 demostrado en las rutas probadas, pero no existe evidencia suficiente de recuperación, MFA, aislamiento de cuatro clubes ni funcionamiento real de créditos IA. La publicación en Netlify y la app de Google Play son pasos posteriores y no sustituyen estos controles. Repetir el gate tras cerrar los seis puntos anteriores con resultados registrados.
