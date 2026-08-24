import fs from 'node:fs';
const root=new URL('../',import.meta.url);
const read=p=>fs.readFileSync(new URL(p,root),'utf8');
const migration=read('supabase/migrations/140_kombax_owner_support_mode_20077.sql');
const admin=read('web/js/modules/platform-admin.js');
const app=read('web/js/app.js');
const shell=read('web/js/ui/components.js');
const repo=read('web/js/core/repositories.js');
const checks=[
  ['support helper',migration.includes('app_kombax_support_entity_v140')&&migration.includes('app_kombax_support_club_v140')],
  ['no fake membership',migration.includes('Deliberately do not add Owner')&&migration.includes('if not public.app_kombax_support_club_v140')],
  ['club central guards',migration.includes('create or replace function public.tiene_rol_club')&&migration.includes('app_puede_gestionar_ciclo_v038')],
  ['professional support',migration.includes('app_kombax_support_direct_profile_v140')&&migration.includes("then 'owner_support'")],
  ['showcase support',migration.includes('app_kombax_showcase_puede_gestionar_v045')],
  ['support audit',migration.includes('app_kombax_support_audit_v140')],
  ['admin support button',admin.includes('kx-admin-enter-support')&&admin.includes('uw-owner-support-enter')],
  ['app support handler',app.includes('enterOwnerSupportMode')&&app.includes('exitOwnerSupportMode')],
  ['support banner',shell.includes('MODO SOPORTE KOMBAX')&&shell.includes('support-mode-exit')],
  ['repository audit',repo.includes('supportAudit:')]
];
let fail=0;for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} ${name}`);if(!ok)fail++;}if(fail)process.exit(1);
