# KOMBAX RC13 build 20072 · Closure validation

## Resultado actual

**CANDIDATA TÉCNICA LOCAL: PASS**  
**PUBLICACIÓN / GO REAL: NO-GO controlado**

El NO-GO restante depende principalmente de configuración externa, datos jurídicos, restore real, firma Android y deploy final; no de una regresión detectada en el código 20072.

## PASS

- Suite completa `npm test`.
- Build determinista y paridad web/dist/Android.
- Owner contraseña + OTP; password-only revocado.
- Sesión Owner privilegiada temporal; Owner sin MFA bloqueado.
- Eliminación de cuenta Owner-only + executor JWT.
- Moderador separado de privacidad, chats y documentos privados.
- Verificador mínimo privilegio; no puede borrar documentación de verificación.
- Push de Club obligatorio; privacidad de lockscreen y avisos financieros neutros.
- Menores: autorización adulta Social, revocación y chat privado <18 bloqueado.
- Denuncia de mensaje con evidencia acotada.
- Child Safety y procedimiento de escalado preparados.
- Gate legal de plataforma para cuentas nuevas y existentes.
- Términos y Privacidad semánticamente separados.
- Plantillas Auth KOMBAX preparadas.
- Aislamiento RLS multiclub probado con cuentas/roles reales y pruebas sintéticas reversibles.
- Health backend v2: HTTP 200 real, DB OK.
- `kombax.es` canónico en runtime y App Links Android.
- Escaneo runtime sin dominio antiguo ni secretos privados incrustados.
- targetSdk 36 y Android hardening previo conservados.

## Bloqueos reales antes de publicación

### REQUIERE USUARIO / legal

Siete datos únicos mantienen activo el release gate:

1. `KOMBAX_LEGAL_CONTROLLER`
2. `KOMBAX_LEGAL_TAX_ID`
3. `KOMBAX_LEGAL_ADDRESS`
4. `KOMBAX_PRIVACY_EMAIL`
5. `KOMBAX_DPO` (indicar “no designado/no aplica” solo tras decisión jurídica si procede)
6. `KOMBAX_CHILD_SAFETY_CONTACT_NAME`
7. `KOMBAX_CHILD_SAFETY_CONTACT_EMAIL`

Además, revisión jurídica final de Términos/Privacidad y encaje KOMBAX↔club.

### Auth/email E2E

- activar las plantillas 20072 en Supabase hosted;
- confirmar remitente profesional verificado;
- probar alta, recuperación y OTP Owner en buzón real;
- confirmar Site URL/Redirect URLs `kombax.es`.

### Backup / restore drill

Tooling PASS, ejecución real pendiente porque se necesita una credencial temporal de DB/Storage y un destino aislado con `pg_dump/pg_restore`. No se marca PASS sin restauración real.

### Monitoring

Endpoint health PASS. Falta monitor externo, canal de alertas y responsable primario/suplente.

### Android

Preflight 4/5. Falta `keystore.properties` local, build APK/AAB signed e instalación/prueba en dispositivo.

### Publicación

- hacer GitHub privado antes del próximo push;
- push únicamente cuando se autorice;
- deploy Netlify/kombax.es únicamente cuando se autorice y el gate legal pase;
- smoke/E2E en dominio real;
- Google Play: Data Safety, Child Safety, clasificación, ficha, pruebas y AAB.

### Supabase plan

Leaked Password Protection permanece deshabilitado porque Supabase lo ofrece en plan Pro o superior. Es una decisión de plan/producción, no una regresión de código.

## No acciones realizadas

- No push GitHub.
- No deploy frontend Netlify.
- No borrado automático de archivos candidatos a huérfanos.
- No restore ficticio.
- No firma Android ficticia.
