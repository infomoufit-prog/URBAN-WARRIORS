# KOMBAX 20.101 R22 — Performance, Scale, Fight Card Hierarchy & Media Quotas

## 1. Objetivo
Eliminar degradaciones de navegación percibidas en R21, preparar los caminos críticos para miles de clubes y decenas de miles de usuarios, reordenar Fight Card con Main Event dominante y separar cuotas multimedia por dominio lógico.

## 2. Alcance exacto
- Events list/detail performance: paginación/ventanas pequeñas, lazy hydration, eliminación de N+1 y trabajo de reparación en navegación.
- Media loading: thumbnails/lazy load/placeholder estable para evitar flashes negros.
- Fight Card: Main Event primero y mayor; Co-Main segundo si existe; undercard compacta.
- Límite de hasta 30 combates por evento.
- Álbum oficial hasta 30 fotos.
- Cartel, banner y fotos de participantes/fighters fuera de cuota de álbum.
- Posibilidad de añadir una media existente al álbum por referencia, sin duplicar binario cuando el backend lo permita.
- Revisión de índices/consultas usadas por los caminos modificados.

## 3. Fuera de alcance
- Reescritura masiva de Social/Finance/Auth.
- Nuevos sistemas paralelos de Events o Storage.
- Deploy Netlify/GitHub.
- APK Signed/AAB.

## 4. Archivos/módulos probables
- web/js/modules/kombax-events.js
- web/js/core/repositories.js
- web/css/kombax-events.css
- supabase/migrations/*R22*.sql
- scripts/test-kombax-20101-*-r22.mjs
- package.json

## 5. Backend
- RPC/listados Events existentes y sus límites.
- kombax_evento_media / participantes / combates / eventos_publicos.
- RLS/GRANT/EXECUTE y Storage existentes.

## 6. Riesgos
- Cambiar contrato de RPC y romper clientes antiguos.
- Desordenar Fight Card o perder Main Event.
- Introducir filtros que oculten eventos.
- Duplicar media al enlazar al álbum.

## 7. Riesgos de regresión
- R19 Showcase, R20 seminario, R21 framing.
- Event Creator y edición existente.
- Android assets parity.

## 8. Riesgo multiclub
Toda consulta/mutación debe mantener event/workspace/club ownership y no ampliar visibilidad.

## 9. Riesgo de datos
No borrar seed ni media. Los cambios de cuota deben ser no destructivos.

## 10. Estrategia de migración
Aditiva/idempotente; reutilizar tablas/RPC existentes; índices solo si evidencia de consulta lo justifica.

## 11. Preservación seed
Verificar R19=3 productos; R20=1 seminario + 2 publicaciones; ejecutar cualquier seed R22 dos veces si existe.

## 12. QA
Test R22 dedicado + npm test completo + build + paridad web/dist/Android + advisors + comprobación de consultas y permisos.

## 13. Criterios de cierre
- Primer viewport no solicita catálogos masivos.
- Sin reparación/seed/upload automático en navegación.
- Sin N+1 evitable de media/event detail en listados.
- Placeholders no negros y carga lazy estable.
- Main Event primero/dominante; Co-Main segundo si existe.
- 30 combates; 30 fotos de álbum independientes; cartel/banner/fighters fuera de cuota.
- Regresión completa PASS y build/paridad PASS.
