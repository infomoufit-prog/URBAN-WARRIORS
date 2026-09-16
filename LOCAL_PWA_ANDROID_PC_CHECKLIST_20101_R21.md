# KOMBAX 20.101 R21 · LOCAL PWA / ANDROID / PC CHECKLIST

## PC / Chrome
1. `npm ci` (or `npm install` only if required)
2. `npm run dev`
3. Open the URL printed by Vite.
4. Verify no horizontal overflow in Events at narrow responsive widths.

## Media framing acceptance
For every available authorized item below, open **Ajustar ...**, move focus, change zoom, switch Mostrar completo/Rellenar marco, save, leave the screen and return. The saved presentation must persist and the original must still open complete where a full viewer exists.

- Events: fighter/participant image; Fight Card; album thumbnail.
- Event banner/poster: existing focal controls remain operational.
- Showcase: main product image; gallery image 1/2/3.
- Materiales: product/material image.
- KOMBAX Social: own image publication.
- Mi perfil: private avatar.
- Perfil deportivo: photo.
- Public/direct profile: album/media.
- Club branding: logo + cover.
- Public club profile: logo + cover + album.
- Comunidad: own/managed image publication.
- Comunicaciones: image.

## Event types
- Competition/velada/open/interclub: competitive fields/Fight Card remain.
- Seminario/masterclass/formación: presenter/program/duration/capacity flow; no empty Fight Card/Main Event.

## Responsive
Check mobile portrait/landscape, tablet portrait/landscape, desktop/PWA:
- no horizontal page scroll;
- faces are not forced out of fighter cards;
- product is recognizable in Showcase card;
- album thumbs can be adjusted;
- buttons stay onscreen.

## Android Signed testing
Open `android` in Android Studio.
Generate Signed APK manually using the existing release JKS. Do not publish it to Play for this validation.
Install on device and repeat the checks above.

Current automated preflight: 4/5. Signing remains pending until your local `keystore.properties`/manual Android Studio signing is supplied.
