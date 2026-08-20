# KOMBAX 20.062 · COMPETITOR REOPEN + FOUNDERS PROMO · VALIDATION

Fecha: 2026-08-20
Fuente base: KOMBAX 20.061 · 10K CONCURRENT SCALE READINESS

## Alcance

Esta intervención reabre el perfil oficial **Competidor** y coloca dos anuncios de lanzamiento:

- Competidores: Combat Social / KOMBAX Social.
- Clubes: KOMBAX Showcase.

No introduce precios ni una promesa económica cuantificada.

## Auditoría Competidor

La auditoría live confirmó que Competidor nunca fue eliminado del backend:

- `app_kombax_perfil_mutate_v072` sigue admitiendo `competidor`;
- el validador canónico conserva lógica específica de Competidor;
- `authenticated` puede ejecutar el mutador canónico;
- `anon` no puede ejecutarlo;
- la continuidad Social Miembro ↔ Competidor y las guardas históricas siguen presentes.

Estado live auditado:

- Competidores creados: 0.
- Competidores verificados: 0.
- Eventos verified Competidor: 0.
- Eventos verified Club: 0.

La prueba transaccional de escritura con `ROLLBACK` se intentó mediante el conector, pero fue bloqueada por los controles de seguridad antes de llegar a Supabase. **No se contabiliza como prueba ejecutada.** El E2E real de creación/envío/verificación queda como validación manual pendiente.

## Implementación UI

### Gateway

Competidor vuelve a estar disponible como identidad oficial. El copy informa de perfil deportivo, verificación KOMBAX y continuidad con Miembro. Profesional/Representante y Espectador permanecen reservados.

### Combat Social

Texto implementado:

> **PRIMEROS 20 · COMPETIDORES FUNDADORES**  
> Los primeros 20 competidores que completen la verificación KOMBAX quedarán incluidos en una **ventaja especial de lanzamiento** cuando KOMBAX active su modalidad de suscripción. Próximamente comunicaremos en qué consiste.  
> La plaza se determina por el orden de verificación KOMBAX.

### Showcase

Texto implementado:

> **PRIMEROS 20 · CLUBES FUNDADORES**  
> Los primeros 20 clubes que completen la verificación KOMBAX quedarán incluidos en una **ventaja especial de lanzamiento** cuando KOMBAX active su modalidad de suscripción. Próximamente comunicaremos en qué consiste.  
> La plaza se determina por el orden de verificación KOMBAX.

Las funciones promocionales no contienen `€`, precio, descuento ni porcentaje concreto.

## Trazabilidad primeros 20

Se reutiliza la auditoría existente: `kombax_verificacion_eventos.evento='verified'`, enlazada a `kombax_solicitudes_alta.tipo`, ordenada por `kombax_verificacion_eventos.creado_en` y `id` como desempate. No se creó migración 107 ni tabla promocional.

Documento específico: `FOUNDERS_PROMOTION_TRACEABILITY_20062.md`.

## Pruebas

- `npm test`: **PASS**.
- Regresión 20.062: **PASS**.
- Regresiones históricas 20.059 / 20.060 / 20.061: **PASS**.
- `npm run build`: **PASS**.
- Builder: **66 archivos · web = dist = Android**.
- Verificación independiente: web 66 / dist 66 / Android 66.
- Missing: 0.
- Extras: 0.
- Diferencias SHA-256: 0.
- Web tree SHA-256: `d9bf72bc5f8a51d7030753bde24426f7a5dff75214661e15c3fb8768f73bce29`.

## Android

Preflight: **4/5**.

- applicationId estable: OK.
- versionCode 20062: OK.
- assets/www: OK.
- Firebase push: OK.
- firma release local: PENDIENTE, por diseño fuera del paquete.

El comando de preflight termina con código 2 debido exclusivamente a esa firma pendiente.

## Secret audit

- archivos secretos/firma prohibidos: 0;
- bloques PRIVATE KEY: 0;
- candidatos de valor `service_role`: 0;
- `android/keystore.properties.example`: presente como plantilla;
- `android/keystore.properties` real: ausente.

## Supabase Security Advisor

No hubo DDL en 20.062, por lo que no se aplicó una nueva migración. La revisión posterior mantiene las categorías conocidas:

- `rls_enabled_no_policy` INFO en tablas deliberadamente cerradas/deny-by-default;
- 5 endpoints públicos SECURITY DEFINER ya conocidos e intencionales;
- WARN de funciones SECURITY DEFINER autenticadas que forman parte de la API RPC KOMBAX;
- `Leaked Password Protection Disabled` continúa como pendiente real de Auth.

Remediación oficial Auth: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

Referencia del linter: https://supabase.com/docs/guides/database/database-linter

## Supabase Performance Advisor

Sin nueva categoría derivada de 20.062. Permanecen:

- `unindexed_foreign_keys` INFO, principalmente relaciones actor/auditoría ya evaluadas;
- `unused_index` INFO por tráfico todavía reducido.

No se añadieron índices indiscriminadamente para Competidor porque reutiliza contratos existentes y actualmente no hay filas Competidor que justifiquen una nueva estructura.

## Pendientes antes de freeze

Validación manual con cuentas reales:

1. seleccionar Competidor desde Gateway;
2. registrar/iniciar sesión y crear borrador;
3. continuidad desde Miembro y alta independiente;
4. completar solicitud/documentación;
5. revisión y verificación por administrador KOMBAX;
6. activación Social y perfil público Competidor;
7. comprobar el primer evento `verified` y su posición promocional;
8. comprobar banners en móvil, PWA y APK.

20.062 es candidata técnica; no es freeze final.
