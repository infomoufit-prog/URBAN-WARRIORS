# KOMBAX Fase 0 · QA Scorecard · R81 build 20134

| Gate | Resultado |
|---|---|
| ZIP de entrada CRC | PASS |
| SHA-256 base de entrada | PASS |
| Corrección Android `BuildConfig.DEBUG` | PASS |
| Gate Fase 0 | 11/11 PASS |
| Gate R81 | 41/41 PASS |
| R80 pagos | 26/26 PASS |
| R80 visibility hotfix | 9/9 PASS |
| Legal release gate | PASS |
| `npm test` acumulativo | PASS |
| I18N full product | 0 unresolved |
| 8 idiomas | PASS |
| Build determinista | 466 archivos |
| `web = dist` | PASS |
| `web = Android assets` | PASS |
| Android preflight | 4/5; firma local pendiente por diseño |
| Android Gradle compile en este contenedor | no alcanza compilador: red/DNS bloquea descarga de Gradle |
| iOS Swift parse | PASS |
| iOS plist/entitlements parse | PASS |
| Supabase R81 migration/RPC/tables | PASS live |
| Edge Functions de pagos | ACTIVE live |
| RLS Terminal | PASS live |
| Health | ACTIVE build 20134 |
| Secret/signing scan | PASS · 0 patrones secretos / 0 archivos privados de firma |
| Manifest SHA-256 | PASS · 4175/4175 entradas verificadas |
| ZIP final CRC | se verifica tras empaquetado |

## Criterios externos que no se falsean como PASS

- APK/AAB firmado: requiere `android/keystore.properties`/keystore local del propietario.
- Compilación Gradle completa en este contenedor: depende de acceso a `services.gradle.org`; la red del contenedor está bloqueada antes del compilador.
- Tap to Pay real: requiere móvil físico compatible y cuenta Stripe habilitada.
- iOS final: requiere Xcode/macOS, Apple Developer, entitlement Tap to Pay y provisioning.
- Publicación GitHub/Netlify: no realizada durante la auditoría de Fase 0.
