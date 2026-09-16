# KOMBAX R43 — Handoff QA / Work

## Objetivo de R43
Reducir fricción visual y gasto de IA: Assist/Migrations son herramientas organizativas, prioritarias para Federación y Club, no para usuarios personales.

## Casos obligatorios de QA
1. Alumno/Miembro: no ve Assist ni Migrations como opción principal; URL directa no debe habilitar consumo.
2. Familia: mismo resultado.
3. Competidor/Profesional: mismo resultado.
4. Monitor/Comunicación: mismo resultado.
5. Club Dirección/Coordinación/Secretaría/Economía: ve y puede iniciar flujo permitido.
6. Federación propietaria activa: ve y puede iniciar flujo permitido.
7. Marca: no dispone del servicio en R43.
8. Cambio de identidad en una misma cuenta: el menú debe recalcular correctamente el acceso.
9. Intento manual contra RPC desde identidad personal: debe terminar antes de reservar turno/allowance.
10. Verificar que soporte general por correo continúa accesible.

## Regresión ya automatizada
- R40 74/74 PASS.
- R42 24/24 PASS.
- R43 18/18 PASS.
- Build/paridad web-dist-Android PASS.

## No asumir
No asumir que la migración viva, RLS global, advisors o costes reales OpenAI están validados solo porque los tests de repositorio pasan. Esos puntos requieren QA vivo.
