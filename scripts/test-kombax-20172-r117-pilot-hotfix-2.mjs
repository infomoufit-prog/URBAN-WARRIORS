import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const [cfg,pkg,gradle,activity,app,gateway,backend,repos,m307,m308,health]=await Promise.all([
  read('web/config.js'),read('package.json'),read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),
  read('web/js/app.js'),read('web/js/modules/gateway.js'),read('web/js/core/backend.js'),read('web/js/core/repositories.js'),
  read('supabase/migrations/307_kombax_account_birthdate_member_entry_r117.sql'),read('supabase/migrations/308_kombax_birthdate_required_all_new_accounts_r117.sql'),read('supabase/functions/health/index.ts')
]);
const checks=[];const ok=(c,m)=>{checks.push([!!c,m]);if(!c)throw new Error(m)};
ok(cfg.includes('build: 20172')&&cfg.includes('r117-pilot-hotfix-2'),'build 20172/config');
ok(pkg.includes('2.0.0-rc.13-r117-pilot-hotfix-2'),'package version');
ok(/versionCode\s+20172/.test(gradle)&&gradle.includes("r117-pilot-hotfix-2"),'Android 20172');
ok(activity.includes('webView.restoreState(savedInstanceState)')&&activity.includes('webView.saveState(outState)'),'Android lifecycle continuity retained');
ok(app.includes('renderGlobalHome({onBack:renderGatewayRoot,restoreLast:!hasTransactionalEntry,autoMemberEntry:!hasTransactionalEntry})'),'restored KOMBAX session resolves established member automatically');
ok(gateway.includes('resolveEstablishedMemberEntry')&&gateway.includes("memberPublic?.membership_confirmed===true")&&gateway.includes("memberPublic?.publication_enabled===true"),'established member enters workspace directly');
ok(gateway.includes("name:'fecha_nacimiento',label:t('auth.registration.birthDate'),type:'date',required:true"),'DOB required in universal KOMBAX account signup');
ok(app.includes("adulto_fecha_nacimiento',label:tutor?'Fecha de nacimiento del adulto':'Fecha de nacimiento',type:'date',required:true"),'DOB required in club member/family account signup');
ok(backend.includes("fecha_nacimiento:dob,tipo_cuenta:'kombax_global'")&&backend.includes("Indica la fecha de nacimiento del titular de la cuenta."),'all signup paths transmit DOB');
ok(m307.includes('kombax_account_private_r117')&&m307.includes('app_kombax_account_age_context_r117'),'private reusable account age context');
ok(m308.includes('KOMBAX_ACCOUNT_BIRTH_DATE_REQUIRED')&&m308.includes('auth_signup_required'),'backend rejects new account without DOB');
ok(m308.includes('app_kombax_account_birthdate_set_r117')&&m308.includes('Never invent a date'),'legacy account age completion/backfill without invented DOB');
ok(gateway.includes("verify.fecha_nacimiento||state.session?.fecha_nacimiento||''"),'age-gated profile verification reuses signup DOB');
ok(repos.includes('app_kombax_club_link_request_r117')&&repos.includes('app_kombax_social_mis_perfiles_r117'),'easy linking and Elite Social retained');
ok(health.includes('build:20172')&&health.includes("'x-kombax-build':'20172'"),'health build marker 20172');
console.log(`OK ${checks.length}/${checks.length} · KOMBAX R117 build 20172 Pilot Hotfix 2`);
