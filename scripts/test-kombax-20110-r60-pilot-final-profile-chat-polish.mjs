import fs from 'node:fs';

const read=p=>fs.readFileSync(p,'utf8');
const cssHero=read('web/css/kombax-brand-heroes.css');
const cssPremium=read('web/css/kombax-premium.css');
const cssUi=read('web/css/kombax-ui-stabilization-r60.css');
const customerOps=read('web/js/modules/customer-operations.js');
const social=read('web/js/modules/kombax-social.js');
const network=read('web/js/modules/social-network.js');
const profile=read('web/js/modules/public-profile.js');
const repos=read('web/js/core/repositories.js');
const edge=read('supabase/functions/kombax-history-delete-r60/index.ts');
const migration=read('supabase/migrations/255_kombax_pilot_profile_chat_network_media_fix_r60.sql');
const cleanup=read('supabase/migrations/257_kombax_pilot_public_qa_cleanup_r60.sql');

const checks=[];
function check(name,ok){checks.push([name,Boolean(ok)]);console.log(`${ok?'PASS':'FAIL'} · ${name}`)}

check('Social hero adds portrait headroom',/kx-brand-hero-social \.kx-brand-hero-media\{height:47%/.test(cssHero));
check('Social hero remains right-weighted',/object-position:70% 27%!important/.test(cssHero));
check('Assist/Migrations empty chat uses avatar shell',customerOps.includes('kx-assist-welcome-avatar-shell'));
check('Assist/Migrations chat no longer embeds chat-empty artwork',!customerOps.includes('assets/assist/chat-empty.webp'));
check('Assistant avatar remains available for messages',customerOps.includes('function assistantAvatar()'));
check('Public profile mobile action rail is a bounded grid',cssPremium.includes('.kx-public-profile-modal .modal-actions{display:grid!important'));
check('Add-to-network becomes full-width first row',cssPremium.includes('#kx-public-network{grid-column:1/-1'));
check('Mi red uses dedicated network profiles',repos.includes('app_kombax_social_network_profiles_v255'));
check('Network request uses network actor path',network.includes('repos.kombaxSocial.networkProfiles()')&&repos.includes('app_kombax_relation_request_v255'));
check('Mi red removes native Perfil select',!social.includes('id="kx-relation-profile"'));
check('Mi red identity control only appears when multiple identities exist',social.includes('networkProfiles.length>1')&&social.includes('kx-network-identities'));
const actorBody=migration.split('create or replace function public.app_kombax_social_network_actor_allowed_v255')[1]?.split('$$;')[0]||'';
check('Verified member network actor is independent of social.publish',actorBody.includes("sp.sujeto_tipo='miembro'")&&!actorBody.includes("'social.publish'"));
check('Network relation list uses dedicated actor permission',migration.includes('app_kombax_social_network_actor_allowed_v255(p_social_id)'));
check('Public profile posts RPC returns media metadata',migration.includes('app_kombax_social_profile_posts_v255')&&migration.includes('media_scope text'));
check('Repository enriches profile post media URLs',repos.includes('readSocialProfilePosts')&&repos.includes('media_cover_url'));
check('Public profile renders video/image activity media',profile.includes('function postMedia(p)')&&profile.includes('<video')&&profile.includes('kx-profile-post-media'));
check('Public activity media supports immersive fullscreen',profile.includes('bindProfilePostMedia')&&profile.includes('openImmersiveMedia'));
check('Showcase message moderation is icon-only',social.includes("isShowcase()?`<button type=\"button\" class=\"kx-message-report kx-message-options\"")&&social.includes("icon('more'"));
check('Showcase message UI does not repeat visible report label',cssPremium.includes('Showcase moderation remains available'));
check('History delete Edge accepts management alias',edge.includes("requestedMode==='assist'||requestedMode==='management'?'assist':null"));
check('History delete backend keeps Support separate from Assist deletion',migration.includes("v_mode='assist' and t.category='MANAGEMENT'"));
check('History delete continues preserving allowance accounting',migration.includes('storage_paths')&&edge.includes('allowance_preserved:true'));
check('Public QA demo identities are hidden for pilot',cleanup.includes("'FEDERACIÓN KOMBAX QA · DEMO'")&&cleanup.includes('set visible=false'));
check('Internal network actor helper is not exposed as standalone RPC',cleanup.includes('revoke execute on function public.app_kombax_social_network_actor_allowed_v255(uuid) from authenticated')); 

const failed=checks.filter(([,ok])=>!ok);
console.log(`\nR60 Pilot Final Profile/Chat Polish: ${checks.length-failed.length}/${checks.length}`);
if(failed.length){console.error('Failed:',failed.map(([n])=>n).join(', '));process.exit(1)}
