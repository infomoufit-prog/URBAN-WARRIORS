import fs from 'node:fs';

const app = fs.readFileSync('web/js/app.js', 'utf8');
const store = fs.readFileSync('web/js/data-store.js', 'utf8');
const sql = fs.readFileSync('supabase/migrations/008_audit_operational_v131.sql', 'utf8');

const checks = [
  ['alta directa de alumno', app.includes("store.createMember(payload)") && store.includes('async createMember(payload)') && sql.includes('app_guardar_socio')],
  ['edición de alumno', app.includes("store.updateMember(id, payload)") && store.includes('async updateMember(id, changes)')],
  ['grupos con horarios', app.includes('Grupo y horarios') && store.includes("app_guardar_grupo") && sql.includes('Hay horarios solapados')],
  ['preinscripciones', app.includes("form.id === 'enrollment-form'") && store.includes('async saveEnrollment(payload)')],
  ['publicaciones e imágenes', app.includes("form.id === 'communication-form'") && store.includes("storageUpload('club-public-media'")],
  ['material e imágenes', app.includes("form.id === 'material-form'") && store.includes("uploadPublicMedia(file")],
  ['tarifas y cuotas', app.includes("form.id === 'tariff-form'") && store.includes('async generateFees(period)')],
  ['pagos y justificantes', app.includes("form.id === 'payment-form'") && store.includes("storageUpload('justificantes-pago'")],
  ['notificaciones', app.includes("renderNotifications") && store.includes('async markNotificationRead')],
  ['sesión renovable', store.includes('async refreshSession()') && store.includes('ensureFreshSession')],
  ['confirmación y cierre', app.includes('function finishMutation')],
  ['auditoría de instalación', sql.includes('app_auditoria_operativa')]
];

const failed = checks.filter(([, ok]) => !ok);
if (failed.length) {
  console.error('FALLOS DE AUDITORÍA:');
  failed.forEach(([name]) => console.error(`- ${name}`));
  process.exit(1);
}
console.log(`OK: ${checks.length} circuitos operativos auditados estáticamente.`);
