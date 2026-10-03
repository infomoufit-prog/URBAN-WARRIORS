import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const [cfg,gradle,activity,gateway,members,repos,social,app,m303,m304,m305,m306]=await Promise.all([
  read('web/config.js'),read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),
  read('web/js/modules/gateway.js'),read('web/js/modules/groups-members.js'),read('web/js/core/repositories.js'),read('web/js/modules/kombax-social.js'),read('web/js/app.js'),
  read('supabase/migrations/303_kombax_pilot_open_registration_no_code_r117.sql'),read('supabase/migrations/304_kombax_public_profiles_member_spectator_r117.sql'),read('supabase/migrations/305_kombax_pilot_easy_linking_elite_social_network_r117.sql'),read('supabase/migrations/306_kombax_elite_social_universal_public_profiles_r117.sql')
]);
const checks=[];const ok=(c,m)=>{checks.push([!!c,m]);if(!c)throw new Error(m)};
const currentBuild=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0);
const currentVersion=cfg.match(/version:\s*'([^']+)'/)?.[1];
ok(currentBuild>=20171&&Number(currentVersion?.match(/-r(\d+)/)?.[1])>=117,'build 20171+ / config monotonic');
const androidCode=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
ok(androidCode===currentBuild&&gradle.includes(`versionName '${currentVersion}'`),'Android versionCode/versionName monotonic');
ok(activity.includes('webView.restoreState(savedInstanceState)')&&activity.includes('webView.saveState(outState)')&&activity.includes('persistInternalUrl()'),'Android lifecycle state persistence');
ok(app.includes('renderClubSessionOrLegal({startAtHome:false})')&&app.includes("renderDirectProfileHub({onBack:renderGatewayRoot,pendingType:sessionStorage.getItem('kombax_pending_profile_type')||''})"),'club navigation restores and account login opens its space selector');
ok(gateway.includes('Alta directa sin código de invitación')&&!gateway.includes("name:'pilot_code'"),'pilot club UI no code');
ok(m303.includes("invite_code_required',false")&&m303.includes('PILOT_INVITE_CODES_DISABLED'),'pilot club backend no code');
ok(m304.includes('album_enabled')&&m304.includes("KOMBAX_SPECTATOR_ALBUM_DISABLED")&&m304.includes('publication_enabled'),'member/spectator public profile separation');
ok(m305.includes('app_kombax_club_link_request_r117')&&m305.includes('app_kombax_club_link_resolve_r117'),'direct member/family club authorization path');
ok(m305.includes('app_kombax_social_network_actor_allowed_v255')&&m305.includes('app_kombax_social_mis_perfiles_r117'),'Elite Social network actor independent of feed publish');
ok(m306.includes('Universal basic Elite Social public profiles')&&m306.includes("d.tipo in ('marca','federacion','media')")&&m306.includes('KOMBAX_SPECTATOR_ALBUM_DISABLED')===false,'universal basic Elite Social visibility keeps spectator album rule in prior guard');
ok(repos.includes('app_kombax_club_link_request_r117')&&repos.includes('resolveClubLink'),'frontend repositories linking');
ok(gateway.includes("value:'family'")&&gateway.includes('Solicitar autorización'),'member/family no-code request UX');
ok(members.includes('Autorizar miembro')&&members.includes('Autorizar acceso familiar'),'club approval UX');
ok(social.includes('publication_enabled')&&social.includes('publishProfiles'),'read/network profiles do not become feed publishers');
ok(gateway.includes("name:'fecha_nacimiento'")&&gateway.includes('fecha_nacimiento:v.fecha_nacimiento')&&repos.includes('activateMember:({fecha_nacimiento=null')&&repos.includes('fecha_nacimiento:fecha_nacimiento||null'),'private DOB age gate for member chat');
console.log(`OK ${checks.length}/${checks.length} · KOMBAX R117 build 20171+ Pilot Hotfix regression`);
