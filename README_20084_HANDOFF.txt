KOMBAX RC13 build 20084 · FULL SECURITY GO-LIVE / PILOT CANDIDATE

ESTE ZIP ES COMPLETO, NO ES UN PATCH.

Base real utilizada:
- KOMBAX_RC13_build_20077_PILOT_READINESS_CANDIDATE.zip
- SHA-256 base: 0e37ca1c589f4235f0ac7a930600f92ef49b0a3550d93d6b99a9d62bd1a08f9b

Integrado sobre esa base:
- 20078 Public Product Overview.
- 20079 Finance Premium Foundation.
- 20080 Dashboard + cargos manuales + automatizaciones UI/Shadow.
- 20081 informes financieros PDF/snapshots/versionado.
- 20082 QA financiero + Shadow Gate.
- 20083 aislamiento workspace/identidades/chat + Finance Final Pilot Gate.
- 20084 Security Go-Live + MFA TOTP/AAL2 Owner + Pilot Security Gate.

Incluye físicamente:
- web/ completo;
- dist/ generado desde web;
- android/ completo con versionCode 20084 y hardening aplicado;
- Supabase histórico + migraciones 143..149;
- Edge Functions, incluyendo finance-recurring y finance-report;
- scripts históricos + pruebas 20078..20084;
- netlify.toml ya fusionado con hardening 20084;
- documentación de QA, seguridad, incidentes, threat model y activación piloto.

Uso previsto:
1. Descomprimir este ZIP como proyecto nuevo.
2. Abrir la carpeta en GitHub Desktop y publicar los cambios que tú decidas.
3. Ejecutar npm test / npm run release:build localmente si quieres repetir la certificación.
4. Hacer el despliegue web desde tu flujo habitual.
5. Abrir android/ en Android Studio.
6. Mantener el JKS y android/keystore.properties exclusivamente en tu PC.
7. Generar APK/AAB signed con versionCode 20084.
8. Subir el AAB al track tester de Google Play.
9. Ejecutar QA final de dos clubes y ~20 usuarios.

IMPORTANTE DE BACKEND:
- Las migraciones nuevas son 143 -> 149 y deben aplicarse en ese orden antes de probar las funciones nuevas contra el backend real.
- Los gates Finance/Shadow/Security permanecen cerrados por defecto.
- No se activa recurrencia real automáticamente con esta entrega.
- No se ha hecho deploy desde este trabajo.

FIRMA ANDROID:
- Firebase está incluido/configurado en el proyecto completo.
- El keystore y sus contraseñas NO se incluyen por seguridad.
- El preflight de esta entrega queda 4/5 hasta que tu configuración local de firma esté presente.
