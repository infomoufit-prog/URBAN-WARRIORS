import {state} from '../core/state.js';
import {repos} from '../core/repositories.js';
import {esc} from '../core/utils.js';
import {getLocale} from '../i18n/index.js';
import {localizeSystemText} from '../i18n/legacy-runtime.js';
import {resolveUsageHelpContext,helpSmallTalk,helpQuestionIntent,helpSafeHistory,helpConversationTopics,helpAudienceAllowed,selectHelpTopics,helpTopicAllowed,usageHelpVisible,usageHelpAiEligible,usageHelpContextKey} from '../core/usage-help-knowledge.js';
import {usageWorkspaceContext,openUsageWorkspaceModule} from './personal-navigation.js';
const L=value=>localizeSystemText(value,getLocale());
const avatar='./assets/assist/assistant-avatar.webp';
let installed=false,root=null,context={},key='',epoch=0,opened=false,catalog=null,quota=null,credits=null,ticketId='',question='',pending=null,busy=false,channel='',conversation=[],questionHistory=[],getClubRoutes=()=>[];

function current(){const initial=Boolean(document.querySelector('[data-kx-usage-help-initial],.kx-type-picker,[data-kombax-view="profiles"],[data-kombax-view="identity-intro"],[data-kombax-view="member-family-intro"]'));return resolveUsageHelpContext(state.session,usageWorkspaceContext(),state.route,initial);}
function sync(){
 const next=current(),nextKey=usageHelpContextKey(next);context=next;
 if(!usageHelpVisible(context))opened=false;
 if(nextKey!==key){key=nextKey;epoch++;quota=null;credits=null;channel='';conversation=[];questionHistory=[];ticketId='';question='';pending=null;busy=false;if(opened){renderPanel();loadQuota();}}
 if(!document.getElementById('kx-usage-help-root'))mount();
 root.hidden=!usageHelpVisible(context);
 if(!opened){root.querySelector('#kx-usage-help-panel').hidden=true;root.querySelector('.kx-usage-help-launcher').setAttribute('aria-expanded','false');}
}
function mount(){
 root=document.createElement('div');root.id='kx-usage-help-root';root.className='kx-usage-help';
 root.innerHTML=`<button type="button" class="kx-usage-help-launcher" aria-controls="kx-usage-help-panel" aria-expanded="false"><img src="${avatar}" alt=""><span>${esc(L('¿Necesitas ayuda?'))}</span></button><section id="kx-usage-help-panel" class="kx-usage-help-panel" role="dialog" aria-modal="false" aria-label="${esc(L('Ayuda KOMBAX'))}" hidden></section>`;
 document.body.appendChild(root);root.querySelector('.kx-usage-help-launcher').addEventListener('click',()=>{opened?close():open();});
 if(opened)renderPanel();
}
function close(){opened=false;root.querySelector('#kx-usage-help-panel').hidden=true;const button=root.querySelector('.kx-usage-help-launcher');button.setAttribute('aria-expanded','false');button.focus();}
async function open(){sync();if(!usageHelpVisible(context))return;opened=true;const panel=root.querySelector('#kx-usage-help-panel');if(panel.dataset.helpEpoch!==String(epoch))renderPanel();else panel.hidden=false;root.querySelector('.kx-usage-help-launcher').setAttribute('aria-expanded','true');const captured=epoch;quotaLine();
 try{if(!catalog)catalog=await loadGuideCatalog();if(captured===epoch){suggest();root.querySelector('textarea')?.focus();}}catch{if(captured===epoch)message(L('No se pudo cargar la guía. Puedes contactar con Soporte.'),'assistant');}
 loadQuota();
}
function renderPanel(){
 const panel=root?.querySelector('#kx-usage-help-panel');if(!panel)return;
 panel.dataset.helpEpoch=String(epoch);panel.hidden=false;panel.innerHTML=`<header><img src="${avatar}" alt=""><div><strong>${esc(L('Ayuda KOMBAX'))}</strong><small>${esc(context.name||'KOMBAX')} · ${esc(L('Tu ayuda en KOMBAX'))}</small></div><button type="button" class="icon-btn" data-help-close aria-label="${esc(L('Cerrar'))}">×</button></header><div class="kx-help-thread" role="log" aria-live="polite" aria-relevant="additions"></div><p class="kx-help-status" data-help-status role="status" aria-live="polite" hidden></p><div class="kx-help-suggestions"></div><form><label for="kx-help-question">${esc(L('Escribe tu pregunta'))}</label><textarea id="kx-help-question" rows="2" maxlength="1500" enterkeyhint="send" aria-describedby="kx-help-keyboard" required placeholder="${esc(L('Por ejemplo: ¿qué es una cuota?'))}"></textarea><small id="kx-help-keyboard">${esc(L('Enter para enviar · Mayús+Enter para otra línea'))}</small><small class="kx-help-followup-hint">${esc(L('¿Te falta algo? Dime qué parte necesitas aclarar o escribe «necesito más ayuda».'))}</small><div><button type="submit" class="btn btn-primary">${esc(L('Enviar'))}</button></div></form><footer><button type="button" data-help-new>${esc(L('Nueva conversación'))}</button><a href="mailto:soporte@kombax.es">${esc(L('Contactar con Soporte'))}</a></footer>`;
 panel.querySelector('[data-help-close]').addEventListener('click',close);panel.onkeydown=e=>{if(e.key==='Escape'){e.preventDefault();close();}};
 panel.querySelector('textarea').addEventListener('keydown',event=>{if(event.key==='Enter'&&!event.shiftKey&&!event.isComposing&&event.keyCode!==229){event.preventDefault();if(!busy)panel.querySelector('form').requestSubmit();}});
 panel.querySelector('form').addEventListener('submit',e=>{e.preventDefault();answer();});
 panel.querySelector('[data-help-new]').addEventListener('click',()=>{if(busy)return;ticketId='';pending=null;question='';conversation=[];questionHistory=[];renderPanel();suggest();quotaLine();});
 message(L('Hola. ¿Qué te gustaría saber sobre KOMBAX?'),'assistant');suggest();quotaLine();
}
function message(text,role='assistant',html=''){
 conversation=helpSafeHistory([...conversation,{role,content:String(text)}]);
 const thread=root.querySelector('.kx-help-thread'),article=document.createElement('article');article.className=`kx-help-message ${role}`;
 article.innerHTML=`<small>${esc(role==='user'?L('Tú'):L('Ayuda KOMBAX'))}</small><div>${esc(text)}</div>${html}`;thread.appendChild(article);thread.scrollTop=thread.scrollHeight;return article;
}
function suggest(){
 if(!catalog)return;
 const queries=context.kind==='club'?(['alumno','familia'].includes(context.role)?['Mis clases','Mis cuotas','Comunicaciones del club']:['Crear una sesión','Añadir un alumno','Registrar un cargo']):context.kind==='profile'?(['marca','federacion'].includes(context.type)?['Editar foto y banner','Activar servicios','Showcase y vendedor']:context.type==='competidor'?['Editar foto y banner','Disponibilidad','Descubrir eventos']:context.type==='profesional'?['Editar foto y banner','Acreditaciones','Activar servicios']:['Editar foto y banner','Explorar Social','Descubrir eventos']):context.userId?['Crear una identidad','Explorar Social','Descubrir eventos']:['Crear una cuenta','Recuperar contraseña','Seleccionar identidad'];
 const box=root.querySelector('.kx-help-suggestions');box.hidden=Boolean(question);box.innerHTML=queries.map(q=>`<button type="button" class="btn btn-ghost btn-sm" data-help-query="${esc(q)}">${esc(L(q))}</button>`).join('');
 box.querySelectorAll('[data-help-query]').forEach(button=>button.addEventListener('click',()=>{root.querySelector('textarea').value=button.dataset.helpQuery;answer();}));
}
function guideAction(topic){
 if(!helpTopicAllowed(topic,context))return false;
 if(context.kind==='club')return topic.route&&getClubRoutes().includes(topic.route);
 return context.kind==='profile'&&topic.module&&(context.modules||[]).includes(topic.module);
}
function showTopic(topic){
 const allowed=guideAction(topic),steps=(topic.steps||[]).map(step=>`<li>${esc(L(step))}</li>`).join('');
 const rules=(topic.rules||[]).length?`<details class="kx-help-notes"><summary>${esc(L('Detalles que conviene revisar'))}</summary><ul>${topic.rules.map(rule=>`<li>${esc(L(rule))}</li>`).join('')}</ul></details>`:'';
 const article=message(L(topic.title),'assistant',`<ol data-guide-full>${steps}</ol><div data-guide-tutorial hidden></div><button type="button" class="btn btn-ghost btn-sm" data-guide-mode>${esc(L('Guiarme paso a paso'))}</button>${!helpTopicAllowed(topic,context)?`<p>${esc(L('Esta función requiere otro rol. Consulta con la administración.'))}</p>`:''}${rules}${allowed?`<button type="button" class="btn btn-ghost btn-sm" data-help-open="${esc(topic.id)}">${esc(L('Ir a esa pantalla'))}</button>`:''}`);
 let guided=false,step=0;
 const mode=article.querySelector('[data-guide-mode]'),tutorial=article.querySelector('[data-guide-tutorial]'),full=article.querySelector('[data-guide-full]');
 const draw=()=>{full.hidden=guided;tutorial.hidden=!guided;mode.textContent=L(guided?'Ver guía completa':'Guiarme paso a paso');if(!guided)return;tutorial.innerHTML=`<small>${esc(L('Paso'))} ${step+1} ${esc(L('de'))} ${topic.steps.length}</small><p>${esc(L(topic.steps[step]))}</p><div><button type="button" class="btn btn-ghost btn-sm" data-guide-prev ${step===0?'disabled':''}>${esc(L('Anterior'))}</button><button type="button" class="btn btn-ghost btn-sm" data-guide-next ${step===topic.steps.length-1?'disabled':''}>${esc(L('Siguiente'))}</button></div>`;tutorial.querySelector('[data-guide-prev]').onclick=()=>{step=Math.max(0,step-1);draw()};tutorial.querySelector('[data-guide-next]').onclick=()=>{step=Math.min(topic.steps.length-1,step+1);draw()};};
 mode.addEventListener('click',()=>{guided=!guided;draw();});
 const button=[...root.querySelectorAll(`[data-help-open="${topic.id}"]`)].at(-1);button?.addEventListener('click',()=>{if(!guideAction(topic))return;close();if(context.kind==='club')window.dispatchEvent(new CustomEvent('kx-club-route',{detail:{route:topic.route}}));else Promise.resolve(openUsageWorkspaceModule(topic.module)).catch(()=>message(L('No he podido abrir esa pantalla. Puedes acceder desde el menú de tu espacio.')));});
}
function showChoices(topics){
 if(!topics.length)return;
 const article=root.querySelector('.kx-help-thread article:last-child');
 article.insertAdjacentHTML('beforeend',`<details class="kx-help-related"><summary>${esc(L('Otras opciones relacionadas'))}</summary><div class="kx-help-choices">${topics.slice(0,3).map(topic=>`<button type="button" class="btn btn-ghost btn-sm" data-help-topic="${esc(topic.id)}">${esc(L(topic.title))}</button>`).join('')}</div></details>`);
 article.querySelectorAll('[data-help-topic]').forEach(button=>button.addEventListener('click',()=>{const topic=topics.find(x=>x.id===button.dataset.helpTopic);if(!topic||busy)return;question=topic.title;message(L(topic.title),'user');showTopic(topic);quotaLine();}));
}
function audienceContext(){return {...context,...(quota?.audience||{}),paid:channel==='paid',premium:channel==='paid'&&quota?.audience?.premium===true};}
function relatedGuide(article,topics){
 const topic=topics.find(t=>helpAudienceAllowed(t,audienceContext()));if(!topic)return;
 const button=document.createElement('button');button.type='button';button.className='btn btn-ghost btn-sm';button.textContent=L('Ver guía relacionada');
 button.addEventListener('click',()=>{if(busy||!helpAudienceAllowed(topic,audienceContext()))return;button.disabled=true;showTopic(topic);});article.appendChild(button);
}
function localReply(text,topics){
 const intent=helpQuestionIntent(text);let topic=topics[0];
 if(!topic){message(L('Cuéntame un poco más sobre tu duda para poder orientarte.'));return;}
 const detail=selectHelpTopics((topic.explanations||[]).map(x=>({...topic,title:x.title,keywords:x.keywords,concept:x.meaning,steps:x.steps,rules:[...(topic.rules||[]),...x.checks]})),text,audienceContext(),1)[0];
 if(detail)topic=detail;
 if(intent==='procedure'){showTopic(topic);return;}
 const explanation=intent==='purpose'?(topic.purpose||topic.concept):topic.concept;
 const reply=message(explanation?L(explanation):L('La guía recoge la información disponible sobre esta función. Puedes abrirla aquí para revisarla.'));
 relatedGuide(reply,[topic,...topics.slice(1)]);
}
async function loadGuideCatalog(){
 let response=await fetch('./assets/guides/usage-help-master-r278.json?v=r278');
 if(!response.ok)response=await fetch('./assets/guides/usage-help-r272.json?v=r275-natural');
 if(!response.ok)throw Error('guide_unavailable');return (await response.json()).guides;
}
async function answer(){
 sync();if(busy)return;const input=root.querySelector('textarea'),text=String(input?.value||'').trim().slice(0,1500);if(!text)return;
 const captured=epoch;questionHistory=helpSafeHistory(conversation);question=text;message(question,'user');input.value='';root.querySelector('.kx-help-suggestions').hidden=true;busy=true;quotaLine();
 try{
  await new Promise(resolve=>requestAnimationFrame(resolve));
  const greeting=helpSmallTalk(question);if(greeting){if(captured===epoch)message(L(greeting));return;}
  // Resolve entitlement before choosing AI or guide. A catalog hit no longer bypasses conversation.
  if(context.userId)await loadQuota();if(captured!==epoch)return;
  if(!catalog){try{catalog=await loadGuideCatalog();}catch{}}
  if(captured!==epoch)return;
  const topics=helpConversationTopics(catalog||[],question,audienceContext(),questionHistory,4);
  busy=false;quotaLine();
  if(canUseAi()){const answered=await askAi({quiet:true});if(captured!==epoch||answered)return;}
  localReply(question,topics);
 }catch{if(captured===epoch)message(L('No he podido consultar la información ahora. Tu pregunta sigue aquí; puedes intentarlo de nuevo.'));}
 finally{if(captured===epoch){busy=false;quotaLine();}}
}
async function loadQuota(){
 if(!opened||!context.userId)return;const ref=context.tenantRef,captured=epoch;
 try{
  if(usageHelpAiEligible(context)){
   const feature=await repos.customerOps.usageHelpStatus(ref);
   if(feature?.usage_help!=='r272'||feature.ai_configured!==true)throw Error('usage_help_unavailable');
   if(captured!==epoch)return;
   if(feature.ai_allowed===true){const [a,c]=await Promise.all([repos.customerOps.allowance(ref),repos.customerOps.aiCredits(ref)]);if(captured!==epoch)return;channel='paid';quota={...a,audience:feature.audience};credits=c;quotaLine();return;}
  }
  const free=await repos.customerOps.freeHelpStatus(ref);if(captured!==epoch)return;
  channel='free';quota=free?.version==='r274'&&free.configured===true?{allowance_remaining:free.remaining,audience:free.audience}:{unavailable:true};credits=null;quotaLine();
 }catch{if(captured===epoch){quota={unavailable:true};quotaLine();}}
}
function canUseAi(){
 const remaining=Number(quota?.allowance_remaining),available=Number(credits?.available);
 return Boolean(context.userId)&&Boolean(quota)&&!quota.unavailable&&(channel==='free'?remaining>0:channel==='paid'&&credits?.trial!==true&&(Boolean(ticketId)||remaining>0)&&available>0);
}
function quotaLine(){
 if(!root||!opened)return;
 const available=Number(credits?.available);
 const status=root.querySelector('[data-help-status]');status.hidden=!busy;status.textContent=busy?L('Preparando respuesta…'):'';root.querySelector('.kx-help-thread').setAttribute('aria-busy',String(busy));

 let balance=root.querySelector('[data-help-balance]');
 if(channel==='paid'&&credits&&Number.isFinite(available)){
  if(!balance){balance=document.createElement('details');balance.dataset.helpBalance='';balance.className='kx-help-notes';root.querySelector('footer').before(balance);}
  const expanded=balance.open,monthly=Number(credits.plan_total);
  balance.innerHTML=`<summary>${esc(L('Créditos del mes'))}: ${esc(String(available))} ${esc(L('disponibles'))}</summary><p>${Number.isFinite(monthly)?`${esc(L('Asignación mensual'))}: ${esc(String(monthly))}. `:''}${esc(L('Saldo compartido entre Ayuda, Assist y Migrations de este espacio.'))}</p>`;balance.open=expanded;
 }else balance?.remove();

 root.querySelector('form button[type="submit"]').disabled=busy;root.querySelector('[data-help-new]').disabled=busy;
}
async function askAi({quiet=false}={}){
 if(busy||!question||!context.userId)return;
 if(!canUseAi())return false;
 const captured=epoch,ref=context.tenantRef,requestQuestion=question;busy=true;quotaLine();
 try{
  if(!pending||pending.question!==requestQuestion)pending={question:requestQuestion,id:crypto.randomUUID()};
  if(channel==='free'){
   const response=await repos.customerOps.freeHelpChat(requestQuestion,pending.id,ref,questionHistory);
   if(captured!==epoch)return;const reply=message(response.message||L('No hay respuesta disponible. Contacta con Soporte.'));relatedGuide(reply,helpConversationTopics(catalog||[],requestQuestion,audienceContext(),questionHistory,2));pending=null;await loadQuota();return true;
  }
  if(channel!=='paid')return;
  if(!ticketId){const created=await repos.customerOps.createTicket({category:'MANAGEMENT',subject:`Ayuda KOMBAX · ${context.name||context.type}`,module:'assist',tenant_ref:ref});if(captured!==epoch)return;ticketId=created.ticket_id;if(!ticketId)throw Error('case_unavailable');}
  if(!pending||pending.question!==requestQuestion)pending={question:requestQuestion,id:crypto.randomUUID()};
  const response=await repos.customerOps.chat(ticketId,requestQuestion,'usage',pending.id,questionHistory);
  if(captured!==epoch)return;const reply=message(response.message||L('No hay respuesta disponible. Contacta con Soporte.'));relatedGuide(reply,helpConversationTopics(catalog||[],requestQuestion,audienceContext(),questionHistory,2));pending=null;await loadQuota();return true;
 }catch(error){if(captured===epoch){if(error?.status===502||(error?.status===409&&error.message==='turn_retry_required'))pending=null;if(!quiet)message(L('Ahora mismo no puedo ampliar la respuesta. Puedes seguir con la guía, volver a intentarlo o escribir a Soporte. Tu pregunta sigue aquí.'));}}
 finally{if(captured===epoch){busy=false;quotaLine();}}
}
export function installUsageHelp({clubRoutes=()=>[]}={}){
 if(installed)return;installed=true;getClubRoutes=clubRoutes;
 const start=()=>{sync();const observer=new MutationObserver(records=>{if(records.every(r=>r.target.closest?.('#kx-usage-help-root')))return;requestAnimationFrame(sync);});const app=document.getElementById('app');if(app)observer.observe(document.body,{childList:true,subtree:true});window.addEventListener('hashchange',()=>requestAnimationFrame(sync));window.addEventListener('kombax:localechange',()=>{if(opened)renderPanel();const launcher=root?.querySelector('.kx-usage-help-launcher span');if(launcher)launcher.textContent=L('¿Necesitas ayuda?');});};
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
}
