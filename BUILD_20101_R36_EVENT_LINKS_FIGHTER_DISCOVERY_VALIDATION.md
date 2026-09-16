# Build validation · KOMBAX 20.101 R36

## QA local
- `npm run test:20101:r36`: PASS 49/49.
- `npm test`: exit 0.
- R35 histórico: PASS 39/39 tras convertir su check de caché en una comprobación compatible con versiones posteriores.
- `node scripts/build.mjs`: OK · 188 archivos.
- Paridad SHA-256: web=188, dist=188, Android assets=188, 0 diferencias.

## Android
- applicationId: `com.urbanwarriors.app`
- versionCode: `20101`
- versionName: `2.0.0-rc.13`
- Preflight: 4/5.
- Único pendiente: `android/keystore.properties` local + JKS autorizada.
- La release R36 no empaqueta JKS, keystore real, `.env` ni secretos.

## Backend live
Verificado:
- 7 tablas R36 con RLS activa.
- RPC privadas R36: `anon_exec=false`, `authenticated_exec=true`, `security_definer=true`, `search_path=""`.
- Única RPC anónima nueva: proyección pública del evento, limitada a JSON autorizado.
- Funciones Fighter Discovery / invitaciones / proyección: no referencian tablas de historial privado de peso.

## Estado de publicación
- Supabase R36: aplicado.
- Netlify: NO desplegado.
- GitHub: NO enviado.
- APK/AAB firmada: NO generada en este cierre.
