import { access, readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const required = [
  'web/index.html','web/config.js','web/js/app.js','web/js/data-store.js','web/manifest.webmanifest',
  'web/service-worker.js','web/firebase-messaging-sw.js','web/js/push.js','web/assets/urban-warriors-logo.png','web/assets/install-qr.png',
  'supabase/migrations/001_phase1_complete.sql','supabase/migrations/002_access_payments_posts_notifications.sql','supabase/migrations/003_extend_fee_status.sql','supabase/migrations/004_payment_reminders_workflow.sql','supabase/functions/payment-reminders/index.ts','android/app/src/main/AndroidManifest.xml'
];
for (const file of required) await access(resolve(root, file));
for (const file of ['web/config.js','web/js/demo-data.js','web/js/data-store.js','web/js/push.js','web/js/app.js','web/service-worker.js','web/firebase-messaging-sw.js']) {
  const result = spawnSync(process.execPath, ['--check', resolve(root, file)], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(`Error de sintaxis en ${file}:\n${result.stderr}`);
}
const manifest = JSON.parse(await readFile(resolve(root,'web/manifest.webmanifest'),'utf8'));
if (!manifest.icons?.length) throw new Error('Manifest sin iconos');
const sqlFiles = ['001_phase1_complete.sql','002_access_payments_posts_notifications.sql','003_extend_fee_status.sql','004_payment_reminders_workflow.sql'];
const sql = (await Promise.all(sqlFiles.map((file) => readFile(resolve(root,'supabase/migrations',file),'utf8')))).join('\n'); 
for (const expected of ['enable row level security','generar_cuotas_periodo','puede_ver_socio','unique (club_id, nombre)','registrar_cuenta_club','registros_acceso_clase','material_pedidos','notificaciones','configuracion_avisos_cuota','historial_avisos_cuota','procesar_avisos_cobro','pausar_avisos_cuota','puede_aportar_pago_socio','comunicar_pago_cuota','validar_pago_cuota']) {
  if (!sql.includes(expected)) throw new Error(`Falta requisito SQL: ${expected}`);
}
const appJs = await readFile(resolve(root,'web/js/app.js'),'utf8');
for (const expected of ['registration-form','payment-form','pause-alerts-form','reject-payment-form','reminder-settings-form','checkin-form','material-order-form','enable-notifications','payment-alerts']) {
  if (!appJs.includes(expected)) throw new Error(`Falta flujo de aplicación: ${expected}`);
}
console.log(`OK: ${required.length} archivos esenciales, flujos Fase 1.2, avisos de cobro y sintaxis JavaScript validados.`);
