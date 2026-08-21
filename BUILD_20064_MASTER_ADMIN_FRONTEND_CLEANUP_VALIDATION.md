# Validación de build · KOMBAX RC13 20064

## Estado de código

- Base: 20063 SOCIAL MESSAGING FINAL QA.
- Build web: 20064.
- Android versionCode: 20064.
- Android versionName: 2.0.0-rc.13.
- applicationId: com.urbanwarriors.app.
- Service Worker cache epoch: 20064.

## Validaciones ejecutadas

- `npm test`: PASS después de adaptar tests históricos que exigían el antiguo acceso técnico dentro del club.
- `npm run build`: PASS.
- Build output: `67 archivos · web = dist = Android`.
- Test específico `test-kombax-20064-master-admin-cleanup.mjs`: PASS.
- Android release preflight: 4/5.
  - Identidad: OK.
  - versionCode: OK.
  - assets/www: OK.
  - Firebase: OK.
  - firma local: PENDIENTE porque el paquete no contiene `keystore.properties`/JKS.

## Supabase live · preflight 108

Consulta de solo lectura realizada contra el proyecto conectado:

- `kombax_platform_admins`: presente.
- `perfiles`: presente.
- helper 055: presente.
- context 055: presente.
- migration 108: todavía ausente.
- `gen_random_uuid`: disponible.
- administradores globales activos: 1.

Los privilegios actuales de los helpers 055 también se comprobaron antes de diseñar el rollback.

## Cambios implementados

- acceso maestro móvil oculto por 8 taps/5 s;
- `/admin` PWA privada;
- password + Email OTP;
- challenge 5 min;
- sesión maestra 30 min;
- cierre por inactividad 15 min;
- consola separada del club;
- eliminación de admin/diagnóstico/certificación del routing ordinario;
- sanitización transversal de errores;
- limpieza de etiquetas internas de Gateway/Profesional;
- barra móvil de cuatro columnas equilibradas;
- migración 108 + preflight + verify + rollback.

## Cambios deliberadamente NO ejecutados

- No se desplegó 20064 en Netlify.
- No se aplicó migración 108 a Supabase live.
- No se modificó la plantilla Email OTP del proyecto desde este paquete.
- No se creó un nuevo JKS.
- No se generó una APK signed en este entorno por ausencia intencionada de las credenciales de firma.

## Próxima validación real

1. configurar plantilla OTP y expiración;
2. aplicar 107 si sigue pendiente;
3. preflight 108;
4. aplicar 108;
5. verify 108 + Advisors;
6. Android Studio -> Generate Signed APK con JKS existente;
7. instalar en móvil;
8. ejecutar QA admin + frontend técnico + regresión Social/Showcase;
9. solo con aprobación, congelar y desplegar.
