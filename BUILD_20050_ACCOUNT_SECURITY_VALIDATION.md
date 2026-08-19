# KOMBAX 20.050 · ACCOUNT SECURITY · VALIDATION

## Resultado

**PASS técnico / pendiente de validación E2E manual con una contraseña real.**

La 20.050 parte del ZIP certificado 20.049. Antes del primer cambio se ejecutó `npm test` y el baseline fue PASS.

## Funcionalidad implementada

Se añade un flujo separado de «He olvidado mi contraseña» para usuarios que ya tienen una sesión iniciada y desean cambiarla voluntariamente.

### Ubicaciones

- Alumno/Familia: **Mi perfil → Seguridad y acceso → Cambiar contraseña**.
- Equipo: **Mi perfil personal → Seguridad y acceso → Cambiar contraseña**.
- Gestor/Coordinación: acceso directo también desde **Perfil del Club → Seguridad y acceso**.
- Cuenta KOMBAX global: botón **Cambiar contraseña** junto a **Cerrar sesión**.

### Flujo

1. Contraseña actual.
2. Nueva contraseña.
3. Confirmación de nueva contraseña.
4. Validación local: actual obligatoria, nueva >= 8 caracteres, nueva distinta de actual y confirmación idéntica.
5. Reautenticación explícita mediante Supabase Auth con email de la sesión + contraseña actual.
6. Comprobación de que el `user.id` reautenticado coincide con `state.session.id`.
7. Actualización de la contraseña con la sesión recién reautenticada.
8. Revocación/cierre de sesión.
9. El usuario debe volver a iniciar sesión con la nueva contraseña.

No se usa `service_role`, no se añade Edge Function, tabla, RPC ni migración SQL.

## Pruebas

- Baseline 20.049 `npm test`: PASS.
- `node scripts/test-kombax-20050-account-security.mjs`: PASS.
- Regresión completa 20.050 `npm test`: PASS.
- `npm run build`: PASS.
- Builder: `OK build 64 archivos · web = dist = Android`.
- Comparación independiente: web 64 / dist 64 / Android 64; faltantes 0; extras 0; diferencias 0.
- SHA-256 agregado de cada árbol: `471aed62d58cfbface559bc426c77fcc2c5334b34b335adfed907b37b2e04c31`.
- Android preflight: 4/5. Único pendiente: `android/keystore.properties` y JKS locales, intencionadamente fuera del paquete.
- Escaneo de archivos sensibles: 0 JKS/keystore/.env/P12/PFX/PEM/private key.
- Escaneo de patrones: 0 `SUPABASE_SERVICE_ROLE_KEY`, 0 GitHub tokens, 0 private keys.

## Prueba que deliberadamente NO se ha realizado

No se ha cambiado la contraseña de ninguna cuenta real durante la automatización, porque la prueba correcta requiere que el propietario introduzca su contraseña actual. La validación E2E final debe hacerse desde CMD/navegador con una cuenta de prueba o con la cuenta elegida por el usuario.

## Supabase

No requiere migración nueva. La 20.050 conserva las migraciones 094, 095 y 096 ya aplicadas en fases anteriores.

## Despliegue

No se ha hecho commit/push a GitHub, deploy a Netlify, firma APK/AAB ni publicación en Google Play.
