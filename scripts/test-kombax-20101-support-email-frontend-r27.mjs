import fs from 'node:fs';
const read=p=>fs.readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const files={
  support:read('web/js/modules/support-privacy.js'),
  admin:read('web/js/modules/admin.js'),
  gateway:read('web/js/modules/gateway.js'),
  index:read('web/index.html'),
  sw:read('web/service-worker.js')
};
const checks=[];const ok=(name,cond)=>checks.push([name,Boolean(cond)]);
ok('canonical support email preserved',files.support.includes("SUPPORT_EMAIL='soporte@kombax.es'"));
ok('support center keeps direct mailto',files.support.includes('href="mailto:${SUPPORT_EMAIL}'));
ok('profile quick row exposes email address',files.support.includes('Contacto general: ${SUPPORT_EMAIL}')); // R60 keeps canonical Support email visible while Assist stays separate
ok('profile quick row has Escribir correo CTA',files.support.includes('Escribir correo</a>'));
ok('profile quick row keeps privacy access CTA',files.support.includes('Privacidad y acceso</button>'));
ok('club settings note exposes clickable mailto',files.admin.includes('Soporte ordinario: <a href="mailto:${SUPPORT_EMAIL}'));
ok('global profile hub imports canonical support email',files.gateway.includes("import { SUPPORT_EMAIL, openSupportPrivacyCenter } from './support-privacy.js';"));
ok('global profile hub surfaces support email action',files.gateway.includes('${SUPPORT_EMAIL}</a><button class="btn btn-ghost" id="kx-account-support"'));
ok('R27 web cache bust',files.index.includes('20101r27')&&!files.index.includes('20101r26'));
ok('R27 service worker cache bust',files.sw.includes('media-r27')&&!files.sw.includes('media-r26'));
let failed=0;for(const [name,pass] of checks){console.log(`${pass?'PASS':'FAIL'} · ${name}`);if(!pass)failed++;}
console.log(`R27 ${checks.length-failed}/${checks.length}`);process.exit(failed?1:0);
