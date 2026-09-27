# KOMBAX R88 · build 20141 · Deployment handoff

## Repository

Use this cumulative package as the repository source. Do not merge code from an older R81/R82 folder over it.

Recommended sequence:

1. Replace/update the repository working tree with this package.
2. Review the diff before commit, especially `supabase/migrations`, `supabase/functions`, `web`, `android`, `ios` and `netlify.toml`.
3. Push the chosen release branch.

## Netlify

`netlify.toml` is already configured with:

- build command: `npm run release:build`
- publish directory: `dist`
- Node 22

The release build executes the legal gate and cumulative test suite before copying the web build to `dist` and Android assets.

## Supabase

R83–R88 migrations listed in the live-state report have already been applied to the current KOMBAX project. Do not manually re-run an already recorded live migration. Future environments should apply the versioned migration history normally.

## Android Studio · APK/AAB

1. Open the `android/` directory in Android Studio.
2. Allow Gradle 8.11.1 / AGP 8.10.1 sync using an installed compatible JDK (JDK 17+; the existing local workflow may use JDK 21).
3. Copy `android/keystore.properties.example` to `android/keystore.properties` locally and fill it with the existing release keystore path/password/alias. Never commit this file or the JKS.
4. Confirm build identity: `versionCode 20141`, `versionName 2.0.0-rc.13-r88-prepilot`.
5. For a test APK, build the debug APK after Gradle sync.
6. For Google Play, use **Generate Signed Bundle / APK → Android App Bundle** and the same existing signing key used by the Play application.
7. Upload the signed `.aab` to the intended Google Play internal/pre-pilot track and verify versionCode 20141 before rollout.

The package includes `google-services.json`, Firebase configuration, Stripe Terminal dependencies and WebView assets. Signing credentials are intentionally not included.

## iOS

Source parity is prepared at build 20141. Production requires macOS/Xcode, Apple Developer signing, provisioning and the Tap to Pay entitlement. No `.p12`, private key or provisioning profile is included.
