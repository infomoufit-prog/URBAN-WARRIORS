# PROMPT MAESTRO DE CONTINUIDAD · KOMBAX RC13 BUILD 20085

Trabajar SIEMPRE sobre el ZIP FULL build 20085 como nueva fuente de verdad.

## Estado actual

- Base FULL: 20085 Premium Finance + Social QA.
- Supabase producción sincronizado con migraciones Finance/Security 143–154.
- Edge Functions `finance-report` y `finance-recurring` desplegadas.
- Finanzas Premium visual habilitada para Urban Warriors y club QA.
- Recurrencias reales, QA aprobado y pilot-live siguen en FALSE.
- Security Pilot sigue cerrado.
- Social v147 verificado: una identidad/perfil directo y una conversación global quedan correctamente excluidos del workspace Urban Warriors.
- Integridad: 13 cuotas, 8 pagos, 6 recibos, 9 contactos y 24 mensajes preservados.

## Próximo flujo

1. Subir el FULL 20085 con GitHub Desktop y desplegar en Netlify.
2. Confirmar que navegador/PWA muestran build 20085 y limpiar service worker/cache si hiciera falta.
3. QA visual de Finanzas Premium: KPIs, SVG mensual, donut/aging, categorías, grupos, disciplinas, filtros y drill-down.
4. QA Social: feed, perfiles, Mi red, chat, badges, Showcase, cambio de identidad y separación Club A/Club B.
5. Enrolar MFA TOTP Owner y exigir AAL2.
6. Activar Leaked Password Protection en Supabase Auth.
7. Realizar restore drill y registrar evidencia.
8. Ejecutar dos Shadow runs equivalentes por club antes de cualquier aprobación financiera.
9. Generar APK signed 20085 e instalarla localmente.
10. Generar AAB signed 20085 y subir a Google Play Internal/Closed Testing.
11. QA móvil con los dos clubes y ~20 testers.
12. Solo tras QA completo: aprobar Security Pilot y decidir explícitamente si abrir Finance Pilot/recurrencias.

## Reglas innegociables

- KOMBAX no procesa dinero directamente.
- Pago comunicado por alumno/familia queda pendiente y no reduce deuda hasta validación.
- Recibo solo tras pago total validado.
- No borrar ni reescribir historial financiero.
- No mezclar identidades, chats ni datos entre clubes/workspaces.
- Owner/Soporte debe ser temporal, aislado, visible y auditado.
- No activar recurrencia real por accidente.
- Cada futura entrega debe ser ZIP FULL salvo petición expresa de patch.
