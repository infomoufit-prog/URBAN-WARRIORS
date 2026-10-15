import {state} from '../core/state.js';
import {repos} from '../core/repositories.js';
import {esc} from '../core/utils.js';
import {getLocale} from '../i18n/index.js';
import {localizeSystemText} from '../i18n/legacy-runtime.js';
import {resolveUsageHelpContext,selectHelpTopics,helpTopicAllowed,usageHelpVisible,usageHelpAiEligible,usageHelpContextKey} from '../core/usage-help-knowledge.js';
import {usageWorkspaceContext,openUsageWorkspaceModule} from './personal-navigation.js';
const L=value=>localizeSystemText(value,getLocale());
const avatar='./assets/assist/assistant-avatar.webp';
let installed=false,root=null,context={},key='',epoch=0,opened=false,catalog=null,quota=null,credits=null,ticketId='',question='',pending=null,busy=false,getClubRoutes=()=>[];

function current(){const initial=Boolean(document.querySelector('[data-kx-usage-help-initial],.kx-type-picker,[data-kombax-view="profiles"],[data-kombax-view="identity-intro"],[data-kombax-view="member-family-intro"]'));return resolveUsageHelpContext(state.session,usageWorkspaceContext(),state.route,initial);}
function sync(){
 const next=current(),nextKey=usageHelpContextKey(next);context=next;
 if(!usageHelpVisible(context))opened=false;
 if(nextKey!==key){key=nextKey;epoch++;quota=null;credits=null;ticketId='';question='';pending=null;busy=false;if(opened){renderPanel();loadQuota();}}
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
async function open(){sync();if(!usageHelpVisible(context))return;opened=true;const panel=root.querySelector('#kx-usage-help-panel');if(panel.dataset.helpEpoch!==String(epoch))renderPanel();else panel.hidden=false;root.querySelector('.kx-usage-help-launcher').setAttribute('aria-expanded','true');const captured=epoch;
 try{if(!catalog){const response=await fetch('./assets/guides/usage-help-r272.json');if(!response.ok)throw Error('guide_unavailable');catalog=(await response.json()).guides;}if(captured===epoch){suggest();root.querySelector('textarea')?.focus();}}catch{if(captured===epoch)message(L('No se pudo cargar la guía. Puedes contactar con Soporte.'),'assistant');}
 loadQuota();
}
function renderPanel(){
 const panel=root?.querySelector('#kx-usage-help-panel');if(!panel)return;
 panel.dataset.helpEpoch=String(epoch);panel.hidden=false;panel.innerHTML=`<header><img src="${avatar}" alt=""><div><strong>${esc(L('Ayuda KOMBAX'))}</strong><small>${esc(context.name||'KOMBAX')} · ${esc(L('Guía de uso'))}</small></div><button type="button" class="icon-btn" data-help-close aria-label="${esc(L('Cerrar'))}">×</button></header><div class="kx-help-thread" role="log" aria-live="polite" aria-relevant="additions"></div><div class="kx-help-suggestions"></div><div class="kx-help-quota" aria-live="polite"></div><form><label for="kx-help-question">${esc(L('¿Qué necesitas hacer?'))}</label><textarea id="kx-help-question" rows="2" maxlength="1500" required placeholder="${esc(L('Por ejemplo: cómo crear una sesión'))}"></textarea><div><button type="submit" class="btn btn-primary">${esc(L('Ver pasos'))}</button><button type="button" class="btn btn-ghost" data-help-ai hidden>${esc(L('Consultar con IA'))}</button></div></form><footer><button type="button" data-help-new>${esc(L('Nueva conversación'))}</button><a href="mailto:soporte@kombax.es">${esc(L('Contactar con Soporte'))}</a></footer>`;
 panel.querySelector('[data-help-close]').addEventListener('click',close);panel.onkeydown=e=>{if(e.key==='Escape'){e.preventDefault();close();}};
 panel.querySelector('form').addEventListener('submit',e=>{e.preventDefault();answer();});panel.querySelector('[data-help-ai]').addEventListener('click',askAi);
 panel.querySelector('[data-help-new]').addEventListener('click',()=>{if(busy)return;ticketId='';pending=null;question='';renderPanel();suggest();quotaLine();});
 message(L('¿Qué necesitas hacer? Te explico los pasos.'),'assistant');suggest();quotaLine();
}
function message(text,role='assistant',html=''){
 const thread=root.querySelector('.kx-help-thread'),article=document.createElement('article');article.className=`kx-help-message ${role}`;
 article.innerHTML=`<small>${esc(role==='user'?L('Tú'):L('Ayuda KOMBAX'))}</small><div>${esc(text)}</div>${html}`;thread.appendChild(article);thread.scrollTop=thread.scrollHeight;
}
function suggest(){
 if(!catalog)return;
 const queries=context.kind==='club'?(['alumno','familia'].includes(context.role)?['Mis clases','Mis cuotas','Comunicaciones del club']:['Crear una sesión','Añadir un alumno','Registrar un cargo']):context.kind==='profile'?['Editar foto y banner','Activar servicios','Showcase y vendedor']:['Crear una cuenta','Recuperar contraseña','Seleccionar identidad'];
 const box=root.querySelector('.kx-help-suggestions');box.innerHTML=queries.map(q=>`<button type="button" class="btn btn-ghost btn-sm" data-help-query="${esc(q)}">${esc(L(q))}</button>`).join('');
 box.querySelectorAll('[data-help-query]').forEach(button=>button.addEventListener('click',()=>{root.querySelector('textarea').value=button.dataset.helpQuery;answer();}));
}
function guideAction(topic){
 if(!helpTopicAllowed(topic,context))return false;
 if(context.kind==='club')return topic.route&&getClubRoutes().includes(topic.route);
 return context.kind==='profile'&&topic.module&&(context.modules||[]).includes(topic.module);
}
function showTopic(topic){
 const allowed=guideAction(topic),steps=(topic.steps||[]).slice(0,5).map((step,i)=>`${i+1}. ${L(step)}`).join('\n');
 message(`${L(topic.title)}\n${steps}${!helpTopicAllowed(topic,context)?'\n'+L('Esta función requiere otro rol. Consulta con la administración.'):''}`,'assistant',allowed?`<button type="button" class="btn btn-ghost btn-sm" data-help-open="${esc(topic.id)}">${esc(L('Abrir esta función'))}</button>`:'');
 const button=[...root.querySelectorAll(`[data-help-open="${topic.id}"]`)].at(-1);button?.addEventListener('click',()=>{if(!guideAction(topic))return;close();if(context.kind==='club')window.dispatchEvent(new CustomEvent('kx-club-route',{detail:{route:topic.route}}));else openUsageWorkspaceModule(topic.module);});
}
function showChoices(topics){
 if(!topics.length)return;
 message(L('También puedo explicarte estas tareas:'),'assistant',`<div class="kx-help-choices">${topics.map(topic=>`<button type="button" class="btn btn-ghost btn-sm" data-help-topic="${esc(topic.id)}">${esc(L(topic.title))}</button>`).join('')}</div>`);
 const choices=root.querySelector('.kx-help-thread article:last-child');
 choices.querySelectorAll('[data-help-topic]').forEach(button=>button.addEventListener('click',()=>{const topic=topics.find(x=>x.id===button.dataset.helpTopic);if(!topic||busy)return;question=topic.title;message(L(topic.title),'user');showTopic(topic);quotaLine();}));
}
function answer(){
 sync();if(busy)return;const input=root.querySelector('textarea');question=String(input?.value||'').trim().slice(0,1500);if(!question||!catalog)return;
 message(question,'user');const topics=selectHelpTopics(catalog,question,context,7);
 if(topics.length){showTopic(topics[0]);showChoices(topics.slice(1,7).filter(topic=>helpTopicAllowed(topic,context)));}else message(L('No encuentro una guía exacta. Prueba con el nombre de la tarea o contacta con Soporte.'));
 input.value='';quotaLine();
}
async function loadQuota(){
 if(!opened||!usageHelpAiEligible(context))return;const ref=context.tenantRef,captured=epoch;
 try{const feature=await repos.customerOps.usageHelpStatus(ref);if(feature?.usage_help!=='r272'||feature.ai_configured!==true)throw Error('usage_help_unavailable');if(captured!==epoch)return;if(feature.ai_allowed!==true){quota={guideOnly:true};credits=null;quotaLine();return;}const [a,c]=await Promise.all([repos.customerOps.allowance(ref),repos.customerOps.aiCredits(ref)]);if(captured!==epoch)return;quota=a;credits=c;quotaLine();}catch{if(captured===epoch){quota={unavailable:true};quotaLine();}}
}
function quotaLine(){
 if(!root||!opened)return;const label=root.querySelector('.kx-help-quota'),ai=root.querySelector('[data-help-ai]');
 const eligible=usageHelpAiEligible(context),remaining=Number(quota?.allowance_remaining),available=Number(credits?.available);
 label.textContent=L('Las guías rápidas no consumen tokens ni asistencias.');
 if(busy)label.textContent+=' '+L('Preparando la respuesta IA…');
 if(eligible&&quota&&!quota.unavailable&&Number.isFinite(remaining))label.textContent+=` ${L('Asistencias compartidas restantes')}: ${remaining}. ${L('Una conversación IA usa el cupo y los créditos vigentes de tu identidad.')}`;
 if(eligible&&quota?.unavailable)label.textContent+=' '+L('No se pudo comprobar el cupo de IA. Las guías siguen disponibles.');
 if(credits?.trial)label.textContent+=' '+L('La prueba de IA mantiene sus consultas de demostración; puedes seguir usando las guías.');
 if(quota?.guideOnly)label.textContent+=' '+L('La consulta IA requiere un plan, prueba o piloto con derecho de uso.');
 ai.hidden=!eligible||!question||quota?.guideOnly===true;ai.disabled=busy||!quota||quota.unavailable===true||credits?.trial===true||(!ticketId&&!(remaining>0))||!(available>0);
 root.querySelector('form button[type="submit"]').disabled=busy;root.querySelector('[data-help-new]').disabled=busy;
}
async function askAi(){
 if(busy||!question||!usageHelpAiEligible(context))return;
 const ai=root.querySelector('[data-help-ai]');if(ai.disabled)return;
 const captured=epoch,ref=context.tenantRef,requestQuestion=question;busy=true;quotaLine();
 try{
  if(!ticketId){const created=await repos.customerOps.createTicket({category:'MANAGEMENT',subject:`Ayuda KOMBAX · ${context.name||context.type}`,module:'assist',tenant_ref:ref});if(captured!==epoch)return;ticketId=created.ticket_id;if(!ticketId)throw Error('case_unavailable');}
  if(!pending||pending.question!==requestQuestion)pending={question:requestQuestion,id:crypto.randomUUID()};
  const response=await repos.customerOps.chat(ticketId,requestQuestion,'usage',pending.id);
  if(captured!==epoch)return;message(response.message||L('No hay respuesta disponible. Contacta con Soporte.'));pending=null;await loadQuota();
 }catch{if(captured===epoch)message(L('No se pudo completar la consulta IA. Revisa el cupo o inténtalo de nuevo; las guías siguen disponibles.'));}
 finally{if(captured===epoch){busy=false;quotaLine();}}
}
export function installUsageHelp({clubRoutes=()=>[]}={}){
 if(installed)return;installed=true;getClubRoutes=clubRoutes;
 const start=()=>{sync();const observer=new MutationObserver(records=>{if(records.every(r=>r.target.closest?.('#kx-usage-help-root')))return;requestAnimationFrame(sync);});const app=document.getElementById('app');if(app)observer.observe(document.body,{childList:true,subtree:true});window.addEventListener('hashchange',()=>requestAnimationFrame(sync));window.addEventListener('kombax:localechange',()=>{if(opened)renderPanel();const launcher=root?.querySelector('.kx-usage-help-launcher span');if(launcher)launcher.textContent=L('¿Necesitas ayuda?');});};
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
}
