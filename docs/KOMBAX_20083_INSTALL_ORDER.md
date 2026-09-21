# Orden de instalación · KOMBAX 20083

1. Backup/restore verificable antes de cualquier cambio.
2. Aplicar migraciones 143, 144, 145, 146, 147 y 148 en ese orden en entorno de validación.
3. Ejecutar advisors de seguridad/rendimiento y tests 20079→20083.
4. Desplegar `finance-report` y `finance-recurring` con su configuración habitual; no ejecutar recurrencia real.
5. Desplegar frontend 20083 completo, incluyendo `context-isolation-20083.js` antes de `app.js`.
6. Validar aislamiento con cuenta multi-identidad: club A, club B/perfil directo y Federación no deben cruzar inbox/actor/header. Cambiar la identidad activa debe cambiar también inbox, badge y Mi red.
   - Importante: actualizar frontend/PWA/APK junto con 147. Los RPC globales históricos se conservan para el workspace KOMBAX global y los clientes antiguos no conocen todavía el nuevo scope contextual.
7. Activar únicamente Finance V2/Dashboard/Reports del club piloto cuando proceda.
8. Ejecutar dos Shadow reales equivalentes y revisar anomalías.
9. Aprobar QA.
10. `finance_pilot_live_enabled` permanece FALSE hasta la decisión explícita de arranque del piloto.
11. Solo entonces ejecutar `finance.pilot.activar` con confirmación literal `ACTIVAR RECURRENCIA`.
12. Verificar primera generación real y repetir el mismo ciclo: la segunda ejecución debe crear 0 duplicados.

Rollback operativo: `finance.pilot.pausar` cierra `pilot_live` y `recurring`; no borrar cargos, pagos, recibos ni snapshots.
