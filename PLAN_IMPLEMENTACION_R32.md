# KOMBAX 20.101 R32 · PLAN DE IMPLEMENTACIÓN · PROFILE MATRIX HARDENING / PILOT RC

## Base congelada
- Fuente: KOMBAX 20.101 R31 · Professional Basic Finance, cerrada tras regresión completa y backend v199 reconciliado.
- No se reabre R28–R31 salvo para corregir una regresión demostrable.
- El Plan Maestro R28 adjunto es la fuente normativa para este cierre.

## Objetivo
Cerrar la implantación R28–R32 como candidato **Pilot RC** listo para validación local/PWA/Android y posterior APK/AAB signed por el Owner, sin realizar push a GitHub ni deploy a Netlify.

## Alcance R32
1. Matriz completa de tipos de perfil y shells gestionados.
2. Matriz cross-subject/cross-tenant estructural y backend.
3. Auditoría dirigida de RLS, grants y RPC sensibles.
4. Advisors de seguridad y rendimiento, separando findings nuevos de heredados.
5. Hardening de cache/versionado PWA y paridad web/dist/Android.
6. Regresión histórica completa.
7. Comprobación de compatibilidad arquitectónica con la escala de Clubes existente; no se introduce dependencia por club nuevo ni migración por tenant.
8. Documentación final, decisiones Pro posteriores, checklist local y packaging seguro.

## Decisiones congeladas
- Competidor sigue siendo un tipo independiente y no un subtipo Profesional.
- Profesional: Entrenador, Manager, Médico/Sanitario, Árbitro/Juez, Promotor/Organizador y catálogo controlado.
- Profesional autónomo: 18+.
- Espectador: consumidor, 16+ para autorregistro, no publicador por defecto y sin verificación profesional.
- Federación tiene Mi Federación, separada de Mi Club y sin acceso implícito a datos privados de clubes afiliados.
- Capacidades efectivas gobiernan operaciones sensibles.
- Manager requiere delegación aceptada y revocable.
- Médico no recibe acceso clínico por tipo.
- Finanzas Profesionales usan professional_profile_id/direct_profile; no fake club_id.
- KOMBAX no procesa dinero ni emite facturación fiscal automática en esta fase.

## Backend
R32 no introduce un nuevo dominio ni requiere DDL adicional por defecto. El estado live esperado queda en las migraciones R28 reconciliadas + 199–204. Solo se añadiría una migración compensatoria si advisors o pruebas detectan una deuda nueva de R28–R31.

Auditorías live:
- RLS activa en tablas privadas Profesional/Finanzas.
- cero DML directo de anon/authenticated en tablas v198/v199 privadas.
- RPC sensibles con auth + gestión de subject + capability.
- una única policy SELECT authenticated en notificaciones, con soporte Club histórico + direct_profile.
- ninguna tabla de Finanzas Profesionales contiene club_id.
- afiliación Federación→Club no abre tablas privadas Club.

## QA
### Estático/determinista
- Test dedicado R32 de matriz de perfiles, capacidades, aislamiento, navegación y packaging.
- `npm test` completo.
- `node scripts/build.mjs`.
- paridad recursiva `web = dist = android/app/src/main/assets/www`.
- Android preflight.
- service worker/cache R32.

### Backend real
No se crearán cuentas QA nuevas ni se tocarán datos reales del piloto solo para satisfacer la matriz. Se validarán contratos, RLS, grants, RPC y aislamiento con consultas read-only y gates sin sesión. Las pruebas de usuario real/dispositivo se dejan en el checklist local del Owner.

### Visual/manual pendiente del Owner
- 360x800.
- 390/412 móvil moderno.
- tablet 768/820.
- desktop 1280+.
- Android WebView real con APK construida desde este mismo ZIP.

## Riesgos y mitigación
- Contaminación de identidad: caches por subject + evento de cambio de identidad + cache R32.
- Fuga Federación→Club: no crear RLS de afiliación sobre datos privados; matriz dedicada.
- Fake Club profesional: prohibición estructural/test de ausencia de club_id en finanzas profesionales.
- Exceso de privilegios por subtipo: mutaciones sensibles siguen requiriendo capability/backend.
- Sobrepago/estado financiero incorrecto: RPC v199 mantiene invariantes y test R31 permanece en regresión.
- Deuda de advisors heredada: se documenta; solo se corrige deuda nueva atribuible a R28–R32.

## Fuera de alcance
- pagos/ticketing internos;
- pasarela bancaria;
- facturación fiscal completa;
- expediente o historia clínica/e-prescripción;
- contratos legales automatizados Manager–Competidor;
- marketplace de contratación;
- publicación social libre del Espectador;
- precios/funciones Pro definitivos;
- integración IA soporte↔correo;
- push GitHub o deploy Netlify.

## Rollback
- Frontend: volver a la copia cerrada R31.
- Backend: R32 no elimina datos ni requiere DDL nuevo; cualquier compensación sería aditiva.
- Profesional/Espectador pueden congelarse funcionalmente por capacidades/entitlements sin borrar perfiles.

## Gate de cierre
R32 solo se declara listo para validación local/signed cuando:
1. test R32 dedicado PASS;
2. regresión completa PASS;
3. auditoría RLS/grants/RPC PASS dirigida;
4. advisors ejecutados y findings nuevos corregidos/justificados;
5. build/paridad PASS;
6. preflight Android 4/5 o 5/5, siendo 4/5 aceptable únicamente si la única ausencia es configuración de firma local;
7. documentación/manifest/package PASS;
8. no hay secretos de firma en el ZIP;
9. no se ha ejecutado GitHub/Netlify;
10. queda explícitamente pendiente la validación visual/dispositivo que el Owner realizará localmente antes de subir/desplegar.
