# KOMBAX 20.101 · R27 · Support Email Frontend

## Objetivo
Hacer visible el canal oficial `soporte@kombax.es` como contacto directo por correo en el frontend, sin obligar al usuario a entrar primero en el centro de privacidad y soporte.

## Alcance exacto
- Mi perfil: mostrar el correo y un CTA `Escribir correo`.
- Mi Club → Ajustes: mostrar el correo como enlace `mailto:` y mantener la entrada a privacidad/acceso.
- Mis perfiles / Mi cuenta KOMBAX: mostrar el correo en la barra de acciones global.
- Mantener el centro de Privacidad y soporte y sus autorizaciones temporales sin cambios funcionales.
- Actualizar cache bust frontend a R27 y reconstruir `dist` + Android assets.

## Fuera de alcance
- No conectar ni desplegar un agente IA de correo.
- No cambiar SMTP/Resend/Supabase Auth.
- No cambiar Supabase, RLS, RPC, Storage o Edge Functions.
- No cambiar permisos Owner/Administrador General.
- No modificar Combat Eventos, Finanzas, Social o Showcase.
- No desplegar Netlify ni GitHub.
- No incrementar Android `versionCode`.

## Archivos/módulos previstos
- `web/js/modules/support-privacy.js`
- `web/js/modules/admin.js`
- `web/js/modules/gateway.js`
- `web/index.html`
- `web/service-worker.js`
- test dedicado R27 + cadena de tests histórica compatible con cache bust posterior.

## Backend / migraciones
Ninguna. La carpeta `supabase/` debe permanecer byte-for-byte igual a R26.

## Riesgos
- Duplicar excesivamente acciones de soporte.
- Romper layout móvil al añadir un segundo CTA.
- Dejar `web`, `dist` y Android desalineados.
- Mantener cache R26 y que PWA no refresque la UI.

## Regresión
Preservar R26 24/24 y toda la suite acumulada.

## Multiclub / datos / seed
Sin cambios. No hay escrituras, migraciones ni seed.

## Estrategia de implementación
Cambio frontend aditivo con `mailto:` al correo canónico exportado por el módulo de soporte; reconstrucción determinista y cache bust R27.

## QA
- Sintaxis JS.
- Test R27 dedicado.
- Test R26 histórico.
- Suite acumulada completa.
- Build determinista web = dist = Android.
- Android preflight.
- Paridad binaria de `supabase/` contra R26.

## Criterio de cierre
R27 dedicado PASS, R26 PASS, regresión global PASS, build determinista PASS, backend sin cambios y ZIP autocontenido verificable.
