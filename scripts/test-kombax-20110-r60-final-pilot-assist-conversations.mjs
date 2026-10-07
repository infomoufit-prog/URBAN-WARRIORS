import { readFile, stat } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
import { resources } from '../web/js/i18n/resources.js';
const copy=resources.es;
const root=resolve(import.meta.dirname,'..');
const read=rel=>readFile(resolve(root,rel),'utf8');
const [app,social,showcase,customer,hub,supportPrivacy,tabs,stab,hero,m253,m254,edge,repos]=await Promise.all([
  read('web/js/app.js'),read('web/js/modules/kombax-social.js'),read('web/js/modules/showcase.js'),read('web/js/modules/customer-operations.js'),read('web/js/modules/managed-profile-hub.js'),read('web/js/modules/support-privacy.js'),read('web/js/ui/conversation-ui.js'),read('web/css/kombax-ui-stabilization-r60.css'),read('web/css/kombax-brand-heroes.css'),read('supabase/migrations/253_kombax_pilot_management_assist_r60.sql'),read('supabase/migrations/254_kombax_support_guided_management_split_r60.sql'),read('supabase/functions/kombax-assist-r38/index.ts'),read('web/js/core/repositories.js')
]);
const assetNames=['hero-assist.webp','hero-migrations.webp','assistant-avatar.webp','chat-empty.webp'];
const assetOk=(await Promise.all(assetNames.map(async n=>(await stat(resolve(root,'web/assets/assist',n))).size>10000))).every(Boolean);
const checks=[
  ['unified conversation route exists',/conversations:renderKombaxConversations/.test(app)&&/conversations:'conversations'/.test(app)&&copy.navigation.routes.conversations==='Conversaciones KOMBAX'],
  ['formal Support has its own full route',/support:renderKombaxSupportHome/.test(app)&&/support:'support'/.test(app)&&copy.navigation.routes.support==='Soporte KOMBAX'&&/\['conversations','support','workspace','resources','guides','consulting','training'\]\.forEach\(x=>allowed\.add\(x\)\)/.test(app)],
  ['Social messages leave the Social feed layer',/location\.hash='#conversations'/.test(social)&&/renderKombaxConversations/.test(social)],
  ['Showcase interest routes to conversation layer',/kombax_conversation_channel','showcase'/.test(showcase)&&/#conversations/.test(showcase)],
  ['conversation shell exposes exactly four isolated channels and excludes Support',/Social/.test(tabs)&&/Showcase/.test(tabs)&&/Assist/.test(tabs)&&/Migrations/.test(tabs)&&!/Soporte/.test(tabs)&&!/onSupport/.test(tabs)],
  ['all four approved Assist/Migrations visuals are local assets',assetOk],
  ['Assist hero and Migrations hero are wired',/hero-assist\.webp/.test(customer)&&/hero-migrations\.webp/.test(customer)],
  ['robot avatar is used in conversation without the full generated chat artwork',/assistant-avatar\.webp/.test(customer)&&/kx-assist-welcome-avatar/.test(customer)&&!/chat-empty\.webp/.test(customer)],
  ['Assist is management AI for Club Federation Brand',/Club, Federación, Marca, Competidor o Profesional/.test(customer)&&/t\('assist.home.heroBody'\)/.test(customer)&&/contexto autorizado/.test(copy.assist.home.heroBody)],
  ['formal Support is separate from management AI',/t\('assist.home.notSupport'\)/.test(customer)&&copy.assist.home.notSupport==='KOMBAX Assist no es Soporte KOMBAX'&&/Atención técnica y formal/.test(customer)],
  ['formal Support exposes privacy security and child-safety channels',/PRIVACY_EMAIL/.test(customer)&&/SECURITY_EMAIL/.test(customer)&&/CHILD_SAFETY_EMAIL/.test(customer)&&/canal humano/i.test(supportPrivacy)],
  ['formal Support is email-first and KOMBAX controls guided/human escalation',/primero atendemos el caso por correo/i.test(customer)&&/puede habilitar este chat guiado/i.test(customer)&&/Combots puede asignar asistencia humana/i.test(customer)&&!/Solicitar verificación \/ revisión humana/.test(customer)],
  ['guided Support cannot self-activate',/SUPPORT_CHAT_ACTIVATION_REQUIRED/.test(m253)&&/guided_chat_requires_activation/.test(m254)&&/activation_owner','KOMBAX_SUPPORT'/.test(m254)],
  ['guided Support status is customer-safe and separate',/app_kombax_support_guided_status_r60/.test(m254)&&/supportGuidedStatus/.test(repos)&&/openKombaxSupportChat/.test(customer)],
  ['Management is a new direct category rather than replacement Support',/v_ticket\.category='MANAGEMENT'/.test(m254)&&/v_ticket\.category not in \('MIGRATION','MANAGEMENT'\)/.test(m254)],
  ['Management monthly allowance is independent from guided Support counters',/reserve_management_for_ticket/.test(m254)&&/c\.channel='CHAT'/.test(m254)&&/management-ticket:/.test(m254)&&/reserve_assistance_for_ticket/.test(m254)],
  ['frontend exposes monthly conversations and per-conversation message limits',/conversaciones disponibles este mes/.test(customer)&&/messagesPerConversation/.test(customer)&&/mensajes tuyos por conversación/.test(customer)],
  ['backend exposes plan message limits to UI',/messages_per_conversation/.test(m254)&&/max_turns_per_general_case/.test(m254)&&/max_turns_per_migration_case/.test(m254)],
  ['management direct-profile hub is available to Federation and Brand',/assist_management/.test(hub)&&/managementAssistBanner/.test(hub)],
  ['backend enforces org authorization and Brand access without Brand migrations',/org_assist_access_allowed/.test(m253)&&/v_type='marca'/.test(m253)&&/migration_access_allowed/.test(m253)],
  ['AI management context is read-only and compact',/management_context/.test(m253)&&/authorized_read_only_snapshot/.test(m253)&&/SOLO LECTURA/.test(edge)],
  ['AI Support prompt is distinct from management and Migrations',/SUPPORT_GUIDED_INSTRUCTIONS/.test(edge)&&/No eres KOMBAX Assist de gestión/.test(edge)&&/MIGRATION_INSTRUCTIONS/.test(edge)&&/MANAGEMENT_INSTRUCTIONS/.test(edge)],
  ['AI sends legal privacy security matters to human Support',/privacidad@kombax\.es/.test(edge)&&/seguridad@kombax\.es/.test(edge)&&/childsafety@kombax\.es/.test(edge)&&/revisión humana/i.test(edge)],
  ['history deletion separates Management from Support and Migrations',/v_mode='management'/.test(m254)&&/v_mode='support'/.test(m254)&&/v_mode='migration'/.test(m254)&&/requestClearHistory\('management'/.test(customer)],
  ['premium chat shell has safe-area sticky composer',/\.kx-assist-composer-sticky/.test(stab)&&/var\(--uw-safe-bottom\)/.test(stab)&&/\.kx-conversation-channels/.test(stab)],
  ['formal Support has responsive dedicated visual layer',/\.kx-support-main-hero/.test(stab)&&/\.kx-support-chat-locked/.test(stab)&&/\.kx-ai-chat-head\.support/.test(stab)],
  ['Social hero final master preserves right-weighted composition without zoom crop',/SOCIAL HERO NO-CROP MASTER/.test(hero)&&/object-fit:cover!important/.test(hero)&&/object-position:68% top!important/.test(hero)&&/transform:none!important/.test(hero)],
  ['mobile bottom navigation remains hidden',/\.bottom-nav\{display:none!important\}/.test(stab)],
];
for(const [name,ok] of checks){assert.equal(ok,true,name);console.log(`PASS ${name}`)}
console.log(`OK ${checks.length}/${checks.length} R60 pilot final · Assist + Migrations + Support guided + Conversations`);
