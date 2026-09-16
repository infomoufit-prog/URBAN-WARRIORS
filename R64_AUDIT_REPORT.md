# KOMBAX 20.112 R64 - Auditoría de base R63

## Base auditada
- Origen: KOMBAX 20.111 R63 `SHOWCASE_EVENTS_COMPLIANCE_READY`.
- Objetivo R64: integrar pricing, fees y contratación comercial sin reconstruir los módulos existentes.
- Estrategia: cambios acumulativos, compatibilidad hacia atrás y configuración centralizada.

## Arquitectura reutilizada
- Onboarding existente con las vías `Entrar con mi club` y `Perfil`.
- Identidades y perfiles directos existentes; `entrenador` y `promotor_organizador` ya estaban modelados como especialidades de Profesional.
- Fichas sin cuenta, registro posterior, deduplicación, multiclub, menores/tutores y aislamiento por club.
- KOMBAX Social, Showcase, Events, Ticketing, QR/control de acceso, Assist y Migrations.
- Stripe Connect Standard con direct charges.
- Motor de planes/capabilities y entitlements históricos.
- Contratos/aceptación legal de Showcase y Events/Ticketing.

## Hallazgos que obligaban a adaptación
1. R63 mantenía un bloqueo explícito a `platform_fee = 0`; R64 necesita 1,5 % / 0 % según plan.
2. Ticketing aparecía como add-on y descomponía capacidades técnicas; R64 lo consolida como un único servicio.
3. Existían conceptos históricos de promoción separados; R64 consolida comercialmente todo en `Destacar`.
4. Migrations estaba orientado a Club/Federación; R64 extiende el mismo motor a Marca sin duplicarlo.
5. El motor SaaS existente permite registrar planes/capabilities, pero el ZIP no contiene un ciclo completo de Stripe Billing recurrente con Price IDs listo para activar cobros reales de suscripción. R64 no simula pagos: registra solicitudes auditables hasta que ese ciclo sea conectado/autorizado.

## Principio aplicado
No se han eliminado ni renombrado de forma destructiva IDs, tablas o capabilities históricas. Cuando un nombre antiguo sigue siendo necesario para compatibilidad, se mantiene internamente y se mapea al producto comercial vigente.
