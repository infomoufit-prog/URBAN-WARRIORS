# VALIDACIÓN 20.101 R34 — KOMBAX Assist Migration + Mi preparación

Estado objetivo: build fuente candidata a pruebas locales/PWA/Android después de regresión.

## Alcance validado
- Descubrimiento y staging privado de migración KOMBAX Assist.
- Preparación/peso en Competidor, miembro, Club y enlace desde Events.
- Accesos explícitos, evidencia privada y separación de Social/Showcase.
- Backend principal Supabase aplicado de forma aditiva.

## Gates
- Sintaxis JS: obligatoria.
- Test específico R34: obligatorio.
- Regresión R32/R33/R33.1: obligatoria.
- Suite completa: obligatoria.
- Build y paridad `web == dist == android assets`: obligatoria.
- ZIP íntegro y extraíble: obligatorio.
- Android firmado: no se genera dentro de este gate; requiere keystore/credenciales locales.
