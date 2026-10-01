# KOMBAX R112 · build 20165 · QA de identidad pública gratuita

## Alcance
- Identidad pública gratuita separada de suscripción.
- Verificación separada de pago.
- Entitlements de suscripción conservan el gate verificación + servicio activo.
- Badge institucional Marca/Federación conserva verificación + pago confirmado.
- Social directo soporta Competidor, Marca, Federación, Profesional y Media sin exigir plan.
- Lectura pública del perfil/álbum y multimedia básica del perfil verificado no requieren suscripción.
- Fotos/vídeos del álbum siguen sujetos a `app_kombax_media_guard_v043` y a los límites del plan; R112 no concede álbum premium gratis.
- Showcase / Checkout / Stripe / Ticketing no se modifican.

## Pruebas ejecutadas
- `node scripts/test-kombax-r112-free-public-identity.mjs` → 12/12 PASS.
- `node scripts/test-kombax-r112-free-identity-visibility.mjs` → 10/10 PASS.
- `node scripts/test-kombax-account-profile-policy-r100.mjs` → 15 escenarios PASS.
- `npm run test:20162:r109` → 25/25 PASS.
- `node scripts/test-kombax-verified-competitor-r102.mjs` → PASS.
- `node scripts/test-kombax-20165-r112-free-public-identity.mjs` → 8/8 PASS.
- `npm run release:build` → 54 PASS, 7 P2 conocidos, 0 fallos nuevos; `web = dist = Android`.
- `node scripts/android-release-preflight.mjs` → 7/8; pendiente únicamente firma local.

## Validación live
- Migración `kombax_free_public_identity_capabilities_r112` aplicada en el Supabase activo.
- Readback: `reconcile`, `social_sync`, continuidad Competidor, álbum y media ya no dependen de `app_kombax_perfil_servicio_activo_v071`.
- `app_kombax_badge_tipo_v069` y `app_kombax_social_badge_guard_v069` conservan el check de pago confirmado para Marca/Federación.
- En el momento de la auditoría no existían perfiles Marca/Media/Profesional verificados sin servicio sobre los que observar un backfill real; la validación de esa rama se apoya en definición de funciones + QA estático y deberá incluirse en E2E de piloto cuando exista una cuenta de prueba de ese tipo.

## Estado
PASS para coherencia identidad/verificación/plan. La generación final de APK/AAB firmados y aceptación en Google Play continúan como validación externa porque la clave de firma local no está disponible en este entorno.
