import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {helpConversationTopics,helpIsFollowup} from '../supabase/functions/_shared/usage-help-dialogue-r280.js';
import {usageHelpContent,USAGE_HELP_INSTRUCTIONS} from '../supabase/functions/_shared/usage-help-guide.ts';
import catalog from '../supabase/functions/_shared/usage-help-catalog.json' with {type:'json'};
import supplements from '../supabase/functions/_shared/usage-help-supplements-r278.json' with {type:'json'};
const guides=[...catalog.guides,...supplements.articles.map(s=>({...catalog.guides.find(g=>g.id===s.guide_id),title:s.title,keywords:s.keywords,summary:s.meaning}))];
const club={kind:'club',type:'club',role:'direccion',paid:true,premium:true,verified:true,userId:'qa'};
let n=0;const ok=(v,m)=>{assert.ok(v,m);n++};
for(const query of ['y después','ya lo hice','no veo el botón','¿dónde está?','¿puedes poner un ejemplo?']){
 ok(helpIsFollowup(query),'short follow-up recognized '+query);
 const rows=helpConversationTopics(guides,query,club,[{role:'user',content:'Cómo creo una sesión'}],4);
 ok(rows.some(r=>r.id==='sessions'),'known session retained '+query);
}
for(const [query,id]of [['La mensualidad del alumno','charge-create'],['Registrar un abono parcial','payment-record'],['Quiero publicar en mi escaparate','showcase-publish'],['Colores de cinturones','catalog']])ok(helpConversationTopics(guides,query,club,[],5).some(r=>r.id===id),'natural synonym '+query);
const duplicates=helpConversationTopics(guides,'Cuotas, pagos y recibos del alumno',club,[],5);ok(new Set(duplicates.map(g=>g.id)).size===duplicates.length,'different tasks before duplicate guide variants');ok(duplicates.length>1,'compound question keeps multiple relevant tasks');
const switched=helpConversationTopics(guides,'Otra pregunta: conectar Instagram',club,[{role:'user',content:'Crear una cuota'}],3);ok(switched[0]?.id==='social-publish','explicit change of topic');
const named=helpConversationTopics(guides,'¿Y eso de Instagram?',club,[{role:'user',content:'Crear una cuota'}],3);ok(named[0]?.id==='social-publish','named feature is not trapped in old context');
const publicRows=helpConversationTopics(guides,'y después',{kind:'public'},[{role:'user',content:'Crear una cuota'}],4);ok(!publicRows.some(r=>r.id==='charge-create'),'history never grants private guide access');
const payload=usageHelpContent('Y después',{},'es',club,[{role:'user',content:'Cómo creo una sesión'}])[0].text;ok(payload.includes('Sesiones'),'backend source retrieval carries follow-up topic');
for(const term of ['no vuelvas a la presentación','no supongas un fallo de permisos','No asegures haber navegado'])ok(USAGE_HELP_INSTRUCTIONS.includes(term),'answer precision instruction '+term);
const assist=readFileSync('supabase/functions/kombax-assist-r38/index.ts','utf8');ok(assist.includes('PRECISIÓN CONVERSACIONAL'),'Assist improved without frontend change');ok(assist.includes('Responde EXCLUSIVAMENTE JSON')&&assist.includes('if(migration){const parsed=cleanJsonText(output)'),'Migrations JSON output parsed under existing contract');ok(assist.includes('app_kombax_assist_turn_reserve_v227')&&assist.includes('store:false'),'billing ledger and disabled model storage preserved');
console.log('PASS '+n+' backend-only dialogue checks: follow-ups, synonyms, topic changes, multiple tasks, permissions and agent contracts');
