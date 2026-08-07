import { access, readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const required = [
  'web/index.html','web/config.js','web/js/app.js','web/js/data-store.js','web/manifest.webmanifest',
  'web/service-worker.js','web/firebase-messaging-sw.js','web/js/push.js','web/assets/urban-warriors-logo.png','web/assets/install-qr.png',
  'supabase/migrations/001_phase1_complete.sql','supabase/migrations/002_access_payments_posts_notifications.sql',
  'supabase/migrations/003_extend_fee_status.sql','supabase/migrations/004_payment_reminders_workflow.sql',
  'supabase/migrations/005_security_hardening.sql','supabase/migrations/006_production_runtime_fixes.sql',
  'supabase/migrations/007_operational_v130.sql','supabase/functions/payment-reminders/index.ts',
  'supabase/functions/notification-dispatch/index.ts','supabase/cron_notification_dispatch.sql.example',
  'android/app/src/main/AndroidManifest.xml'
];
for (const file of required) await access(resolve(root, file));
for (const file of ['web/config.js','web/js/demo-data.js','web/js/data-store.js','web/js/push.js','web/js/app.js','web/service-worker.js','web/firebase-messaging-sw.js']) {
  const result = spawnSync(process.execPath, ['--check', resolve(root, file)], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(`Error de sintaxis en ${file}:\n${result.stderr}`);
}
const manifest = JSON.parse(await readFile(resolve(root,'web/manifest.webmanifest'),'utf8'));
if (!manifest.icons?.length) throw new Error('Manifest sin iconos');
const sqlFiles = ['001_phase1_complete.sql','002_access_payments_posts_notifications.sql','003_extend_fee_status.sql','004_payment_reminders_workflow.sql','005_security_hardening.sql','006_production_runtime_fixes.sql','007_operational_v130.sql'];
const sql = (await Promise.all(sqlFiles.map((file) => readFile(resolve(root,'supabase/migrations',file),'utf8')))).join('\n');
for (const expected of [
  'enable row level security','generar_cuotas_periodo','puede_ver_socio','unique (club_id, nombre)',
  'registrar_cuenta_club','registros_acceso_clase','material_pedidos','notificaciones','configuracion_avisos_cuota',
  'historial_avisos_cuota','procesar_avisos_cobro','pausar_avisos_cuota','puede_aportar_pago_socio',
  'comunicar_pago_cuota','validar_pago_cuota','club-public-media','member-documents','invitaciones_club',
  'app_guardar_grupo','app_guardar_socio','app_aprobar_preinscripcion','app_guardar_disciplina','app_guardar_grado',
  'app_registrar_graduacion','app_guardar_tarifa','app_guardar_material','app_guardar_comunicacion','app_guardar_sesion',
  'app_solicitar_material','app_actualizar_pedido_material','app_crear_preinscripcion','app_marcar_notificacion_leida','notificaciones_lecturas','publicar_comunicaciones_programadas','generar_recordatorios_clase','v_progreso_socio'
]) {
  if (!sql.includes(expected)) throw new Error(`Falta requisito SQL: ${expected}`);
}
const appJs = await readFile(resolve(root,'web/js/app.js'),'utf8');
for (const expected of [
  'registration-form','invited-registration-form','member-form','enrollment-form','discipline-form','grade-form',
  'graduation-form','group-form','session-form','communication-form','tariff-form','material-form',
  'material-variant-form','material-order-form','progress-form','document-form','payment-form',
  'pause-alerts-form','reject-payment-form','reminder-settings-form','checkin-form','enable-notifications',
  'data-edit-group','data-edit-discipline','data-edit-tariff','data-edit-material','data-edit-communication'
]) {
  if (!appJs.includes(expected)) throw new Error(`Falta flujo de aplicación: ${expected}`);
}
if (appJs.includes('[data-notification,[data-')) throw new Error('Selector de botones malformado detectado.');
const declaredActions = [...appJs.matchAll(/data-action=["']([^"']+)/g)].map((match) => match[1]);
const handledActions = new Set([...appJs.matchAll(/action === '([^']+)'/g)].map((match) => match[1]));
const missingActions = [...new Set(declaredActions)].filter((action) => !handledActions.has(action));
if (missingActions.length) throw new Error(`Botones sin controlador: ${missingActions.join(', ')}`);
console.log(`OK: ${required.length} archivos esenciales, migración 007, CRUD operativo, Storage, progreso y preparación Firebase validados.`);
