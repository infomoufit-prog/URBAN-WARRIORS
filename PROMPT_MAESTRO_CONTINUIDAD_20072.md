# Continuidad KOMBAX desde RC13 build 20072

Usar la build 20072 como candidata de cierre. No retroceder a 20070/20071 salvo comparación histórica.

Estado: suite/build/RLS/Owner OTP/privacidad/menores/Child Safety/gate legal/health PASS técnico. Migraciones 128 y 129 ya aplicadas en Supabase. Frontend NO desplegado aún; GitHub NO actualizado.

Pendiente prioritario, en orden:
1. completar 7 campos legales/contacto y revisión jurídica;
2. activar plantillas Auth 20072 y hacer E2E real de alta/recovery/Owner OTP;
3. ejecutar backup completo + restore drill aislado;
4. configurar monitor externo y responsables de alerta;
5. hacer GitHub privado, después push autorizado;
6. deploy autorizado a Netlify/kombax.es y QA E2E;
7. APK/AAB signed con keystore local y QA dispositivo;
8. Google Play Console y formularios finales.

Reglas: no declarar PASS sin evidencia, no exponer service_role/JKS/SMTP, mantener multiclub RLS y mínimo privilegio, push Mi club no configurable por categorías, chat personal <18 bloqueado, Social menor requiere tutor.
