// KOMBAX Universal Content Translation runtime.
// Authored source content is never overwritten. Translations are derived views.
import { getLocale, normalizeLocale, t } from './index.js';

export const USER_CONTENT_TRANSLATABLE_TYPES=Object.freeze([
  'social_post','social_comment','social_message','community_post','community_comment',
  'showcase_product_name','showcase_product_summary','showcase_product_description','showcase_product_review','showcase_inquiry_message',
  'event','event_name','event_summary','event_description','event_comment','event_review','event_media','fighter_invitation',
  'public_profile_bio','club_editorial','federation_editorial','brand_editorial',
  'professional_service','professional_service_name','professional_service_description','professional_finance_charge','professional_expense',
  'communication_message','club_material_name','club_material_description','club_tariff','work_scope','document_description'
]);
const AUTO_KEY='kombax_i18n_auto_translate_public_v1';
const stateByElement=new WeakMap();
const requestCache=new Map();
let installed=false,observer=null,intersection=null,active=0;
const queue=[];const MAX_CONCURRENT=3;
const attr=v=>String(v??'').replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const normalizeType=v=>String(v||'').trim().toLowerCase().replace(/[^a-z0-9_.-]/g,'').slice(0,80);
const normalizeField=v=>String(v||'text').trim().toLowerCase().replace(/[^a-z0-9_.-]/g,'').slice(0,80)||'text';
export function isAutoTranslatePublicEnabled(){try{return localStorage.getItem(AUTO_KEY)!=='0';}catch{return true;}}
export function setAutoTranslatePublicEnabled(value){try{localStorage.setItem(AUTO_KEY,value?'1':'0');}catch{};scanTranslatableContent(document,{auto:Boolean(value)});}
export function canOfferUserContentTranslation({text='',sourceLocale=null,targetLocale=getLocale(),contentType='' }={}){
  const value=String(text||'').trim();if(!value||value.length<2)return false;
  if(!normalizeType(contentType))return false;
  const target=normalizeLocale(targetLocale);const source=sourceLocale?normalizeLocale(sourceLocale):null;
  return !source||source!==target;
}
export function buildUserContentTranslationRequest({contentId,contentType,fieldName='text',text,sourceLocale=null,targetLocale=getLocale(),visibility='public'}={}){
  if(!canOfferUserContentTranslation({text,sourceLocale,targetLocale,contentType}))return null;
  return Object.freeze({content_id:String(contentId||'').slice(0,180),content_type:normalizeType(contentType),field_name:normalizeField(fieldName),source_text:String(text||''),source_locale:sourceLocale?normalizeLocale(sourceLocale):null,target_locale:normalizeLocale(targetLocale),visibility:['public','tenant','private'].includes(visibility)?visibility:'public',preserve_original:true,mutation_policy:'derived_translation_only'});
}
export function contentTranslationAttrs({contentId,contentType,fieldName='text',sourceLocale='',visibility='public',auto=true}={}){
  return `data-kx-translatable="1" data-kx-content-id="${attr(contentId)}" data-kx-content-type="${attr(normalizeType(contentType))}" data-kx-content-field="${attr(normalizeField(fieldName))}" data-kx-source-locale="${attr(sourceLocale||'')}" data-kx-content-visibility="${attr(visibility)}" data-kx-translate-auto="${auto?'1':'0'}"`;
}
function labels(){return {translate:t('common.translation.seeTranslation'),original:t('common.translation.viewOriginal'),loading:t('common.translation.translating'),translated:t('common.translation.translated'),failed:t('common.translation.failed')};}
function ensureState(el){let s=stateByElement.get(el);if(s)return s;s={originalHtml:el.innerHTML,originalText:((el.innerText||el.textContent||'').trim()),translatedText:'',translatedLocale:'',sourceLocale:el.dataset.kxSourceLocale||'',showing:'original',busy:false,control:null};stateByElement.set(el,s);return s;}
function ensureControls(el){const s=ensureState(el);if(s.control?.isConnected)return s.control;const host=document.createElement('span');host.className='kx-content-translation-controls';host.setAttribute('data-kx-translation-controls','');host.innerHTML=`<button type="button" class="kx-content-translation-action" data-kx-translate-action="translate">${labels().translate}</button><span class="kx-content-translation-note" hidden></span>`;el.insertAdjacentElement('afterend',host);s.control=host;return host;}
function updateControls(el){const s=ensureState(el),host=ensureControls(el),button=host.querySelector('[data-kx-translate-action]'),note=host.querySelector('.kx-content-translation-note'),l=labels();if(!button)return;if(s.busy){button.disabled=true;button.textContent=l.loading;note.hidden=true;return;}button.disabled=false;button.dataset.kxTranslateAction=s.showing==='translated'?'original':'translate';button.textContent=s.showing==='translated'?l.original:l.translate;if(s.showing==='translated'){note.hidden=false;note.textContent=l.translated;}else note.hidden=true;}
export async function translateUserContentValue({contentId,contentType,fieldName='text',text,sourceLocale=null,targetLocale=getLocale(),visibility='public'}={}){
  const req=buildUserContentTranslationRequest({contentId,contentType,fieldName,text,sourceLocale,targetLocale,visibility});
  if(!req)return {ok:true,same_language:true,translated_text:String(text||''),source_locale:sourceLocale||null,target_locale:normalizeLocale(targetLocale)};
  try{return await invokeTranslation(req);}catch(error){return {ok:false,error,translated_text:String(text||''),source_locale:sourceLocale||null,target_locale:normalizeLocale(targetLocale)};}
}
export async function prewarmUserContentTranslations(input={}){
  if(Array.isArray(input)){
    const rows=await Promise.all(input.map(item=>prewarmUserContentTranslations(item)));
    return {ok:rows.every(x=>x?.ok!==false),items:rows.length,results:rows};
  }
  const {contentId,contentType,fieldName='text',text,sourceLocale=null,visibility='public'}=input||{};
  const source=String(text||'').trim();if(!source||!contentId||!contentType||visibility==='private')return {ok:false,skipped:true};
  const targets=['es','en','fr','pt','it','de','th','fil'].filter(locale=>!sourceLocale||normalizeLocale(sourceLocale)!==locale);
  const results=[];for(let i=0;i<targets.length;i+=3){const batch=targets.slice(i,i+3);const rows=await Promise.all(batch.map(targetLocale=>translateUserContentValue({contentId,contentType,fieldName,text:source,sourceLocale,targetLocale,visibility})));results.push(...rows);}
  return {ok:results.every(x=>x?.ok!==false),targets:targets.length,results};
}
async function sha256Text(value){if(!globalThis.crypto?.subtle)return '';const bytes=new TextEncoder().encode(String(value||''));const digest=await crypto.subtle.digest('SHA-256',bytes);return Array.from(new Uint8Array(digest)).map(b=>b.toString(16).padStart(2,'0')).join('');}
async function lookupPublicCachedTranslation(req){if(req.visibility!=='public'||!req.content_id||!req.source_text)return null;try{const {client}=await import('../core/backend.js');const hash=await sha256Text(req.source_text);if(!hash)return null;const q=`select=translated_text,source_locale,target_locale&content_type=eq.${encodeURIComponent(req.content_type)}&content_id=eq.${encodeURIComponent(req.content_id)}&field_name=eq.${encodeURIComponent(req.field_name)}&source_hash=eq.${hash}&target_locale=eq.${encodeURIComponent(req.target_locale)}&visibility=eq.public&requester_id=is.null&limit=1`;const rows=await client.select('kombax_content_translations_u01',q);const row=Array.isArray(rows)?rows[0]:null;return row?.translated_text?{translated_text:row.translated_text,source_locale:row.source_locale||req.source_locale||null,target_locale:row.target_locale||req.target_locale,preserve_original:true,cached:true}:null;}catch{return null;}}
async function invokeTranslation(req){const key=[req.content_type,req.content_id,req.field_name,req.target_locale,req.visibility,req.source_text].join('\u001f');if(requestCache.has(key))return requestCache.get(key);const promise=(async()=>{const cached=await lookupPublicCachedTranslation(req);if(cached)return cached;const {backend}=await import('../core/backend.js');return backend.invokeFunction('kombax-content-translate',req,50000);})();requestCache.set(key,promise);try{return await promise;}finally{setTimeout(()=>requestCache.delete(key),120000);}}
async function runTranslate(el){const s=ensureState(el);if(s.busy||!s.originalText)return;s.busy=true;updateControls(el);const req=buildUserContentTranslationRequest({contentId:el.dataset.kxContentId||'',contentType:el.dataset.kxContentType||'user_content',fieldName:el.dataset.kxContentField||'text',text:s.originalText,sourceLocale:el.dataset.kxSourceLocale||null,targetLocale:getLocale(),visibility:el.dataset.kxContentVisibility||'public'});if(!req){s.busy=false;updateControls(el);return;}try{const out=await invokeTranslation(req);if(out?.same_language||String(out?.translated_text||'').trim()===s.originalText){s.sourceLocale=out?.source_locale||s.sourceLocale;const host=s.control||ensureControls(el);host.hidden=true;return;}s.translatedText=String(out?.translated_text||'').trim();s.translatedLocale=String(out?.target_locale||getLocale());s.sourceLocale=String(out?.source_locale||s.sourceLocale||'');if(s.translatedText){el.textContent=s.translatedText;el.lang=s.translatedLocale;el.classList.add('kx-content-translated');s.showing='translated';}}catch(error){console.warn('KOMBAX content translation:',error);const host=s.control||ensureControls(el),note=host.querySelector('.kx-content-translation-note');if(note){note.hidden=false;note.textContent=labels().failed;note.classList.add('error');}}finally{s.busy=false;updateControls(el);}}
function showOriginal(el){const s=ensureState(el);el.innerHTML=s.originalHtml;el.removeAttribute('lang');el.classList.remove('kx-content-translated');s.showing='original';updateControls(el);}
function enqueue(el){if(!el?.isConnected)return;queue.push(el);pump();}
function pump(){while(active<MAX_CONCURRENT&&queue.length){const el=queue.shift();if(!el?.isConnected)continue;active++;runTranslate(el).finally(()=>{active--;pump();});}}
function shouldAuto(el){if(el.dataset.kxTranslateAuto==='0')return false;if(el.dataset.kxContentVisibility==='private')return false;return isAutoTranslatePublicEnabled();}
function observeElement(el){if(el.dataset.kxTranslationBound==='1')return;el.dataset.kxTranslationBound='1';const s=ensureState(el);if(!s.originalText)return;ensureControls(el);updateControls(el);if(shouldAuto(el)){if(intersection)intersection.observe(el);else enqueue(el);}}
export function scanTranslatableContent(root=document,{auto=true}={}){if(!root?.querySelectorAll)return;const els=[];if(root.matches?.('[data-kx-translatable="1"]'))els.push(root);root.querySelectorAll('[data-kx-translatable="1"]').forEach(el=>els.push(el));for(const el of els){observeElement(el);if(auto&&shouldAuto(el)&&!intersection)enqueue(el);}}
function resetForLocale(){requestCache.clear();document.querySelectorAll('[data-kx-translatable="1"]').forEach(el=>{const s=ensureState(el);if(s.showing==='translated')showOriginal(el);if(shouldAuto(el)){intersection?.observe(el);if(!intersection)enqueue(el);}});}
export function installUniversalContentTranslation(){if(installed||typeof document==='undefined')return;installed=true;intersection=typeof IntersectionObserver!=='undefined'?new IntersectionObserver(entries=>{for(const e of entries){if(e.isIntersecting){intersection.unobserve(e.target);enqueue(e.target);}}},{rootMargin:'220px'}):null;document.addEventListener('click',e=>{const b=e.target.closest?.('[data-kx-translate-action]');if(!b)return;const host=b.closest('[data-kx-translation-controls]'),el=host?.previousElementSibling;if(!el?.matches?.('[data-kx-translatable="1"]'))return;e.preventDefault();if(b.dataset.kxTranslateAction==='original')showOriginal(el);else runTranslate(el);});observer=new MutationObserver(records=>{for(const r of records)for(const node of r.addedNodes)if(node.nodeType===1)scanTranslatableContent(node);});observer.observe(document.body,{childList:true,subtree:true});window.addEventListener('kombax:localechange',resetForLocale);scanTranslatableContent(document);}
