import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import vm from 'node:vm';

const root = resolve(import.meta.dirname, '..');
const memory = new Map();
globalThis.window = globalThis;
globalThis.localStorage = {
  getItem: (key) => memory.has(key) ? memory.get(key) : null,
  setItem: (key, value) => memory.set(key, String(value)),
  removeItem: (key) => memory.delete(key)
};
globalThis.FileReader = class {};
window.UW_CONFIG = {
  demoMode: true,
  clubSlug: 'urban-warriors',
  supabase: { enabled: false, url: '', anonKey: '' }
};

for (const file of ['web/js/demo-data.js', 'web/js/data-store.js']) {
  vm.runInThisContext(await readFile(resolve(root, file), 'utf8'), { filename: file });
}

const store = window.UW_STORE;
await store.init();
await store.loginDemo('family');
const d = store.getData();
const month = new Date().toISOString().slice(0, 7);

// Limpieza y dos cuotas hermanas pendientes para comprobar agrupación familiar.
d.notificaciones = [];
d.historial_avisos_cuota = [];
d.pagos = d.pagos.filter((payment) => !['c1', 'c5'].includes(payment.cuota_id));
for (const fee of d.cuotas.filter((item) => ['c1', 'c5'].includes(item.id))) {
  fee.periodo = `${month}-01`;
  fee.estado = 'pendiente';
  fee.avisos_pausados = false;
  fee.avisos_pausados_hasta = null;
}
d.settings.dias_aviso = [1, 4, 8, 11, 14];
await store.persist();

const result1 = await store.processPaymentReminders(`${month}-01`);
const first = d.notificaciones.find((item) => item.datos?.aviso_numero === 1);
if (!first || first.datos.cuotas.length !== 2) throw new Error('El aviso 1 no agrupó las dos mensualidades familiares.');
if (result1.avisos_generados !== 2) throw new Error('El historial debe registrar una fila por cuota avisada.');

const duplicate = await store.processPaymentReminders(`${month}-01`);
if (duplicate.avisos_generados !== 0) throw new Error('El motor de avisos no es idempotente.');

// El usuario comunica el pago de una cuota: se pausa y queda en validación.
await store.submitPayment({ cuota_id: 'c5', socio_id: 's5', importe: 35, fecha: `${month}-02`, metodo: 'bizum', referencia: 'TEST', justificante_url: 'data:test' });
if (d.cuotas.find((item) => item.id === 'c5').estado !== 'pendiente_validacion') throw new Error('La cuota comunicada no quedó pendiente de validación.');

const result2 = await store.processPaymentReminders(`${month}-04`);
const second = d.notificaciones.find((item) => item.datos?.aviso_numero === 2);
if (!second || second.datos.cuotas.length !== 1 || second.datos.cuotas[0] !== 'c1') throw new Error('El segundo aviso incluyó una cuota con pago comunicado.');
if (result2.avisos_generados !== 1) throw new Error('El segundo aviso debía registrar una sola cuota.');

// Secretaría valida el justificante y la cuota queda pagada.
const payment = d.pagos.find((item) => item.cuota_id === 'c5');
await store.loginDemo('admin');
await store.validatePayment(payment.id, 'validado');
if (d.cuotas.find((item) => item.id === 'c5').estado !== 'pagada') throw new Error('La validación no cerró la cuota.');

// Pausa temporal y reactivación automática al expirar.
await store.pauseFeeAlerts('c1', 'Acuerdo con la familia', `${month}-07`);
await store.processPaymentReminders(`${month}-08`);
if (d.cuotas.find((item) => item.id === 'c1').avisos_pausados) throw new Error('La pausa temporal no caducó.');
const third = d.notificaciones.find((item) => item.datos?.aviso_numero === 3);
if (!third) throw new Error('No se generó el aviso 3 tras caducar la pausa.');

console.log('OK: agrupación familiar, 5 días configurables, idempotencia, justificante, validación y pausa temporal.');
