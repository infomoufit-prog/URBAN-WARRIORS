import fs from 'node:fs';
const read=f=>fs.readFileSync(f,'utf8');
const migration=read('supabase/migrations/129_kombax_platform_legal_acceptance_20072.sql');
const backend=read('web/js/core/backend.js');
const gateway=read('web/js/modules/gateway.js');
const app=read('web/js/app.js');
const gate=read('web/js/modules/platform-legal.js');
const terms=read('web/terms.html');
const releaseGate=read('scripts/release-legal-gate.mjs');
for(const needle of ['kombax_platform_legal_acceptances_v129','app_kombax_platform_legal_status_v129','app_kombax_platform_legal_accept_v129']){
  if(!migration.includes(needle))throw new Error(`Migración legal 129 incompleta: ${needle}`);
}
if(!/revoke all on table public\.kombax_platform_legal_acceptances_v129 from public,anon,authenticated/i.test(migration))throw new Error('La tabla de aceptación legal no está cerrada al acceso directo.');
if(!migration.includes("tipo in ('terms','privacy_notice')"))throw new Error('Términos y aviso de privacidad deben quedar semánticamente separados.');
if(!backend.includes("platform_legal_required")||!backend.includes("acceptPlatformLegal"))throw new Error('Backend no aplica el gate legal a la sesión.');
if(!gateway.includes("showPlatformLegalGate")||!gateway.includes("terms.html")||!gateway.includes("privacy.html"))throw new Error('Alta global/gateway no presenta los documentos KOMBAX.');
if(!app.includes('renderClubSessionOrLegal')||!app.includes('showPlatformLegalGate'))throw new Error('Las cuentas de club no están protegidas por el gate global.');
if(!gate.includes('La lectura de la política de privacidad no se utiliza como consentimiento general'))throw new Error('El gate confunde información de privacidad con consentimiento.');
if(!terms.includes('Versión de condiciones: <strong>1.0.0</strong>'))throw new Error('Falta versión contractual 1.0.0.');
if(!releaseGate.includes("'web/terms.html'"))throw new Error('Release gate no inspecciona los Términos globales.');
if(/Mínimo 6 caracteres/.test(gateway)||/password\|\|''\)\.length<6/.test(gateway))throw new Error('Alta global mantiene mínimo de contraseña inferior a 8.');
console.log('KOMBAX 20072 platform legal acceptance: PASS');
