# Continuidad KOMBAX desde RC13 build 20073

Usar la build 20073 como candidata actual. Conserva todo el hardening 20072 y añade únicamente el pulido premium de emails Auth.

Pendientes prioritarios:
1. completar 7 datos legales/contactos;
2. activar plantillas Auth 20073 en Supabase alojado;
3. ejecutar E2E real de alta, confirmación, recovery, invitación, reautenticación y OTP Owner;
4. ejecutar backup + restore drill real;
5. conectar monitoring externo;
6. firma APK/AAB en entorno local;
7. después, GitHub privado → push autorizado → Netlify → kombax.es → QA E2E → Google Play.

No retroceder a plantillas 20072 salvo comparación histórica. No subir a GitHub ni desplegar Netlify sin autorización explícita.
