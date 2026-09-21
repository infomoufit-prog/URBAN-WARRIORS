# PROMPT MAESTRO DE CONTINUIDAD · KOMBAX RC13 build 20086

Trabaja exclusivamente sobre el ZIP FULL 20.086 como nueva fuente maestra. No reconstruyas desde cero y no regreses a builds anteriores.

Estado funcional:
- Finanzas Premium: dashboard visual interactivo/animado, histogramas, donut, categoría, grupo/disciplina, filtros cruzados y drill-down.
- Recibos: visor profesional restaurado para club y alumno, numeración/branding snapshot preservados.
- Informes: PDF privado con branding, KPIs, histograma, antigüedad y tabla; Edge Function finance-report v3.
- Social: aislamiento de contexto 20.083 preservado.
- Security 20.084 preservado.
- Backend financiero 143→154 ya aplicado en producción.

Gates que deben permanecer cerrados hasta QA explícito:
- finance_recurring_enabled=false
- finance_qa_shadow_approved=false
- finance_pilot_live_enabled=false
- security pilot no abrir sin evidencias finales.

Siguiente fase:
1. Deploy de 20.086 con GitHub Desktop/Netlify por parte del usuario.
2. QA móvil real de Finanzas: Resumen, drill-down, Recibos, Informes PDF.
3. QA KOMBAX Social/chat/cambio de contexto.
4. Solo después: generar APK/AAB signed con el keystore local del usuario y probar en Google Play.

Regla de entrega: cualquier nueva build debe entregarse como ZIP FULL standalone, nunca solo patch salvo petición explícita.
