# PROMPT MAESTRO DE CONTINUIDAD · KOMBAX RC13 BUILD 20071

Trabaja exclusivamente desde `KOMBAX_Urban_Warriors_RC13_build_20071_SECURITY_PRIVACY_HARDENING` como candidata local. No regreses a builds anteriores salvo para auditoría comparativa.

## Estado ya realizado
- Supabase migraciones 119–127 aplicadas.
- Owner MFA por OTP; password-only revocado.
- Privacidad/eliminación Owner-only + Edge executor.
- Push Mi club obligatorio y privacidad financiera.
- Menores Social con consentimiento adulto + safety reminder + revocación; chat <18 bloqueado.
- Denuncia de mensajes con evidencia individual.
- Child Safety rules 1.4.
- Android WebView/deep-link/permissions hardening.
- Runtime fuente canonical `https://kombax.es`.
- `/privacy`, `/child-safety`, `/delete-account` preparados.
- Release legal gate activo.
- Regresión completa y build: PASS; 71 archivos `web = dist = Android`.

## NO hacer todavía
- NO push a GitHub.
- NO Netlify deploy.
- NO incluir JKS, `keystore.properties`, service-role keys, SMTP secrets ni credenciales de backup.

## Bloqueos antes de GO PILOTO
1. Completar datos legales y contacto Child Safety; `npm run release:legal-gate` debe pasar.
2. Validar email real de registro/recovery/OTP Owner.
3. Ejecutar backup DB+Storage y restore drill aislado.
4. Android Studio: firma APK/AAB + QA real.
5. Repetir QA final.
6. Hacer GitHub Private; después push autorizado y Netlify.

## Regla de rigor
Nunca marcar PASS por existencia de código. Exigir evidencia ejecutada. Clasificar cada control como PASS / FAIL / BLOCKED / REQUIERE USUARIO.
