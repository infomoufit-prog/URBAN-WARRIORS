# KOMBAX R42 — Cybersecurity Handoff

## Contexto
R42 es una candidata de congelación reconstruida desde R40. Solo incorpora dos cambios UI: safe viewport del explainer móvil y neutralización del watermark estructural a marca KOMBAX.

No hay cambios R40→R42 en `supabase/`, `netlify/` ni `functions/`.

## Evidencia disponible
- Regresión completa: PASS.
- Paridad de artefactos: PASS.
- Inmutabilidad de backend: PASS.
- Escaneo local de patrones de secretos: 910 archivos / 0 hallazgos.

El escaneo de secretos **no equivale** a pentest, SAST/DAST completo ni revisión criptográfica.

## Áreas prioritarias de revisión
1. **RLS / multitenancy**
   - policies por tabla y storage;
   - funciones SECURITY DEFINER;
   - search_path;
   - bypass/service-role únicamente servidor;
   - pertenencia club/federación y cambio de identidad.
2. **Autenticación y sesiones**
   - signup/invitación/OTP/reset/reautenticación;
   - expiración y revocación;
   - MFA donde aplique;
   - protección de endpoints y refresh tokens.
3. **Autorización**
   - control server-side, no solo ocultación UI;
   - IDOR/BOLA en entidades, eventos, mensajes, documentos y finanzas.
4. **Storage / multimedia / documentos**
   - MIME y límites;
   - paths no predecibles cuando corresponda;
   - URLs firmadas/privadas;
   - RLS de buckets.
5. **Datos personales**
   - minimización, retención, borrado;
   - menores/tutores;
   - logs sin datos sensibles innecesarios;
   - exportación/acceso.
6. **Infraestructura / secretos**
   - Supabase, Netlify, Resend, FCM y CI;
   - rotación y separación por entorno;
   - ausencia de service-role/browser exposure.
7. **Web/PWA/APK**
   - CSP/headers;
   - XSS/HTML injection;
   - service worker/cache de información privada;
   - deep links/rutas protegidas;
   - WebView settings.
8. **Operaciones**
   - backups y restore probado;
   - monitorización/alertas;
   - trazabilidad administrativa;
   - incident response y rollback.

## Gate vivo pendiente
Debe capturarse y revisarse el resultado actual de **Supabase Security Advisors** y cualquier advisor/performance relevante del proyecto `poggsobhtutbuagjiydc` antes del sign-off de datos reales.

Durante este cierre no se obtuvo una evidencia de advisors verificable incorporable al artefacto, por lo que se marca conscientemente como PENDIENTE.

## Resultado recomendado
- **Aprobada para revisión de ciberseguridad:** Sí.
- **Aprobada por ciberseguridad:** No evaluado todavía.
- **Uso con datos reales:** Bloqueado hasta sign-off.
