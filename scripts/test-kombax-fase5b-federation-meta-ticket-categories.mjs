import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=async p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const [fed,inst,events,repos,social]=await Promise.all([
 'web/js/modules/federation-licenses.js','web/js/modules/instagram-integration.js','web/js/modules/kombax-events.js','web/js/core/repositories.js','web/js/modules/kombax-social.js'
].map(read));
let pass=0;const ok=(cond,message)=>{assert.ok(cond,message);pass++};
// This is a static/contract regression suite, not a live checkout/OAuth test.
ok(fed.includes('federationContext(profileId)'),'only authorized federation RPC');
ok(fed.includes("c.has('federation.licenses.read')"),'role-gated filters');
ok(fed.includes("c.has('federation.federates.read')"),'role-gated federates');
ok(fed.includes('federationLicenseCsv(rows)'),'export helper exists');
ok(fed.includes('/^[=+@-]/'),'formula injection guarded');
ok(fed.includes("const rows=filterFederationRows()"),'filtered export');
ok(fed.includes('limitado')||fed.includes('límite de 500'),'pagination limitation disclosed');
ok(fed.includes('federation.team.manage'),'team ACL unchanged');
ok(fed.includes('privacyNotice()'),'privacy context unchanged');
ok(repos.includes('app_kombax_event_ticket_categories_public_r266'),'real public RPC');
ok(repos.includes('app_kombax_event_ticket_categories_r265'),'real management RPC');
ok(repos.includes('app_kombax_event_ticket_category_save_r265'),'real write RPC');
ok(repos.includes('ticket_category_id:String(options.ticket_category_id)'),'Stripe payload includes category');
ok(events.includes('openEventTicketCategories(event)'),'management editor');
ok(events.includes("'Borrador / no vendible'")||events.includes('Borrador / no vendible'),'draft state disclosed');
ok(events.includes('EVENT_TICKET_CATEGORY_LIMIT')===false,'front does not fabricate backend limit errors');
ok(events.includes('No se han podido verificar los tipos de entrada'),'safe RPC failure');
ok(events.includes('categories.some(c=>Number(c.remaining)>0)'),'sold-out status');
ok(events.includes('category&&quantity>Number(category.remaining)'),'local capacity guard');
ok(events.includes('repos.payments.checkout(\'event_ticket\',event.id,quantity,category?'),'uses tier at checkout');
ok(events.includes('order.ticket_tier_name'),'ticket snapshot shows tier');
ok(events.includes('ticketQrPayload(ticket)'),'QR unchanged');
ok(events.includes('ticket_tier_entry_point'),'tier entry point printed');
ok(events.includes('ticket_tier_instructions'),'tier instructions printed');
ok(events.includes('ticket_tier_color||order?.ticket_accent'),'tier accent');
ok(inst.includes('instagramCaptionLinks'),'link extraction');
ok(inst.includes('data-instagram-open-social'),'upload/link existing Social post route');
ok(inst.includes('post.autor_id!==identity.id'),'ownership gate');
ok(inst.includes("action:'publish',social_id:identity.id,post_id:post.id,confirm:true"),'server publishes only posted image with confirmation');
ok(inst.includes('En el feed de Instagram estos enlaces normalmente no son clicables'),'link behavior disclosed');
ok(inst.includes('preview')||inst.includes('Imagen asociada a esta publicación'),'preview image');
ok(social.includes('publishPostToInstagram(post'),'existing Social integration preserved');
for(const p of ['js/modules/federation-licenses.js','js/modules/kombax-events.js','js/modules/instagram-integration.js','js/core/repositories.js']){
 const [web,dist,android]=await Promise.all([`web/${p}`,`dist/${p}`,`android/app/src/main/assets/www/${p}`].map(read));
 ok(web===dist,`${p} dist synchronized`);ok(web===android,`${p} android synchronized`);
}
console.log(`PASS ${pass}/${pass} static/contract & sync checks (F5B)`);
