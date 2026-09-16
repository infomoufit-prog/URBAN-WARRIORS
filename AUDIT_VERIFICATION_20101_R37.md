# KOMBAX 20.101 R37 · Audit Verification

## Código
- `npm run test:20101:r37`: PASS 62/62.
- `npm test`: exit 0.
- Build: 189 archivos.
- Paridad: web 189 = dist 189 = Android assets/www 189; 0 missing, 0 extra, 0 hash differences.

## Android
- applicationId: `com.urbanwarriors.app`.
- versionCode: `20101`.
- versionName: `2.0.0-rc.13`.
- Preflight: 4/5.
- Pendiente único: `android/keystore.properties` local / JKS autorizada.
- No se generó APK/AAB firmado en este cierre.

## Supabase live
Migraciones R37 aplicadas:
- `kombax_brand_business_hub_r37`
- `kombax_brand_business_api_r37`
- `kombax_brand_business_privacy_hardening_r37`
- `kombax_brand_public_targets_r37`

Verificado:
- 6 tablas base Brand v223 con RLS y política deny directa.
- 2 tablas de opt-in Club/Event v224 con RLS y política deny directa.
- RPC privadas Brand: `anon_exec=false`, `authenticated_exec=true`.
- `app_kombax_brand_public_profile_v224`: única proyección pública Brand R37, disponible para anon/authenticated.
- Trigger `trg_kombax_brand_proposal_target_guard_v224`: activo.
- `search_path=""` en funciones privilegiadas auditadas.
- Ninguna función R37 auditada toca `kombax_weight_measurements_v216` o `kombax_competition_preparations_v216`.

## Datos live
No se creó una Marca ficticia ni campañas ficticias en producción para validar el cierre. Las tablas nuevas permanecen sin datos de demo hasta utilizar identidades reales/autorizadas de piloto.

## No realizado
- No Netlify deploy.
- No GitHub push.
- No firma APK/AAB.
