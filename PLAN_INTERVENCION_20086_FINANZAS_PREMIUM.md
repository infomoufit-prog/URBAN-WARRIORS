# KOMBAX RC13 build 20086 · Plan de intervención Finanzas Premium

## Objetivo
Cerrar las regresiones detectadas tras 20.085 y llevar Finanzas Premium a una experiencia visual, interactiva, animada y coherente entre club/alumno, sin alterar la verdad contable ni abrir las recurrencias reales antes del QA.

## Bloques implementados

### 1. Dashboard Premium interactivo
- Histograma mensual agrupado: generado, cobrado y pendiente.
- Donut de antigüedad de deuda.
- Barras por categoría.
- Barras por grupo y disciplina.
- KPIs financieros con navegación/drill-down.
- Filtros cruzados: al tocar una visualización se actualizan KPIs, detalle y contexto.
- Selección visual persistente y accesible (`aria-pressed`).

### 2. Animación funcional
- Entrada suave de KPIs y paneles.
- Crecimiento de barras desde cero.
- Dibujo progresivo del donut.
- Expansión de barras de composición.
- Respeto estricto a `prefers-reduced-motion`.
- Interacción táctil; ninguna función esencial depende de hover.

### 3. Recibos del club
- Restaurado `Ver recibo` dentro de Finanzas Premium para Dirección/Tesorería/Secretaría según RLS existente.
- Reutiliza el visor profesional heredado; no crea un formato paralelo.
- Conserva número correlativo, branding snapshot, alumno, concepto, periodo, pago, método e importe.
- Mantiene `Imprimir / Guardar PDF` y documento verificable.

### 4. Informes PDF
- Edge Function `finance-report` con CORS y preflight OPTIONS.
- PDF privado con branding/logo, KPIs, periodo, actor y snapshot histórico.
- Histograma mensual dentro del PDF.
- Visualización de antigüedad de deuda dentro del PDF.
- Tabla detallada de movimientos.
- Histórico inmutable y enlace firmado temporal.

### 5. Integridad y seguridad
- No se modifica la semántica de cuota/pago/recibo.
- No se activa `finance_recurring_enabled`.
- No se activa `finance_qa_shadow_approved`.
- No se activa `finance_pilot_live_enabled`.
- Sin JKS, keystore.properties, .env ni secretos en el entregable.

## Criterios de aceptación
1. `npm test` PASS.
2. `npm run release:build` PASS.
3. `web`, `dist` y Android assets idénticos.
4. Build marker 20086 en web, service worker, Android y health.
5. Recibos del club abren el visor profesional.
6. PDF de informes contiene histogramas, antigüedad y tabla.
7. Visualizaciones son clicables/táctiles y aplican drill-down.
8. Animaciones se desactivan con reduced-motion.
