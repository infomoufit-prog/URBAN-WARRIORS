# KOMBAX R112 · build 20165 · Free public identity coherence

## Objetivo
Alinear la ejecución backend con el onboarding y el catálogo R98 ya aprobado: cuenta gratuita, identidad gratuita, verificación independiente y plan/capacidades como capa separada.

## Cambios
- La identidad directa **verificada** de Competidor, Marca, Federación, Profesional y Media puede ser pública sin suscripción.
- Las capacidades con origen `suscripcion` siguen requiriendo **verificación + servicio activo**.
- El badge de Marca/Federación sigue requiriendo **verificación + pago confirmado** (`app_kombax_subscription_paid_v102`).
- Social directo soporta Marca, Federación, Competidor, Profesional y Media sin dependencia de un plan; publicar exige `social_activo` y las reglas R109.
- Miembro → Competidor conserva continuidad sin requerir servicio de pago.
- Avatar/banner y lectura del álbum de un perfil verificado dejan de depender del servicio activo. Fotos/vídeos siguen sujetos a los límites existentes de `app_kombax_media_guard_v043`; R112 no regala capacidades premium.
- Se recupera en la base acumulativa el source del hotfix R111 del trigger de identidad.

## No modificado
- Onboarding y selector de perfiles.
- Checkout SaaS.
- Stripe / Connect / Ticketing / Commerce.
- Reglas de menores y edad.
- Badge institucional de pago.
- Límites existentes de álbum, Showcase y moderación.

## Verificación live
- R112 aplicado en Supabase activo.
- Readback confirma retirada de la dependencia de servicio en visibilidad/álbum/continuidad Competidor.
- Readback confirma que los badges Marca/Federación mantienen la comprobación de pago confirmado.
- Los perfiles verificados existentes continuaron públicos tras la migración.

## QA
- R112 funcional: 12/12 + 10/10 PASS.
- Política de cuentas: 15 escenarios PASS.
- R109: 25/25 PASS.
- R102 badge: PASS.
- Build 20165: 8/8 PASS.
- Netlify/release: 54 PASS, 7 P2 conocidos, 0 fallos nuevos.
- Build: `web = dist = Android`.
- Android preflight: 7/8; pendiente solo firma local.

## Estado
PASS para la corrección de coherencia. La validación Android firmada / Google Play sigue siendo un gate externo independiente.
