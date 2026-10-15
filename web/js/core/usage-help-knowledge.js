export function normalizeHelpText(text=''){return String(text).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9 ]/g,' ').replace(/\s+/g,' ').trim();}
const stop=new Set(Object.keys({como:true,que:true,puedo:true,quiero:true,necesito:true,hacer:true,crear:true,dar:true,una:true,unos:true,unas:true,para:true,por:true,con:true,del:true,desde:true,donde:true,los:true,las:true,mis:true,esta:true,este:true,tengo:true,hay:true,cual:true,paso:true,pasos:true,activar:true,consultar:true,registrar:true,anadir:true,add:true,create:true,ver:true}));
const aliases={contratar:'contratacion',servicios:'servicio',planes:'plan',session:'sesion',sessions:'sesion',students:'alumno',student:'alumno',charge:'cargo',charges:'cargo',fees:'cargo',photo:'foto',account:'cuenta',seller:'seller',vendedor:'seller',products:'product',product:'product',producto:'product',subscription:'suscripcion',services:'servicio',event:'evento',events:'evento',sesiones:'sesion',clases:'sesion',clase:'sesion',alumnos:'alumno',socios:'alumno',socio:'alumno',nino:'alumno',ninos:'alumno',hijos:'familia',hijo:'familia',cuotas:'cargo',cuota:'cargo',cobro:'cargo',cobros:'cargo',cobrar:'cargo',cargos:'cargo',pagos:'pago',licencias:'licencia',grupos:'grupo',productos:'product',vender:'seller',perfiles:'perfil',marcas:'marca',federaciones:'federacion',sesion:'sesion',fotografia:'foto',fotografias:'foto',fotos:'foto',contrasena:'password'};
const words=text=>[...new Set(normalizeHelpText(text).split(' ').filter(x=>x.length>2&&!stop.has(x)).map(x=>aliases[x]||x))];
export function helpTopicAllowed(topic,context={}){
 const role=context.role==='familia'?'alumno':context.role;
 return !topic.roles?.length||topic.roles.includes('todos')||topic.roles.includes(role);
}
export function selectHelpTopics(guides=[],query='',context={},limit=3){
 const tokens=words(String(query).slice(0,1500));if(!tokens.length)return [];
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
export function usageHelpVisible(context={}){
 if(context.initial===true)return true;
 if(!context.userId)return false;
 if(context.kind==='club')return ['direccion','coordinacion','secretaria','economia','comunicacion','monitor'].includes(context.role);
 return context.kind==='profile'&&['marca','federacion'].includes(context.type);
}
export function usageHelpAiEligible(context={}){
 if(!usageHelpVisible(context))return false;
 if(!context.userId)return false;
 if(context.kind==='club')return ['direccion','coordinacion','secretaria','economia'].includes(context.role);
 return context.kind==='profile'&&['marca','federacion'].includes(context.type);
}
export function usageHelpContextKey(context={}){return [context.userId||'guest',context.tenantRef||'public',context.role||'',context.type||'',context.verified===true?'verified':'',context.initial===true?'initial':''].join(':');}
export function usageOutputCap(planLimit){const value=Number(planLimit);return Math.min(600,Number.isFinite(value)&&value>0?Math.floor(value):500);}

export function resolveUsageHelpContext(session,workspace,route='',initial=false){
 if(!session?.id)return {kind:'public',initial:true,route};
 if(initial&&!session.support_mode)return {kind:'public',initial:true,userId:session.id,route};
 if(session.support_mode||session.platform_legal_required===true||session.birth_date_required===true)return {kind:'public',userId:session.id,route};
 if(session.club_id&&session.scope!=='kombax'&&session.scope!=='platform-admin')return {kind:'club',userId:session.id,tenantRef:`club:${session.club_id}`,type:'club',name:session.club?.nombre||'Club',role:session.rol,route};
 if(workspace?.profileId)return {kind:'profile',userId:session.id,tenantRef:`profile:${workspace.profileId}`,type:workspace.type,name:workspace.name,verified:workspace.verified===true,modules:workspace.modules||[],route};
 return {kind:'public',userId:session.id,name:'KOMBAX',route};
}
