# R67 · checklist de estabilización para Work

Objetivo: certificar navegación, comprensión del producto y continuidad comercial antes del piloto. Corregir defectos; no crear funcionalidades nuevas salvo que el fallo revele una ausencia imprescindible del flujo acordado.

## Entrada pública y marketing

- Abrir KOMBAX sin sesión y verificar que se entiende qué es KOMBAX antes de registrarse.
- Verificar las tres puertas principales: Club, identidad/perfil y cuenta gratuita Espectador.
- Abrir `?profile=club`, `?profile=marca`, `?profile=federacion`, `?profile=competidor`, `?profile=profesional`, `?profile=media` y `?profile=espectador`.
- Confirmar que cada enlace aterriza en la presentación correcta y que Atrás no deja al usuario atrapado.
- En “Conocer KOMBAX”, abrir las fichas de identidad y comprobar que llevan a su presentación.
- Probar móvil estrecho, tablet y desktop: ningún CTA debe quedar fuera de pantalla o tapado por safe areas.

## Cuenta gratuita / Espectador

- Crear una cuenta KOMBAX nueva sin elegir Club ni perfil especializado.
- Confirmar email y acceder.
- Comprobar cabecera `ESPECTADOR · CUENTA GRATUITA`.
- Abrir KOMBAX Social, Showcase y Events desde las tarjetas principales.
- Confirmar que puede descubrir/navegar según las reglas del Espectador.
- Confirmar que no aparecen Alumnos, Finanzas, Assist/Migrations organizacionales ni otras áreas privadas de gestión.
- Abrir “Explorar perfiles” y “Planes y precios”.

## Presentaciones de identidad

Para Club, Marca, Federación, Competidor, Profesional y Media/Creador:

- Verificar nombre, propuesta de valor y texto “para quién es”.
- Verificar beneficios principales.
- Verificar permisos/privacidad sin prometer capacidades no disponibles.
- Verificar “Cómo empiezas”.
- Comprobar que el CTA final sigue el flujo correcto.

## Club

- Presentación → comparar Club/Premium/Enterprise → seleccionar mensual/anual → cuenta → solicitud.
- Verificar que Founder solo se ofrece/activa como mensual.
- Comprobar que el plan elegido llega visible al proceso administrativo sin simular cobro.
- Tras verificación/activación manual de QA, comprobar Mi Club y acceso a “Plan y servicios”.

## Marca

- Presentación → Brand Start/Growth/Enterprise → cuenta/perfil → verificación.
- Comprobar persistencia del plan y ciclo elegidos.
- Abrir Showcase; comprobar límite/capacidad según plan.
- En Growth/Enterprise, comprobar descubrimiento de Events sin saltarse entitlements.

## Federación

- Presentación → plan Federación → cuenta/perfil → verificación.
- Confirmar que Showcase explica la limitación comercial de Federación en vez de dejar un dead end.
- Verificar que no se ofrecen capacidades de Marca/Club por error.

## Competidor / Profesional / Media

- Presentación → cuenta/perfil → solicitud/verificación.
- Confirmar que no aparece una tarifa de organización que no corresponda.
- Profesional: comprobar mayoría de edad cuando proceda.
- Media/Creador: confirmar que mantiene identidad diferenciada y navegación pública correspondiente.

## Showcase y Commerce

- Club Básico: publicar hasta su límite de escaparate y comprobar explicación contextual de Commerce.
- Pulsar activación Commerce y verificar que lleva al servicio/plan correcto, no a un hash o pantalla sin contexto.
- Premium/Enterprise/Marca: comprobar capacidades incluidas según catálogo vigente.
- Verificación de vendedor → contrato/políticas → Stripe Connect test → `selling_ready`.
- Probar pedido, preparación, envío, refund parcial/total y stock separado del refund financiero.
- Confirmar bloqueo de compra para menores de 18 años.

## Events

- Crear/publicar evento desde identidades elegibles.
- Cuando falte capacidad, verificar explicación de qué plan/activación se necesita y su precio.
- Probar publicación temporal, Destacar y activación Ticketing con la tabla vigente.
- Probar venta test, QR, check-in, historial de accesos, cancelación y refund por lote.

## Regresión crítica

- Multiclub.
- Alumno importado sin cuenta → registro → vínculo sin duplicado.
- Menor + tutor.
- 16–17 años con cuenta/membresía permitida pero compra comercial bloqueada.
- Stripe Connect sigue siendo Connect/direct charges para vendedor/organizador.
- Finance Center y BI Enterprise continúan operativos.
- Comunicaciones transaccionales no se duplican.
- Navegación Atrás/Cerrar disponible donde corresponde.

## Release local Android

- Crear `android/keystore.properties` local con el keystore correcto.
- Ejecutar preflight hasta 5/5.
- Compilar APK/AAB firmado localmente.
- Smoke test Android: registro, Espectador, Social, Showcase, Events, deep link y safe areas.

## Criterio de salida del piloto QA

La matriz se considera apta cuando no quedan defectos P0/P1, no existe fuga de gestión privada a Espectador, los planes se descubren antes de las altas comerciales y los bloqueos comerciales siempre explican la vía de activación. SaaS Billing no forma parte de este gate.
