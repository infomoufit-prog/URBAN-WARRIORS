import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {setLocale} from '../web/js/i18n/index.js';
import {humanError} from '../web/js/core/utils.js';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');
const checks=[];
const ok=(name,fn)=>{fn();checks.push({name,status:'PASS'});console.log(`✓ ${name}`)};

ok('client errors are localized before render',()=>{
  const utils=read('web/js/core/utils.js');
  assert.match(utils,/localizeSystemText\(humanErrorSpanish\(error\), getLocale\(\)\)/);
  setLocale('en',{allowSupported:true,persist:false});
  assert.equal(humanError(new Error('invalid login credentials')),'The email or password is incorrect.');
  assert.equal(humanError(new Error('KOMBAX_WEIGHT_OUT_OF_RANGE')),'Enter a valid weight between 15 and 300 kg.');
  setLocale('es',{allowSupported:true,persist:false});
});

ok('checkout and refunds propagate user_locale',()=>{
  const repos=read('web/js/core/repositories.js');
  assert.match(repos,/stripe-checkout[^\n]+user_locale:getLocale\(\)/);
  assert.match(repos,/stripe-refund[^\n]+user_locale:payload\.user_locale\|\|getLocale\(\)/);
  assert.match(repos,/event_batch[^\n]+user_locale:getLocale\(\)/);
});

ok('Stripe Checkout localizes KOMBAX copy and does not force Spanish',()=>{
  const s=read('supabase/functions/stripe-checkout/index.ts');
  for(const locale of ['es','en','fr','pt','it','de','th','fil'])assert.match(s,new RegExp(`\\b${locale}:\\{ticket:`));
  assert.match(s,/normalizeLocale\(body\.user_locale\)/);
  assert.match(s,/'locale':STRIPE_LOCALE\[userLocale\]\|\|'auto'/);
  assert.doesNotMatch(s,/'locale'\s*:\s*['"]es['"]/);
  assert.match(s,/copy\.fee/);assert.match(s,/copy\.soldBy/);assert.match(s,/copy\.payment/);
});

ok('refund system reasons are locale-aware',()=>{
  const s=read('supabase/functions/stripe-refund/index.ts');
  for(const locale of ['es','en','fr','pt','it','de','th','fil'])assert.match(s,new RegExp(`\\b${locale}:\\{batch:`));
  assert.match(s,/normalizeLocale\(body\?\.user_locale\)/);
  assert.match(s,/body\?\.reason\|\|copy\.batch/);
  assert.match(s,/body\?\.reason\|\|copy\.event/);
});

ok('push finance and session system copy uses recipient preferred_locale',()=>{
  const s=read('supabase/functions/notification-dispatch/index.ts');
  assert.match(s,/select\('id,preferred_locale'\)/);
  assert.match(s,/FINANCE_COPY/);assert.match(s,/SESSION_COPY/);
  assert.match(s,/SESSION_TYPES=new Set\(\['clase','reserva_sesion','sesion_cambio'\]\)/);
  for(const locale of ['es','en','fr','pt','it','de','th','fil'])assert.match(s,new RegExp(`\\b${locale}:\\{title:`));
});

ok('payment reminders, invite email, reports and AI receive locale',()=>{
  const reminders=read('supabase/functions/payment-reminders/index.ts');
  const invite=read('supabase/functions/invite-email/index.ts');
  const report=read('supabase/functions/finance-report/index.ts');
  const assist=read('supabase/functions/kombax-assist-r38/index.ts');
  assert.match(reminders,/preferred_locale/);assert.match(reminders,/FINANCE_COPY/);
  assert.match(invite,/body\?\.user_locale|body\.user_locale/);assert.match(invite,/COPY\[locale\]/);
  assert.match(report,/body\.user_locale/);assert.match(report,/PDF_COPY\[locale\]/);
  assert.match(assist,/body\?\.user_locale/);assert.match(assist,/localeInstruction\(userLocale/);
});

ok('cron/API transport errors use language-neutral stable codes',()=>{
  const cron=read('supabase/functions/_shared/cron-security.ts');
  const recurring=read('supabase/functions/finance-recurring/index.ts');
  const reminders=read('supabase/functions/payment-reminders/index.ts');
  const notifications=read('supabase/functions/notification-dispatch/index.ts');
  const report=read('supabase/functions/finance-report/index.ts');
  for(const s of [cron,recurring,reminders,notifications,report]){
    assert.doesNotMatch(s,/error\s*:\s*['"](?:JSON no válido|Método no permitido|Formato no admitido|Solicitud demasiado grande|No autorizado|club_id no válido|date no válida|Error interno|report_id no valido)['"]/);
  }
});

ok('six Supabase Auth templates support all 8 locales via preferred_locale',()=>{
  for(const name of ['confirmation','recovery_otp','magic_link_otp','invite','reauthentication_otp','password_changed']){
    const s=read(`supabase/auth_templates/${name}_20124_i18n.html`);
    assert.match(s,/preferred_locale/);for(const locale of ['en','fr','pt','it','de','th','fil'])assert.match(s,new RegExp(`eq \\.Data\\.preferred_locale \"${locale}\"`));
  }
});

const report={generated_at:new Date().toISOString(),status:'PASS',checks};
fs.writeFileSync(path.join(root,'docs/i18n/remediation/KOMBAX_I18N_SYSTEM_CHANNEL_AUDIT_RB02.json'),JSON.stringify(report,null,2)+'\n');
console.log(`\nSystem channel audit: PASS · ${checks.length}/${checks.length}`);
