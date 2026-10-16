import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import {createHash} from 'node:crypto';
import master from '../supabase/functions/_shared/usage-help-master-r278.json' with {type:'json'};
import supplements from '../supabase/functions/_shared/usage-help-supplements-r278.json' with {type:'json'};
import catalog from '../supabase/functions/_shared/usage-help-catalog.json' with {type:'json'};
import {usageHelpContent} from '../supabase/functions/_shared/usage-help-guide.ts';import {helpAudienceAllowed,helpQuestionIntent} from '../web/js/core/usage-help-knowledge.js';
let n=0;const ok=(v,m)=>{assert.ok(v,m);n++};const ids=new Map(catalog.guides.map(g=>[g.id,g]));
ok(master.articles.length===67&&supplements.articles.length===45,'67 core topics plus 45 specialized cases');
for(const a of [...master.articles,...supplements.articles]){
 ok(ids.has(a.guide_id),'existing permission parent '+a.title);ok(a.review_status==='source_reviewed','review flag '+a.title);
 for(const s of a.sources){const file=readFileSync(s.path);ok(createHash('sha256').update(file).digest('hex')===s.sha256,'source freshness '+s.path);ok(s.line>0&&s.line<=file.toString().split('\n').length,'source line '+s.path);}
}
const contexts=[{}, {kind:'public',userId:'qa'}, {kind:'profile',type:'espectador',verified:false,paid:false,userId:'qa'}, {kind:'profile',type:'marca',verified:true,paid:true,premium:true,userId:'qa'}, {kind:'club',type:'club',role:'alumno',paid:false,userId:'qa'}, {kind:'club',type:'club',role:'direccion',paid:true,premium:true,userId:'qa'}];
for(const c of contexts)for(const a of supplements.articles){const text=usageHelpContent(a.title,{},'es',c,[])[0].text;const raw=text.split('Guías publicadas: ')[1].split('\nHilo reciente')[0];const sources=JSON.parse(raw);ok(raw.length<=7000,'bounded valid JSON');if(!helpAudienceAllowed(ids.get(a.guide_id),c))ok(!sources.some(s=>s.title===a.title),'no inherited permission bypass '+a.title);ok(!text.includes('Owner Operations')&&!text.includes('Pilot Intelligence'),'private Owner corpus absent');}
const club=contexts.at(-1);const text=usageHelpContent('Mi alumno hace karate y kickboxing en varios grupos',{},'es',club,[])[0].text;ok(text.includes('Varias disciplinas')||text.includes('Grupos de mañana'),'specific multi-activity question retrieves useful sources');
const inventory=JSON.parse(readFileSync('docs/AUDITORIA_MODULOS_R278.json','utf8'));ok(inventory.modules.length===72,'entire module inventory');ok(inventory.modules.every(m=>m.sha256&&m.exports&&m.repositories),'traceable inventory, not an end-to-end claim');
for(const [question,expected] of [
 ['No me deja cambiar la tarifa del alumno','tariff-change'],
 ['Tengo dos hijos y quiero inscribirlos','students'],
 ['Como registro un pago parcial de una cuota','payment-record'],
 ['Varios coordinadores en el mismo equipo','team'],
 ['El alumno entrena por la mañana y por la tarde en dos grupos','groups'],
 ['Quiero recuperar un documento archivado','documents'],
 ['Foto de perfil y banner en mi album','social-media'],
 ['No puedo crear una sesoin','sessions'],
 ['Que diferencia hay entre Assist y Migrations','assist-data']
]){const meta={};usageHelpContent(question,{},'es',{...club,verified:true},[],[],[],meta);ok(meta.guide_ids.includes(expected),'natural wording retrieves '+expected+': '+question);}
for(const q of ['No me deja guardar la cuota','No puedo publicar','No funciona el chat','No llega la invitación'])ok(helpQuestionIntent(q)==='troubleshooting','diagnose rather than prescribe '+q);
for(const [q,intent] of [['Hola, me puedes explicar qué es una cuota','definition'],['Quería saber cómo crear una sesión','procedure'],['Me gustaría saber para qué sirve Assist','purpose'],['Explícame qué son los grupos','definition'],['Hola, no me deja publicar','troubleshooting']])ok(helpQuestionIntent(q)===intent,'natural introductory wording: '+q);
const enriched=usageHelpContent('No puedo guardar una sesión',{},'es',club,[])[0].text;ok(enriched.includes('troubleshooting')&&enriched.includes('prerequisites'),'diagnosis receives source-backed prerequisites and checks');
console.log('PASS '+n+' master knowledge checks: sources, freshness, 112 topics, six audience layers, Owner isolation, retrieval and bounded context');
