# KOMBAX 20.101 R25 · PILOT STABILIZATION — IMPLEMENTATION PLAN

## 1. Objetivo
Corregir causas raíz demostradas en R23-AUDIT para estabilizar navegación Events antes del piloto de tres clubes.

## 2. Alcance exacto
- Lifecycle de modal/detail Events.
- `Me interesa` y handlers async con la misma causa exacta.
- Hidratación de media Events.
- Cache de detalle Events.
- Coste de compositor de Fight Card/Main Event en móvil Android.
- Tests específicos y regresión.

## 3. Fuera de alcance
Nuevas features, Supabase, migraciones, Edge Functions, Finance/Auth, rediseño Events, seeds, Netlify, GitHub, versionCode, firma Android.

## 4. Archivos probables
- `web/js/modules/kombax-events.js`
- `web/js/ui/components.js`
- `web/js/modules/showcase.js` (solo misma clase causal async target)
- `web/css/kombax-events.css`
- scripts/test R25
- package.json para registrar test R25

## 5. Backend / tablas / RPC / Storage
No cambios. R23 backend se preserva.

## 6. Riesgos
Cambiar lifecycle modal puede afectar otras vistas; se implementará mediante evento previo al remove sin cambiar API pública. Hydration debe conservar retry y URLs reales.

## 7. Riesgos de regresión
Modales globales, media real, Fight Cards, álbum, Showcase guardados, R22 keyset, R23 routing Urban.

## 8. Riesgos multiclub
Ninguno de los cambios debe introducir lógica por club/demo. No se modifica RLS ni datos.

## 9. Riesgos de datos
Cero mutaciones de seed/datos durante implementación. `Me interesa` conserva mutación backend existente.

## 10. Estrategia de migración
Sin migración SQL. Revisión frontend aditiva sobre R23.

## 11. Preservación seed
R19/R20/R22/R23 no se modifican. No DELETE/TRUNCATE/reseed.

## 12. Estrategia QA
- Test dedicado R25.
- R22/R23.
- Regresión global `npm test`.
- Build y paridad SHA web/dist/Android.
- Preflight Android.
- Validación física Android marcada pendiente.

## 13. Criterios de cierre
- `currentTarget` no se usa después de await en handlers auditados.
- `Me interesa` no puede producir null.textContent y evita doble submit.
- Hydration no fuerza todo el álbum a 1.4 s.
- Media se decodifica antes de sustituir placeholder.
- Observer se desconecta al cerrar modal.
- Cache detalle <=24.
- Móvil Events elimina compositor blur y filtros/animaciones caros en cards sin alterar jerarquía.
- R25 test PASS, full regression PASS, build/paridad PASS.
