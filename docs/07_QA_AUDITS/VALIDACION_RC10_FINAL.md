# Validación RC10 FINAL MVP

## Ejecutado localmente

- [x] Suite de arquitectura.
- [x] Contrato completo del gateway.
- [x] Regresiones RC4, RC5, RC6, RC7, RC8 y RC9.
- [x] Suite RC10.
- [x] Build web.
- [x] Sincronización `web` → `dist` → Android.
- [x] Versionado Android `2.0.0-rc.10 / 20010`.
- [x] Validación estática de Comunidad: límites 3/5, 15 s y retención 30 días.
- [x] Validación estática de recurrencias y excepciones.
- [x] Validación estática de agrupación/lectura masiva de notificaciones.
- [x] Validación estática de estado de cuenta financiero.
- [x] Validación estática de perfil/avatar.
- [x] Validación estática de textos y aceptación legal.
- [x] Manual de usuario presente.
- [x] Manual de equipo presente.
- [x] Cartel restringido por interfaz al equipo autorizado.
- [x] Android conserva ruta de una notificación al abrirla y resincroniza token existente.

## Pendiente en infraestructura real

- [ ] Ejecutar `SQL_EJECUTAR_RC10_022.sql` en Supabase real.
- [ ] Comprobar 12/12 controles `OK` de `app_diagnostico_instalacion_v166()`.
- [ ] Ejecutar E2E desde Chrome contra Supabase real.
- [ ] Probar una serie semanal + excepción + reserva.
- [ ] Probar Comunidad con imagen y vídeo real <=15 s.
- [ ] Probar sustitución/eliminación de avatar.
- [ ] Probar cuenta financiera y flujo de pago/validación/recibo.
- [ ] Probar lectura por grupo/todas las notificaciones.
- [ ] Probar aceptación y retirada de derechos de imagen.
- [ ] Configurar Firebase/Edge/cron reales.
- [ ] Recibir push con Android físico y aplicación cerrada.

## Criterio de promoción

Solo después de completar los puntos de infraestructura real se cambia `2.0.0-rc.10` a `2.0.0` y se genera la build release firmada.

## Integración de manuales visuales

- Manual visual de usuario integrado como assets locales y accesible desde `Manual y ayuda` para Alumno/Familia.
- Manual visual del equipo integrado en cuatro páginas y priorizado para Gestor, Coordinación, Secretaría, Tesorería, Comunicación y Monitor.
- Gestor/Coordinación/Secretaría conservan acceso al cartel de difusión; no se expone al usuario normal.
- Visor interno responsive con navegación anterior/siguiente y apertura de imagen completa.
- Build posterior a la integración: `web = dist = Android`, 44 archivos del frontend.
