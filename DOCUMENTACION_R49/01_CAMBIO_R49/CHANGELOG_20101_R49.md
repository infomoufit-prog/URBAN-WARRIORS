# KOMBAX 20.101 R49 · Social + Events Final Polish

Base preservada: R48 Events Premium Polish.

## Combat Social
- Separa definitivamente **Me gusta / Like** de **Me interesa / No me interesa**.
- ❤️ Me gusta = reacción pública y contador público.
- 👍 Me interesa / 👎 No me interesa = preferencia privada para ranking; no expone contador público ni identidad de quien la marca.
- Las publicaciones ajenas muestran: Me gusta · Preferencia · Comentar · Compartir (si la audiencia permite compartir).
- Las publicaciones propias muestran el resumen público de Me gusta y comentarios, sin controles de afinidad privados.
- El feed v238 pondera recencia, likes, comentarios, guardados y afinidad privada sin mezclar tablas.
- Añadido aviso permanente de comunidad temática: Combat Social está dedicado a artes marciales y deportes de contacto.
- Añadido recordatorio temático al publicar.
- Añadido motivo de moderación `fuera_tematica`; entra en la cola de moderación y **no borra automáticamente**.

## Combat Events
- El acabado premium R48 se conserva y R49 añade interacción viva del cartel también para eventos ya existentes.
- Carteles de discovery, detalle y landing pública reciben microinteracción de zoom/glow.
- El cartel de detalle y landing pública se puede abrir por toque/clic/teclado en visor inmersivo con `object-fit: contain`.
- Se respeta `prefers-reduced-motion`.
- Se mantienen Main Event, Co-Main Event, undercard, cartel general de Fight Card, fotos de peleadores opcionales y fallback visual cuando no existen fotos.
- No se crea una tabla nueva de Events ni una migración Events.

## Backend
Migración R49 aplicada al Supabase principal:
`kombax_social_like_interest_separation_r49`

Crea/actualiza:
- `app_kombax_social_preference_v240`
- `app_kombax_social_report_offtopic_v240`
- `app_kombax_social_feed_v238`
- constraint de motivos de `kombax_social_reportes` con `fuera_tematica`.

## No realizado
- Sin deploy Netlify.
- Sin push GitHub.
- Sin firma APK/AAB porque `android/keystore.properties` es una dependencia local deliberadamente excluida.
