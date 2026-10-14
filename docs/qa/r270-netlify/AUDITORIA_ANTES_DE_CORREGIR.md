# Auditoría del ZIP R270 y fallo de Netlify

## Fuente revisada

Archivo: KOMBAX_R270_PWA_TODOS_LOS_PERFILES_FINAL_ACUMULATIVO.zip.
SHA-256: `6e7acf9e663c758dfb78a6a098c4c8797baf0f3eebb0ebf8b865b42d5a89fc13`.
5806 entradas; comprobación CRC completa correcta. Conservado sin cambios.
La copia de auditoría está en `work/audit-r270-20261014`.

## Fallo comunicado, reproducido

`scripts/test-kombax-20171-r117-pilot-hotfix.mjs` exige el texto antiguo «Solicitar autorización».
R270 mantiene el flujo de solicitud sin código con el botón «Enviar solicitud al club», selección member/family, detección de ficha existente y envío a `contactClub`.
La misma prueba antigua está en GitHub (blob `eb0164ec961b00ff184c4047590ae5319a58ccd6`, rama main, leído durante esta auditoría).
Se corrigió únicamente esta prueba en la copia aislada: comprueba las dos opciones, el campo request_kind, la nueva acción, la llamada al repositorio y el aviso de revisión del club. No se ha eliminado la prueba ni agregado una excepción al release gate.
Cinco comprobaciones funcionales de ese flujo con repositorios simulados pasan: autenticación necesaria, opciones miembro/familiar, envío familiar, segundo espacio familiar para un miembro ya vinculado y vinculación de ficha existente. No se enviaron solicitudes reales.

## Resultado completo después de esa corrección

- Release legal gate: PASS.
- Generación: 654 archivos, web = dist = Android.
- Todas las 115 suites de pretest/test se ejecutaron en un runner de auditoría que registra los fallos y continúa, sin modificar la condición de aprobación del build.
- Resultado: 110 suites correctas, 5 fallidas.
- El release gate normal sigue bloqueado. La primera prueba arreglada NO basta para desplegar.
- Compatibilidad: PASS, 387 JavaScript, 943 imports locales revisados con sensibilidad de mayúsculas para Linux; build 20178.

### Cinco suites fallidas

1. `i18n-r79-full-product-audit.mjs --strict`: 416 entradas detectadas sin resolver; 141 no coinciden con la lista de excepciones heredadas. Algunas entradas del escáner son técnicas y necesitan clasificación, no traducción indiscriminada.
2. `test-kombax-20130-r79-i18n-phases-6-10.mjs`: 25/26; exige cero textos sin resolver.
3. `i18n-runtime-copy-audit.mjs --all --strict`: cobertura incompleta de textos de interfaz.
4. `test-kombax-20125-r74-i18n-showcase-events-multiclub.mjs`: no encuentra la llamada literal `has(session,'eventManage')` en app.js. Revisar el nuevo lugar de resolución de permisos antes de determinar si es una prueba obsoleta o una regresión funcional.
5. `test-kombax-20123-r72-reputation-catalog.mjs`: 13/14; falta el texto literal «conservará la trazabilidad, las ventas y las reseñas». Revisar el flujo actual de archivo/eliminación antes de actualizar la prueba.

No se amplió la excepción de traducciones. No se confirma ausencia de regresiones funcionales basándose solo en estas pruebas estáticas.

## Meta/Instagram

Los dos módulos backend compartidos, las cuatro Edge Functions, el ejemplo de secrets, el texto i18n Meta, el callback frontend y su HTML coinciden byte a byte con la copia FIX22 anterior. Esto confirma conservación del código, no autorización real ni App Review.
La suite Meta del pipeline figura entre las correctas; usa servicios simulados.
No se realizó OAuth real, publicación en Instagram ni revisión de configuración externa en esta auditoría.

## Evidencia y límites

- `work/R270_NETLIFY_VERIFY.log`: release gate real, bloqueado por traducciones tras corregir la primera prueba.
- `work/R270_REGRESSION_AUDIT.json`: resultado individual de 115 suites.
- `work/R270_REGRESSION_AUDIT.log`: ejecución de todas las suites.
- `work/R270_COMPATIBILITY.log`: compatibilidad y sincronización.
- `work/audit-r270-20261014/scripts/test-no-code-flow-r270.cjs`: prueba funcional simulada adicional.

No se modificó el repositorio remoto, no se hizo push/commit/merge/PR, no se desplegó Netlify y no se cambió Supabase. El ZIP original no está certificado para despliegue. La corrección aislada del test queda disponible, pero no se entrega como una solución completa a los cinco bloqueos restantes.
