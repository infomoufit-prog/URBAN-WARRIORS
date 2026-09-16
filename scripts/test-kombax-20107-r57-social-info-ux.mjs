import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const read=async p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const [social,css,cfg,sw,gradle,main,debug,aab,events,showcase,profile,repos]=await Promise.all([
  read('web/js/modules/kombax-social.js'),read('web/css/kombax-premium.css'),read('web/config.js'),read('web/service-worker.js'),
  read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),read('scripts/android-debug-qa.mjs'),read('scripts/android-play-bundle.mjs'),
  read('web/js/modules/kombax-events.js'),read('web/js/modules/showcase.js'),read('web/js/modules/public-profile.js'),read('web/js/core/repositories.js')
]);
const ok=(name,value)=>{assert.ok(value,name);console.log('PASS',name)};
const sha=x=>createHash('sha256').update(x).digest('hex');
const feed=(social.match(/function renderFeedView\(\)\{[\s\S]*?\n\}/)||[''])[0];
const info=(social.match(/function openSocialInfoPanel\(\)\{[\s\S]*?\n\}/)||[''])[0];
const currentBuild=Number((cfg.match(/build:\s*(\d+)/)||[])[1]||0),isHistoricalR57=currentBuild===20107;
ok('R57 baseline is preserved in build 20107 or later',currentBuild>=20107);
ok('service worker is R57 or later',isHistoricalR57?(sw.includes('uw2-build-20107')&&sw.includes('20107-r57')):/uw2-build-20\d{3}/.test(sw));
ok('Android is R57 or later',isHistoricalR57?(/versionCode\s+20107/.test(gradle)&&/2\.0\.0-rc\.13-r57-qa-freeze/.test(gradle)&&main.includes('KOMBAXRevision/r57-qa-freeze')&&main.includes('KOMBAXApp/2.0.0-rc.13/20107')):/versionCode\s+20\d{3}/.test(gradle));
ok('R57 Android artifact names or later release naming',isHistoricalR57?(debug.includes('KOMBAX_20107_R57_QA_FREEZE_DEBUG.apk')&&aab.includes('KOMBAX_20107_R57_QA_FREEZE_GOOGLE_PLAY.aab')):(!debug.includes('KOMBAX_20107_R57_QA_FREEZE_DEBUG.apk')&&!aab.includes('KOMBAX_20107_R57_QA_FREEZE_GOOGLE_PLAY.aab')));
ok('Social exposes compact information trigger',social.includes('function socialInfoTrigger()')&&social.includes('id="kx-social-info"')&&social.includes('aria-label="Información de KOMBAX Social"'));
ok('information trigger is bound to a real panel',social.includes("document.getElementById('kx-social-info')?.addEventListener('click',openSocialInfoPanel)"));
ok('information panel contains active identity',info.includes('${identitySwitcher()}')&&social.includes('IDENTIDAD ACTIVA'));
ok('information panel contains topic moderation policy',info.includes('${socialTopicPolicyNotice()}'));
ok('information panel contains full publication rules',info.includes('${socialRulesCard()}'));
ok('feed no longer renders identity switcher inline',!feed.includes('${identitySwitcher()}'));
ok('feed no longer renders large topic policy inline',!feed.includes('${socialTopicPolicyNotice()}'));
ok('feed no longer renders rules card inline',!feed.includes('${socialRulesCard()}'));
ok('feed keeps founders launch promotion',feed.includes('${competitorFoundersPromo()}'));
ok('feed keeps existing publish action unchanged',feed.includes('+ Publicar con multimedia'));
ok('composer keeps small contextual moderation reminder',social.includes('kx-social-publish-topic-hint')&&social.includes('<b>Solo contenido de combate.</b>'));
ok('composer keeps publishing identity context',social.includes('PUBLICAR EN KOMBAX')&&social.includes('${esc(identityLabel(current))}'));
ok('identity can still be changed from information panel',info.includes("setActiveIdentity(activeIdentityId)")&&info.includes('renderKombaxSocial()'));
ok('all principal Social views use secondary information action',[
  "pageHeader('Actualidad profesional'","pageHeader('Perfiles públicos'","pageHeader('Mensajes KOMBAX'","pageHeader('Guardados'","pageHeader('Mi red'","pageHeader('Seguridad y alcance'"
].every(marker=>social.includes(marker))&&(social.match(/socialHeaderActions\(/g)||[]).length>=7);
ok('information control remains compact on mobile',css.includes('.kx-social-info-trigger{flex:0 0 42px!important')&&css.includes('@media(max-width:620px){.kombax-social-page .page-actions'));
ok('information panel resets old inline card margins',css.includes('.kx-social-info-panel .kx-identity-context')&&css.includes('.kx-social-info-panel .kx-social-topic-policy')&&css.includes('.kx-social-info-panel .kx-social-rules-card'));
ok('Events module historical hash only enforced on R57',!isHistoricalR57||sha(events)==='2bc0f20a14f84e2d8164d250de1ca03eeba484ebe31fff73a5df0624d3345549');
ok('Showcase historical hash only enforced on R57',!isHistoricalR57||sha(showcase)==='af769c24f454393515da9822077d62159953d263405178a7952edd6b8f0edbae');
ok('public profile historical hash only enforced on R57',!isHistoricalR57||sha(profile)==='8f48e786349b00a5ef59c4d4544c2a2ea94d163cdad6803af3d49ba43ec6b5eb');
ok('repositories historical hash only enforced on R57',!isHistoricalR57||sha(repos)==='dfd0474ed65336208a66b620f85f842419fee19de54418edf072e9b2e6f3c4c4');
const migrations=await readdir(new URL('../supabase/migrations/',import.meta.url));
ok('R57 itself remains frontend-only; later migrations are allowed',!migrations.some(x=>/20107.*r57|r57.*20107/i.test(x)));
console.log('R57 Social information UX / QA freeze candidate: 25/25 PASS');
