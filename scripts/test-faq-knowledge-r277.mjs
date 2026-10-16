import assert from 'node:assert/strict';
import faq from '../supabase/functions/_shared/usage-help-faq-r277.json' with {type:'json'};
import catalog from '../supabase/functions/_shared/usage-help-catalog.json' with {type:'json'};
import {USAGE_HELP_INSTRUCTIONS,usageHelpContent} from '../supabase/functions/_shared/usage-help-guide.ts';
import {helpAudienceAllowed,normalizeHelpText} from '../supabase/functions/_shared/usage-help-knowledge.js';
let checks=0;const ok=(v,m)=>{assert.ok(v,m);checks++};
ok(faq.entries.length===200,'exactly 200 curated FAQ entries');
ok(new Set(faq.entries.map(f=>normalizeHelpText(f.question))).size===200,'200 distinct questions');
ok(new Set(faq.entries.map(f=>f.id)).size===200,'unique stable ids');
const guides=new Map(catalog.guides.map(g=>[g.id,g]));
for(const f of faq.entries){ok(guides.has(f.guide_id),'existing source '+f.id);ok(f.answer.length>20&&f.review_status==='curated','substantive reviewed answer '+f.id);}
const contexts=[{}, {kind:'public',userId:'qa'}, {kind:'club',type:'club',role:'alumno',userId:'qa',paid:false}, {kind:'club',type:'club',role:'monitor',userId:'qa',paid:true,premium:false}, {kind:'profile',type:'espectador',userId:'qa',paid:false,verified:false}, {kind:'profile',type:'marca',userId:'qa',paid:true,premium:true,verified:true}];
const sources=(q,c,h)=>{const text=usageHelpContent(q,{entity_type:c.type||'club'},'es',c,h)[0].text;const raw=text.split('Guías publicadas: ')[1].split('\nHilo reciente')[0];ok(raw.length<=7000,'source budget');return JSON.parse(raw)};
for(const c of contexts)for(const f of faq.entries){if(!helpAudienceAllowed(guides.get(f.guide_id),c)){const found=sources(f.question,c);ok(!found.some(x=>x.title===f.question),'FAQ cannot bypass parent audience '+f.id);}}
const premium={kind:'club',type:'club',role:'direccion',userId:'qa',paid:true,premium:true,verified:true};
ok(sources('¿Cómo creo una sesión?',premium).some(g=>g.title==='Sesiones y recurrencia'),'canonical session guide stays ahead of FAQ matches');
ok(sources('¿Qué es una cuota?',premium).some(g=>g.concept?.includes('importe')),'definitions retain sourced concepts');
const recovered=usageHelpContent('¿Y eso para qué sirve?',{},'es',premium,undefined,[{role:'user',content:'¿Qué es una cuota de PRIVATE_PERSON?'},{role:'assistant',content:'PRIVATE_FINANCES'},{role:'user',content:'¿Y eso?'},{role:'assistant',content:'Dime a qué te refieres'},{role:'user',content:'¿Eso?'}])[0].text;
ok(recovered.includes('Tema anterior de la guía:'),'legacy follows topic across clarifications');
ok(!recovered.includes('PRIVATE_'),'legacy never replays private user or assistant history');
for(const followup of ['Necesito más ayuda','No lo entiendo','No me queda claro']){
 const content=usageHelpContent(followup,{},'es',premium,undefined,[{role:'user',content:'¿Qué es una cuota de PRIVATE_PERSON?'},{role:'assistant',content:'PRIVATE_FINANCES'}])[0].text;
 ok(content.includes('Tema anterior de la guía:')&&!content.includes('PRIVATE_'),'continuation keeps public topic without copying private history: '+followup);
}
const approved={guide_id:'charge-create',question:'¿Qué distingue un cargo?',answer:'ACLARACION_PUBLICADA_QA sobre el registro de un importe.',source_ref:'guide:charge-create',revision:1};
let m={};let text=usageHelpContent('¿Qué es un cargo?',{},'es',premium,[],[],[approved],m)[0].text;
ok(text.includes('ACLARACION_PUBLICADA_QA'),'approved lesson can enrich its allowed parent guide');
ok(m.guide_ids.includes('charge-create')&&m.reason==='covered','metadata contains topic ids only');
text=usageHelpContent('¿Qué es un cargo?',{},'es',{},[],[],[approved])[0].text;ok(!text.includes('ACLARACION_PUBLICADA_QA'),'approved lesson cannot bypass public layer');
text=usageHelpContent('¿Qué es un cargo?',{},'es',premium,[],[],[{...approved,guide_id:'NOT_ALLOWED'}])[0].text;ok(!text.includes('ACLARACION_PUBLICADA_QA'),'unmatched parent lesson ignored');
m={};usageHelpContent('Corrección: eso está mal',{},'es',premium,[],[],[],m);ok(m.reason==='correction'&&!('question' in m)&&!('answer' in m),'learning proposals copy no question or answer');
ok(USAGE_HELP_INSTRUCTIONS.includes('Si la respuesta solo cubre parte')&&USAGE_HELP_INSTRUCTIONS.includes('No añadas esta frase a todas'),'partial answers invite continuation without repetitive closing');
console.log('PASS '+checks+' FAQ count, uniqueness, source, audience, bounded retrieval and legacy context checks; no provider calls');
