import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read=path=>readFileSync(new URL(`../${path}`,import.meta.url),'utf8');
const specialists=read('web/js/core/assist-specialists.js');
const ui=read('web/js/modules/customer-operations.js');
const repo=read('web/js/core/repositories.js');
const fn=read('supabase/functions/kombax-assist-r38/index.ts');
const backend=read('web/js/core/backend.js');
const legal=read('web/js/modules/platform-legal.js');

for(const id of ['management','memberships','finance','stripe','events','showcase','marketing','federation']){
  assert.match(specialists,new RegExp(`id:'${id}'`));
  assert.match(fn,new RegExp(`\\b${id}:`));
}
assert.match(ui,/profileType==='marca'.*showcase_provider/);
assert.match(ui,/profileType==='federacion'.*federation/);
assert.match(ui,/8 ESPECIALIDADES/);
assert.match(repo,/chat:\(ticket_id,message,specialty='management'/);
assert.match(fn,/specialty==='stripe'/);
assert.match(fn,/Nunca solicites tarjeta, CVC, cuenta bancaria, documentos KYC/);
assert.match(fn,/directo y Stripe cobra sus tarifas a esa cuenta/);
assert.match(backend,/const active=await platformLegalStatus\(\)/);
assert.match(backend,/active\?\.terms_version\|\|PLATFORM_TERMS_VERSION/);
assert.match(legal,/Condiciones \$\{termsVersion\} · Privacidad \$\{privacyVersion\}/);
console.log('PASS R64.1 · aceptación legal dinámica · 8 especialidades Assist · Stripe seguro por organización');
