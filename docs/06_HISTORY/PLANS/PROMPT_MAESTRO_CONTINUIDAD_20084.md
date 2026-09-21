# PROMPT MAESTRO · CONTINUIDAD KOMBAX RC13 build 20084

Trabajamos desde **KOMBAX RC13 build 20084 FULL SECURITY GO-LIVE / PILOT CANDIDATE**, reconstruido sobre el último desplegado real 20077 e integrando 20078→20084.

Estado:
- Proyecto FULL: web + dist + Android + Supabase + scripts + docs.
- Android versionCode: 20084.
- Finance Premium 2.0 integrado: 143→148.
- Security Go-Live: migración 149.
- Aislamiento de club/identidad/chat 20083 integrado.
- MFA TOTP/AAL2 Owner integrado.
- Gates Finance/Shadow/Security cerrados por defecto.
- Firebase Android presente.
- Keystore/contraseñas NO incluidos; se configuran localmente.

Siguiente fase:
1. GitHub Desktop / último deploy web.
2. Aplicar migraciones 143→149 y Edge Functions en backend de QA/piloto.
3. Crear APK/AAB signed 20084 en Android Studio.
4. Google Play tester.
5. QA final con 2 clubes y ~20 usuarios.
6. Activar Leaked Password Protection y MFA Owner.
7. Validar aislamiento multiclub, permisos, Storage, chats, Finanzas y modo soporte.
8. Solo con evidencias reales, declarar PILOT SECURITY READY y abrir piloto.

Regla de entregables: futuras builds deben entregarse como ZIP FULL por defecto, salvo petición expresa de patch.
