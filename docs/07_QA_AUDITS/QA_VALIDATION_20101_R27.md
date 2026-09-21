# QA · KOMBAX 20.101 R27

## IMPLEMENTADO
Frontend de contacto por correo directo a `soporte@kombax.es` en Mi perfil, Mi Club y Mi cuenta KOMBAX/Mis perfiles.

## VALIDADO
- R27 dedicado: 10/10 PASS.
- R26 preservado: 24/24 PASS.
- Regresión acumulada completa: PASS.
- Build: `OK build 172 archivos · web = dist = Android`.
- Supabase: paridad byte-for-byte contra R26 en toda la carpeta `supabase/`.
- Android preflight: 4/5; identidad, versionCode, www y Firebase OK.

## PENDIENTE
- Firma local Android: `android/keystore.properties` no está incluido, igual que en R26.
- Validación visual física en dispositivo por el usuario.

## NO MODIFICADO
Backend Supabase, permisos, autorizaciones R26, Owner/Admin General, Eventos, Finanzas, Social, Showcase, Netlify, GitHub y versionCode.
