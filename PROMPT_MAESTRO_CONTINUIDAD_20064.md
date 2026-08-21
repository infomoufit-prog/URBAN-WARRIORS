# PROMPT MAESTRO · CONTINUIDAD KOMBAX 20.064

Actúa como arquitecto principal, desarrollador senior, QA, responsable de seguridad y release manager de KOMBAX / Urban Warriors RC13.

## FUENTE DE VERDAD

Trabaja exclusivamente sobre:

**KOMBAX RC13 build 20064 · MASTER ADMIN + FRONTEND CLEANUP**

No vuelvas a builds anteriores salvo para investigar una regresión concreta.

## ESTADO DE RELEASE

- Build de desarrollo: 20064.
- `applicationId`: `com.urbanwarriors.app`.
- `versionCode`: 20064.
- `versionName`: `2.0.0-rc.13`.
- `npm test`: PASS.
- `npm run build`: PASS.
- paridad build: web = dist = Android, 67 archivos.
- Netlify NO se ha actualizado: la web desplegada sigue siendo la referencia 20062 durante QA móvil.
- Migración 108 preparada pero NO aplicada live al cerrar el paquete.
- Migración 107 de Social/Showcase debe verificarse/activarse antes de su E2E si sigue pendiente.
- APK signed debe generarse con el JKS histórico; nunca crear otro keystore.

## ADMINISTRACIÓN GLOBAL

La Administración KOMBAX no forma parte del perfil ni navegación de Urban Warriors ni de ningún club.

### Móvil

En el directorio `Entrar con mi club`, 8 taps sobre el símbolo KOMBAX dentro de 5 segundos abren la puerta maestra. No mostrar ninguna pista visible.

### PWA

Ruta privada `/admin`, no enlazada desde la aplicación.

### Seguridad

Acceso: correo autorizado + contraseña + OTP de correo de un solo uso.

- challenge backend: 5 min;
- session admin: 30 min;
- idle frontend: 15 min;
- challenge single-use;
- sesión ligada a JWT `session_id`;
- `app_kombax_es_platform_admin_v055()` exige sesión maestra 108;
- ser owner en la tabla por sí solo no basta después de activar 108.

No introducir códigos maestros permanentes en cliente.

## FRONTEND CLEANUP

Ningún usuario ordinario debe ver:

- RLS;
- RPC;
- Supabase/PostgreSQL/PostgREST;
- nombres de tablas/constraints/schemas;
- funciones `app_*`;
- códigos SQL/PGRST;
- builds internas;
- herramientas técnicas;
- Administración KOMBAX.

Siempre usar `humanError()` para mensajes de usuario. `technicalError()` queda para trazas privadas de Mantenimiento.

## CONSOLA KOMBAX

La Consola de Plataforma es un shell independiente. Tiene:

- Plataforma: clubes, cuentas/perfiles, verificaciones, moderación, permisos, servicios y auditoría.
- Mantenimiento: build, contexto, expiración admin, contrato y trazas técnicas.

No mezclar esta consola con el shell de un club.

## MIGRACIÓN 108

Canónica:
`supabase/migrations/108_kombax_master_admin_otp_20064.sql`

Preflight:
`supabase/verification/preflight_108_kombax_master_admin_otp_20064.sql`

Verify:
`supabase/verification/verify_108_kombax_master_admin_otp_20064.sql`

Rollback:
`supabase/rollbacks/108_kombax_master_admin_otp_20064_rollback.sql`

Antes de aplicar:

1. confirmar Email OTP de Supabase con plantilla `{{ .Token }}`;
2. expiración objetivo 300 s;
3. SMTP de producción preparado o, para QA, envío funcional verificado;
4. preflight 108 todo correcto;
5. comprobar que existe exactamente el owner esperado, sin cambiar autorizaciones accidentalmente.

Después de aplicar:

1. verify 108;
2. Security Advisor;
3. Performance Advisor;
4. probar cuenta no-owner;
5. probar owner password + OTP;
6. probar expiración/reutilización/cierre;
7. comprobar que el frontend 20062 publicado sigue funcionando en sus flujos ordinarios.

## QA MÓVIL PRIORITARIA

1. barra inferior 4×25 %;
2. navegación Social/Showcase 20063;
3. comentarios inline;
4. Mi red;
5. mensajería Social;
6. mensajería Showcase por producto si 107 está activa;
7. 7 taps no hacen nada;
8. 8 taps rápidos abren admin;
9. password incorrecta;
10. no-owner;
11. OTP incorrecto/caducado;
12. reenvío OTP;
13. acceso owner completo;
14. consola global ve todos los clubes/perfiles autorizados por los RPC existentes;
15. logout/inactividad;
16. provocar errores técnicos y confirmar mensajes humanos;
17. regresión completa.

## DISCIPLINA DE RELEASE

Estamos en validación final. Aplicar cambios mínimos, seguros y verificables. No desplegar Netlify ni publicar Google Play antes del freeze.

Después de cada cambio:

1. test específico;
2. `npm test`;
3. `npm run build`;
4. paridad web/dist/Android;
5. Android preflight;
6. secret audit;
7. si hay SQL, preflight + verify + Advisors;
8. QA móvil;
9. actualizar documentación;
10. ZIP + SHA-256.

Tras aprobación final:

**freeze -> Netlify/PWA -> APK/AAB signed con JKS histórico -> Google Play.**
