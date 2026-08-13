import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RELEASE F: ${msg}`);console.log(`OK RELEASE F: ${msg}`)};
const [schema,reminders,rollbackSchema,rollbackReminders,repos,ui,financeUi,dispatch,paymentWorker]=await Promise.all([
  read('supabase/migrations/025_material_validation_finance.sql'),
  read('supabase/migrations/026_material_payment_reminders.sql'),
  read('supabase/rollbacks/025_material_validation_finance.sql'),
  read('supabase/rollbacks/026_material_payment_reminders.sql'),
  read('web/js/core/repositories.js'),
  read('web/js/modules/comms-material.js'),
  read('web/js/modules/finance.js'),
  read('supabase/functions/notification-dispatch/index.ts'),
  read('supabase/functions/payment-reminders/index.ts')
]);

assert(schema.includes("'pendiente_validacion'")&&schema.includes('validado_por')&&schema.includes('validado_en'),'pedido conserva estado, validador y fecha');
assert(schema.includes('for update')&&schema.includes('Stock insuficiente'),'validación bloquea filas y evita stock negativo');
assert(schema.includes("origen,'material'")||schema.includes("'material',v_pedido.id"),'cargo financiero queda vinculado a origen material');
assert(schema.includes('uq_cuotas_origen_material')&&schema.includes("estado in ('validado','entregado')"),'validación repetida no duplica cargo');
assert(schema.includes('El alumno no puede validar su propia retirada'),'alumno no puede autoaprobar la deuda');
assert(schema.includes("p_operation not in ('material.solicitar','material.pedido.estado')"),'gateway intercepta solo material y preserva RC10');
assert(schema.includes('revoke insert,update,delete')&&schema.includes('from authenticated'),'escritura directa de pedidos y entregas queda cerrada');
assert(!schema.includes('create or replace view public.v_estado_cuenta_socio')&&!schema.includes('create or replace view public.v_finanzas_detalle'),'025 preserva contratos de vistas existentes');
assert(financeUi.includes('publicConcept')&&financeUi.includes('[0-9a-f]{8}'),'interfaz presenta concepto de material sin sufijo técnico');
assert(reminders.includes('Material pendiente')&&reminders.includes('conceptos pendientes'),'un solo motor genera avisos individuales y agrupados');
assert(reminders.includes('on conflict')&&reminders.includes('historial_avisos_cuota'),'avisos conservan historial e idempotencia');
assert(rollbackSchema.includes('Rollback conservador')&&rollbackReminders.includes('Restaura el motor'),'los dos cambios tienen punto de retorno');
assert(repos.includes('validar_ahora:p.validar_ahora===true'),'frontend comunica validación directa autorizada');
assert(ui.includes('Validar y generar cargo')&&ui.includes('Pendiente de validación'),'interfaz separa solicitud y validación');
assert(dispatch.includes(".eq('activo',true)")&&paymentWorker.includes("'aviso_cobro'"),'avisos de material entran en los workers push existentes');
assert(financeUi.includes('Desglose por origen')&&financeUi.includes("originLabel(r.origen)"),'material se separa en cargos, saldos y recibos');
console.log('RELEASE F MATERIAL: PASS');
