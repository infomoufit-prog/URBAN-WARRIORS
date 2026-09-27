# KOMBAX iOS R81 - Tap to Pay on iPhone

Source variant for build 20144. It wraps the canonical `https://kombax.es` UI in WKWebView and exposes `window.webkit.messageHandlers.kombaxTerminal` to the same R91 Payment Center used by Android and the web fallback.

## Build prerequisites
1. macOS + current Xcode.
2. Apple Developer membership for the KOMBAX organization.
3. Request the **Tap to Pay on iPhone** development entitlement, then distribution entitlement before App Store/TestFlight release.
4. Generate the Xcode project with XcodeGen: `xcodegen generate` from `/ios` (or reproduce `project.yml` settings manually).
5. Resolve StripeTerminal via Swift Package Manager (5.8.0+).
6. Replace only signing Team/Profile settings locally. Never commit certificates, `.p12`, provisioning profiles or private keys.

The entitlement file is intentionally an unsigned source declaration. Apple must authorize it for the Team before a signed Tap to Pay build is valid.

## Web-first period
Until the iOS app is distributed, iPhone users use `https://kombax.es` in Safari/PWA. The Payment Center automatically offers **QR/payment link** instead of NFC. Safari cannot turn the iPhone into a Stripe Tap to Pay reader.
