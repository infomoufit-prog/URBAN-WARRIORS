# KOMBAX R104 · manifiesto de congelación

- Base acumulativa: R104, build 20156, versión `2.0.0-rc.13-r104-public-logo`.
- Supabase: proyecto `poggsobhtutbuagjiydc`, estado `ACTIVE_HEALTHY` al aplicar las migraciones.
- Migraciones aplicadas: `kombax_club_visual_identity_sync_r104`, `kombax_reconcile_existing_club_logo_r104`, `kombax_public_logo_documents_r104`.
- Verificación de datos: club demo con `branding_version=12`; logo y portada del club coinciden con el perfil público; avatar de Social coincide con el logo público; versión 11 conservada en historial.
- Verificación de permisos: los nuevos triggers internos no conceden `EXECUTE` a `anon` ni a `authenticated`.
- Web y Android: `node scripts/build.mjs` copió y comparó 615 archivos en `web`, `dist` y los assets Android.
- Legal: `node scripts/release-legal-gate.mjs` pasó.
- Android: preflight 4/5. Falta la firma privada release para producir un AAB publicable en Google Play.
- Netlify y GitHub: despliegue y subida a cargo del usuario; no se han ejecutado desde esta entrega.
- Límite de QA: el test estático legado de finanzas que busca `Antiguedad de la deuda` falla ante el texto actual `Antigüedad de la deuda`; la función PDF no se modificó en R104. Las migraciones se comprobaron estructuralmente, pero no se emitió un recibo ni se generó un informe financiero real durante esta intervención.
- Gate de piloto: la congelación R104 no implica veredicto GO. Siguen siendo necesarias las verificaciones independientes de copia recuperable, aislamiento y flujos piloto del informe `KOMBAX_PILOT_RELEASE_GATE_2026-10-01`.
