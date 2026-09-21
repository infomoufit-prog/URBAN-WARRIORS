import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RELEASE D: ${msg}`);console.log(`OK RELEASE D: ${msg}`)};
const [ui,finance,sql,dispatch,reminders]=await Promise.all([
  read('web/js/modules/comms-material.js'),
  read('web/js/modules/finance.js'),
  read('supabase/migrations/004_payment_reminders_workflow.sql'),
  read('supabase/functions/notification-dispatch/index.ts'),
  read('supabase/functions/payment-reminders/index.ts')
]);

assert(!ui.includes('Preferencias push')&&!ui.includes('push_finanzas'),'la experiencia elimina categorías push personales');
assert(ui.includes('getNotificationPermissionState')&&ui.includes('openNotificationSettings'),'la bandeja usa solo el permiso global Android');
assert(!dispatch.includes("from('preferencias_notificacion')")&&!reminders.includes("from('preferencias_notificacion')"),'las Edge Functions no filtran categorías personales');
assert(dispatch.includes(".eq('activo',true)")&&reminders.includes(".eq('activo', true)"),'solo se usan dispositivos push activos');
assert(dispatch.includes('UNREGISTERED')&&reminders.includes('UNREGISTERED'),'los dos circuitos desactivan tokens FCM inválidos');
assert(finance.includes('exactamente cinco días distintos entre 1 y 28'),'el formulario conserva cinco días válidos');
assert(sql.includes('cardinality(dias_aviso) = 5')&&sql.includes('unique (club_id, cuota_id, perfil_id, aviso_numero, canal)'),'base de datos conserva cinco avisos e idempotencia');
assert(finance.includes("id=\"process-reminders\"")&&finance.includes('Historial'),'procesamiento manual e historial siguen disponibles');
console.log('RELEASE D REMINDERS: PASS');
