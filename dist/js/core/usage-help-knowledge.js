export function normalizeHelpText(text=''){return String(text).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9 ]/g,' ').replace(/\s+/g,' ').trim();}
const stop=new Set(Object.keys({como:true,que:true,puedo:true,quiero:true,necesito:true,hacer:true,crear:true,dar:true,una:true,unos:true,unas:true,para:true,por:true,con:true,del:true,desde:true,donde:true,los:true,las:true,mis:true,esta:true,este:true,tengo:true,hay:true,cual:true,paso:true,pasos:true,activar:true,consultar:true,registrar:true,anadir:true,add:true,create:true,ver:true}));
const aliases={contratar:'contratacion',servicios:'servicio',planes:'plan',session:'sesion',sessions:'sesion',students:'alumno',student:'alumno',charge:'cargo',charges:'cargo',fees:'cargo',photo:'foto',account:'cuenta',seller:'seller',vendedor:'seller',products:'product',product:'product',producto:'product',subscription:'suscripcion',services:'servicio',event:'evento',events:'evento',sesiones:'sesion',clases:'sesion',clase:'sesion',alumnos:'alumno',socios:'alumno',socio:'alumno',nino:'alumno',ninos:'alumno',hijos:'familia',hijo:'familia',cuotas:'cargo',cuota:'cargo',cobro:'cargo',cobros:'cargo',cobrar:'cargo',cargos:'cargo',pagos:'pago',licencias:'licencia',grupos:'grupo',productos:'product',vender:'seller',perfiles:'perfil',marcas:'marca',federaciones:'federacion',sesion:'sesion',fotografia:'foto',fotografias:'foto',fotos:'foto',contrasena:'password'};
const words=text=>[...new Set(normalizeHelpText(text).split(' ').filter(x=>x.length>2&&!stop.has(x)).map(x=>aliases[x]||x))];
const vocabularies=new WeakMap();
export function helpSmallTalk(text){
 const value=normalizeHelpText(text);
 if(/^(hola|buenas|buenos dias|buenas tardes|buenas noches|hello|hi)$/.test(value))return 'Hola. ¿Qué te gustaría saber sobre KOMBAX?';
 if(/^(gracias|muchas gracias|perfecto gracias|thanks|thank you)$/.test(value))return 'De nada. Si necesitas otra cosa, seguimos por aquí.';
 return '';
}
function editDistance(a,b){
 const d=Array.from({length:a.length+1},()=>Array(b.length+1).fill(0));
 for(let i=0;i<=a.length;i++)d[i][0]=i;for(let j=0;j<=b.length;j++)d[0][j]=j;
 for(let i=1;i<=a.length;i++)for(let j=1;j<=b.length;j++){d[i][j]=Math.min(d[i-1][j]+1,d[i][j-1]+1,d[i-1][j-1]+(a[i-1]===b[j-1]?0:1));if(i>1&&j>1&&a[i-1]===b[j-2]&&a[i-2]===b[j-1])d[i][j]=Math.min(d[i][j],d[i-2][j-2]+1);}
 return d[a.length][b.length];
}
export function helpQueryTokens(guides,query){
 let vocabulary=vocabularies.get(guides);if(!vocabulary){vocabulary=new Set(guides.flatMap(g=>normalizeHelpText(`${g.title} ${g.keywords}`).split(' ')).concat(Object.keys(aliases)));vocabularies.set(guides,vocabulary);}
 return [...new Set(normalizeHelpText(String(query).slice(0,1500)).split(' ').filter(x=>x.length>2&&!stop.has(x)).map(token=>{
  if(vocabulary.has(token)||token.length<4)return aliases[token]||token;
  let best=token,distance=token.length>=8?2:1,tied=false;
  for(const candidate of vocabulary){if(Math.abs(candidate.length-token.length)>distance)continue;const next=editDistance(token,candidate);if(next<distance){best=candidate;distance=next;tied=false;}else if(next===distance){if(best===token){best=candidate;tied=false;}else if(candidate!==best)tied=true;}}
  const resolved=tied?token:best;return aliases[resolved]||resolved;
 }))];
}
export function helpTopicAllowed(topic,context={}){
 const role=context.role==='familia'?'alumno':context.role;
 return !topic.roles?.length||topic.roles.includes('todos')||topic.roles.includes(role);
}
const genericHelp=new Set(['account-create','account-login','identity-choose','social-explore','showcase-explore','events-explore']);
export function helpAudienceAllowed(topic,context={}){
 if(!helpTopicAllowed(topic,context))return false;
 if(genericHelp.has(topic.id))return true;
 if(topic.id==='identity-create')return Boolean(context.userId);
 if(!context.userId||context.kind==='public')return false;
 if(['finance-report','automation-prepare'].includes(topic.id))return context.premium===true;
 if(topic.id==='social-publish')return context.verified===true;
 if(['showcase-publish','events-create','profile-events','profile-showcase'].includes(topic.id))return context.verified===true&&context.paid===true;
 if(topic.scope==='club'&&topic.memberOnly!==true&&!['social','showcase','community','notifications','install','privacy'].includes(topic.id))return context.paid===true;
 if(['profile-brand','profile-federation','assist-data','migrations-import'].includes(topic.id))return context.paid===true;
 return true;
}
export function selectHelpTopics(guides=[],query='',context={},limit=3){
 guides=guides.filter(g=>helpAudienceAllowed(g,context));
 const tokens=helpQueryTokens(guides,query);if(!tokens.length)return [];
 const broadFinance=context.kind==='club'&&!['alumno','familia'].includes(context.role)&&/\b(finanza|finanzas|finance|finances)\b/.test(normalizeHelpText(query))&&!/\b(cargo|pago|tarifa|recibo|informe|automatizacion|deuda|charge|payment|report|receipt)\b/.test(normalizeHelpText(query));
 if(broadFinance){const priority=['finance','charge-create','payment-record','tariff-change','receipts','finance-report','automation-prepare','payment-validate','reminders'];return guides.filter(g=>g.category==='finance'&&helpTopicAllowed(g,context)&&g.memberOnly!==true).sort((a,b)=>priority.indexOf(a.id)-priority.indexOf(b.id)).slice(0,limit);}
 return guides.filter(g=>{
  if(g.requiredTerms?.length&&!g.requiredTerms.some(term=>normalizeHelpText(query).includes(term)))return false;
  if(g.scope==='club'&&context.kind!=='club')return false;
  if(g.scope==='profile'&&context.kind!=='profile')return false;
  if(g.types?.length&&!g.types.includes(context.type))return false;
  if(g.scope==='club'&&g.memberOnly!==undefined&&g.memberOnly!==['alumno','familia'].includes(context.role))return false;
  return true;
 }).map(g=>{const title=words(g.title),primary=words(`${g.title} ${g.keywords}`),secondary=words(`${g.summary} ${(g.steps||[]).join(' ')}`);const score=tokens.reduce((n,t)=>n+(title.includes(t)?8:primary.includes(t)?4:secondary.includes(t)?1:0),0);return {topic:g,score:score?score+(g.scope===context.kind?0.25:0):0};})
 .filter(x=>x.score>=4).sort((a,b)=>b.score-a.score||a.topic.id.localeCompare(b.topic.id)).slice(0,limit).map(x=>x.topic);
}
export function usageHelpVisible(){return true;}
export function usageHelpAiEligible(context={}){
 if(!usageHelpVisible(context))return false;
 if(!context.userId)return false;
 if(context.kind==='club')return ['direccion','coordinacion','secretaria','economia'].includes(context.role);
 return context.kind==='profile'&&['marca','federacion'].includes(context.type);
}
export function usageHelpContextKey(context={}){return [context.userId||'guest',context.tenantRef||'public',context.role||'',context.type||'',context.verified===true?'verified':'',context.initial===true?'initial':''].join(':');}
export function usageOutputCap(planLimit){const value=Number(planLimit);return Math.min(600,Number.isFinite(value)&&value>0?Math.floor(value):500);}

export function helpQuestionIntent(text=''){
 const q=normalizeHelpText(text).replace(/^(?:hola|buenas|buenos dias|buenas tardes)\s+/,'').replace(/^(?:(?:me puedes|puedes|podrias) (?:explicar|decir|contar)|(?:quiero|queria|necesito|me gustaria) (?:saber|entender)|explicame)\s+/,'');
 if(/\b(no (?:me )?(?:deja|puedo|funciona|guarda|aparece|llega|responde)|error|fallo|falla|atascad[oa]|bloquead[oa]|can t|cannot|not working)\b/.test(q))return 'troubleshooting';
 if(/^(?:y )?(?:(?:eso|esto|esa|ese) )?(?:para que|que utilidad|de que sirve|what is .+ for)/.test(q))return 'purpose';
 if(/^(?:y )?(?:que es|que son|que significa|a que se refiere|what is|what are|what does)/.test(q))return 'definition';
 if(/\b(diferencia|diferencias|comparar|versus|vs|difference)\b/.test(q))return 'comparison';
 if(/^(?:y )?(?:como|pasos|guiame|ensename|quiero crear|quiero anadir|crear|registrar|anadir|how)/.test(q))return 'procedure';
 return 'conversation';
}
export function helpSafeHistory(history){
 return (Array.isArray(history)?history:[]).slice(-4).filter(x=>x&&['user','assistant'].includes(x.role)&&typeof x.content==='string').map(x=>({role:x.role,content:x.content.replace(/\u0000/g,'').slice(0,600)}));
}
export function helpConversationTopics(guides,message,context,history=[],limit=4){
 if(helpIsFollowup(message))for(const previous of helpSafeHistory(history).filter(x=>x.role==='user').reverse()){
  const topic=selectHelpTopics(guides,previous.content,context,1)[0];
  if(topic)return selectHelpTopics(guides,`${message} ${topic.title}`,context,limit);
 }
 return selectHelpTopics(guides,message,context,limit);
}
export function helpIsFollowup(message=''){return /\b(eso|esto|esa|ese|lo anterior|it|that|this)\b/.test(normalizeHelpText(message))||/^(?:necesito mas ayuda|mas ayuda|no (?:lo )?entiendo|no (?:me )?queda claro|explicamelo|i need more help|i do not understand)$/.test(normalizeHelpText(message));}

export function resolveUsageHelpContext(session,workspace,route='',initial=false){
 if(!session?.id)return {kind:'public',initial:true,route};
 if(initial&&!session.support_mode)return {kind:'public',initial:true,userId:session.id,route};
 if(session.support_mode||session.platform_legal_required===true||session.birth_date_required===true)return {kind:'public',userId:session.id,route};
 if(session.club_id&&session.scope!=='kombax'&&session.scope!=='platform-admin')return {kind:'club',userId:session.id,tenantRef:`club:${session.club_id}`,type:'club',name:session.club?.nombre||'Club',role:session.rol,route};
 if(workspace?.profileId)return {kind:'profile',userId:session.id,tenantRef:`profile:${workspace.profileId}`,type:workspace.type,name:workspace.name,verified:workspace.verified===true,modules:workspace.modules||[],route};
 return {kind:'public',userId:session.id,name:'KOMBAX',route};
}
