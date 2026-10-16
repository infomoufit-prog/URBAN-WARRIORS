# Validación R278

Resultado final de `node scripts/release-netlify-r104-3.mjs`:

```
OK build 666 archivos · web = dist = Android
KOMBAX Netlify pilot gate: 133 PASS, 3 P2 conocidos, 0 fallos nuevos.
PASS compatibility · 397 JavaScript files · 966 local imports checked for Linux · build 20178 · web/dist/Android identical
```

Las tres incidencias heredadas, conservadas y no ocultadas, son:

- `scripts/i18n-r79-full-product-audit.mjs`
- `scripts/test-kombax-20130-r79-i18n-phases-6-10.mjs`
- `scripts/i18n-runtime-copy-audit.mjs`

La suite estricta `npm test` continúa fallando por esa deuda. El gate solo tolera las frases heredadas registradas, no nuevas traducciones ausentes. Se añadieron las traducciones de los nuevos controles y textos de R278.

Pruebas nuevas integradas: conocimiento maestro (1.299 comprobaciones), datos Owner/migración (17), controlador Owner (17), PDF/CSV (42). Se conserva la regresión acumulativa de familias, cuotas, equipos, altas, moderación, servicios y ayuda.

Se actualizó una aserción estática heredada de R114 que esperaba el SDK de Storage antiguo. Ahora comprueba las llamadas REST privadas que ya utilizaba el backend real, la firma temporal y la ausencia de URL pública. Las 42 pruebas de comportamiento PDF verifican autorización, archivos e integridad; no se retiró la comprobación de seguridad para ocultar el fallo.

Los siete PDF se generaron con datos simulados y la biblioteca real y se inspeccionaron visualmente: doce páginas en total, sin páginas iniciales vacías. No representan estadísticas reales de producción.

Supabase: migración aplicada y comprobada; cuatro funciones activas con JWT y fuentes verificadas mediante lectura posterior. La respuesta real de Pilot Intelligence tras reparar el agregado de créditos fue correcta. La nueva generación real de PDF de marketing no quedó completada por falta de sesión Owner válida.

Navegador: ayuda pública local comprobada con pregunta natural y repregunta contextual sin IA; apertura de guía de club en escenario simulado; acceso Owner local conserva autenticación. No hubo publicación en redes, cobros, campañas ni altas/aprobaciones reales en estas pruebas.

La enumeración de 395 archivos y 1.338 funciones es un inventario estático; no equivale a ejecutar cada flujo real con cada perfil.
