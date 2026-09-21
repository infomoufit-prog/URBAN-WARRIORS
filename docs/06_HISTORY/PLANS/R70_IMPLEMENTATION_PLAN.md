# KOMBAX R70 · Plan de implementación ejecutado

**Build:** 20121  
**Base:** R69 build 20120  
**Objetivo:** hacer persistentes en la barra lateral los accesos privados **Mi Showcase** y **Mis Eventos**, sin sustituir los accesos públicos KOMBAX Showcase / KOMBAX Events.

## Bloque 1 · Navegación
- Añadir rutas privadas `#my-showcase` y `#my-events`.
- Mantener `#showcase` y `#kombax-events` como áreas públicas.
- Colocar cada acceso privado inmediatamente debajo de su producto público.
- Marcar visualmente el producto padre cuando se visita su centro privado.

## Bloque 2 · Permisos
- Mostrar `Mi Showcase` solo a roles de club con capacidad potencial de gestión: Dirección, Coordinación, Secretaría y Comunicación.
- Mostrar `Mis Eventos` solo a roles de club con capacidad potencial de organización: Dirección, Coordinación, Secretaría y Comunicación.
- Mantener la validación backend existente dentro de Seller Center y Centro de Eventos.
- No mostrar estos accesos a alumno/familia/espectador ni a roles no gestores.

## Bloque 3 · Rutas directas
- `Mi Showcase` abre directamente el workspace privado de vendedor.
- `Mis Eventos` abre directamente el Centro del organizador.
- Las rutas privadas pasan por el mismo allowlist de navegación de la sesión.

## Bloque 4 · QA y entrega
- Regresión R64–R69.
- Nueva batería específica R70.
- Sincronización `web = dist = Android`.
- Preflight Android y prueba de compilación.
- Actualización de build/health y paquete íntegro.
