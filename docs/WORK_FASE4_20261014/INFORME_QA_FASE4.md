# QA fase 4

## Superadas localmente

- `node scripts/test-kombax-fase4-premium-navigation.mjs`: **94/94 comprobaciones**. Incluye seis identidades directas, navegación común, enlaces sin duplicidad, títulos, restricciones, accesibilidad básica, escape HTML y cableado.
- `node scripts/test-kombax-phase1-multi-space.mjs`: **26/26**.
- `node scripts/test-kombax-phase1-finance-scope.mjs`: **17/17**.
- `node scripts/test-kombax-phase2-inscripciones-licenses.mjs`: **32/32**.
- `node scripts/test-kombax-phase3-finance-void.mjs`: **49/49**.
- `node scripts/test-workspace-access-fix14.mjs`: **13/13**.
- `node scripts/test-kombax-20142-r89-inventory-lifecycle.mjs`: **52/52**.
- `node scripts/test-kombax-20101-professional-finance-r31.mjs`: **15/15**.
- `node scripts/test-kombax-20123-r72-sidebar-product-accordions.mjs`: **9/9**.
- `node scripts/test-kombax-20177-r118-pilot-stabilization.mjs`: OK.
- `node scripts/test-personal-space-r118.mjs`: OK.
- `node scripts/test-release-metadata.mjs`: OK.
- Sintaxis JS módulos modificados: OK.
- Integridad SHA-256 de los espejos web/dist/Android: OK.

## Limitaciones y preexistentes

- La prueba histórica `test-kombax-20101-profile-matrix-r32.mjs` falla en su aserción 7 sobre texto antiguo de `gateway.js`; este archivo **no ha cambiado** en fase 4. No atribuirlo a una regresión sin reproducir en la base anterior.
- Los tests `test-kombax-20101-r33-1-federation-ux.mjs` y `test-kombax-20101-federation-licenses-r33.mjs` dependen de documentos `PLAN_IMPLEMENTACION_R33*.md` ausentes de la base; no se completaron.
- No se ha ejecutado toda la batería `npm test` ni las suites PGlite; no está disponible un entorno instalado y certificado de dependencias.
- E2E autenticado, capturas reales de 320/360/390/430/768/1024/1280/1920px, test Android/PWA, validación de lector de pantalla y pruebas de navegación real **pendientes**.
- Componentes sin handler / sin capacidades aparecen como vista previa, no se les asignan privilegios.
