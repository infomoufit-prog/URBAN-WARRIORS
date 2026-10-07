import {localizeR120ProfileText} from "./r120-profile-copy.js";
import {localizeMetaInstagramText} from './meta-instagram-copy.js';
import { resources } from './resources.js';
import { getLocale } from './index.js';
import { LEGACY_EN_OVERRIDES } from './legacy-copy-en.js';
import { LEGACY_EN_RB02_OVERRIDES } from './legacy-copy-en-rb02.js';
import { LEGACY_EN_RB02_EXACT } from './legacy-copy-en-rb02-exact.js';
import { autoTranslateLegacyEnglish } from './legacy-auto-en.js';
import { LEGACY_FR_COMPLETE } from './legacy-copy-fr-complete.js';
import { LEGACY_PT_COMPLETE } from './legacy-copy-pt-complete.js';
import { LEGACY_IT_COMPLETE } from './legacy-copy-it-complete.js';
import { LEGACY_DE_COMPLETE } from './legacy-copy-de-complete.js';
import { LEGACY_TH_COMPLETE } from './legacy-copy-th-complete.js';
import { LEGACY_FIL_COMPLETE } from './legacy-copy-fil-complete.js';
import { localizeLegacyDynamic } from './legacy-dynamic-patterns.js';
import { PUBLIC_LEGAL_TRANSLATIONS } from './public-legal-translations.js';
import { R78_SYSTEM_SOURCE } from './r78-system-source.js';
import { r79Exact, r79Dynamic, hydrateR79SystemCopy, warmR79SystemCopyCatalogs } from './r79-system-runtime.js';
import { localizeR110PilotText } from './r110-pilot-copy.js';
import { localizeR115PilotText } from './r115-pilot-copy.js';
import { localizeR116PilotText } from './r116-pilot-copy.js';
import { localizeR117PilotHotfixText } from './r117-pilot-hotfix-copy.js';

const SKIP_SELECTOR = [
  '[data-user-content]','[data-i18n-user-content]','[data-kx-user-content]','[contenteditable="true"]',
  '.kx-social-post-text','.kx-contact-message p','.kx-comment p','.kx-inline-comment-context',
  '.kx-community-comment > p','.kx-community-review > p','.kx-seller-response > p',
  '.kx-message-product h3','.kx-message-product p',
  '.showcase-item-body > .page-kicker','.showcase-item-body > h2','.showcase-item-body > p',
  '.kx-public-event-copy > h1','.kx-public-event-copy > p','.kx-event-detail-copy > h1','.kx-event-detail-copy > p',
  '.kx-event-card-large-body > h2','.kx-event-card-large-body > h3'
].join(',');
const ATTRIBUTES=['placeholder','title','aria-label'];
const originalText=new WeakMap();
const originalAttrs=new WeakMap();
let observer=null;
let applying=false;

function flatten(obj,prefix='',out={}){
  for(const [key,value] of Object.entries(obj||{})){
    const path=prefix?`${prefix}.${key}`:key;
    if(typeof value==='string')out[path]=value;
    else if(value&&typeof value==='object')flatten(value,path,out);
  }
  return out;
}
function normalize(value){return String(value??'').replace(/\u00a0/g,' ').replace(/\s+/g,' ').trim();}
const R78_CACHE_VERSION='20129-p1-p5-v1';
const R78_CACHE_PREFIX='kx_r78_system_copy_';
const R78_EXPECTED_COUNT=Object.keys(R78_SYSTEM_SOURCE).length;
const r78LocaleMaps=new Map();
const r78Inflight=new Map();
const r78SourceById=new Map(Object.entries(R78_SYSTEM_SOURCE).map(([id,text])=>[id,normalize(text)]));
const r78SourceIdByText=new Map([...r78SourceById.entries()].map(([id,text])=>[text,id]));
const r78DynamicIds=[...r78SourceById.entries()].filter(([,text])=>text.includes('{VAR}')).map(([id,text])=>({id,text}));
function r78CacheKey(locale){return `${R78_CACHE_PREFIX}${R78_CACHE_VERSION}_${locale}`;}
function escapeRegExp(value){return String(value).replace(/[.*+?^${}()|[\]\\]/g,'\\$&');}
function compileR78Dynamic(source){
  const parts=String(source).split('{VAR}');
  if(parts.length<2)return null;
  const pattern='^'+parts.map(escapeRegExp).join('(.+?)')+'$';
  try{return new RegExp(pattern,'u')}catch{return null}
}
function buildR78LocaleMap(locale,byId){
  const exact=new Map(),dynamic=[];
  for(const [id,translatedRaw] of Object.entries(byId||{})){
    const source=r78SourceById.get(id),translated=normalize(translatedRaw);
    if(!source||!translated||translated===source)continue;
    exact.set(source,translated);
  }
  for(const item of r78DynamicIds){
    const translated=normalize(byId?.[item.id]);if(!translated||translated===item.text)continue;
    const regex=compileR78Dynamic(item.text);if(regex)dynamic.push({regex,translated});
  }
  const value={exact,dynamic,count:Object.keys(byId||{}).length};r78LocaleMaps.set(locale,value);return value;
}
function readR78Cached(locale){
  if(locale==='es')return {exact:new Map(),dynamic:[],count:R78_EXPECTED_COUNT};
  if(r78LocaleMaps.has(locale))return r78LocaleMaps.get(locale);
  try{
    const parsed=JSON.parse(localStorage.getItem(r78CacheKey(locale))||'null');
    if(parsed?.version===R78_CACHE_VERSION&&parsed?.byId&&Object.keys(parsed.byId).length===R78_EXPECTED_COUNT)return buildR78LocaleMap(locale,parsed.byId);
  }catch{}
  const empty={exact:new Map(),dynamic:[],count:0};r78LocaleMaps.set(locale,empty);return empty;
}
function applyR78Dynamic(source,locale){
  const catalog=readR78Cached(locale);
  for(const rule of catalog.dynamic){
    const match=source.match(rule.regex);if(!match)continue;
    let index=1;return rule.translated.replace(/\{VAR\}/g,()=>String(match[index++]??''));
  }
  return '';
}
export async function hydrateR78SystemCopy(locale=getLocale(),{force=false}={}){
  const code=String(locale||'').toLowerCase();if(code==='es'||!['en','fr','pt','it','de','th','fil'].includes(code))return R78_EXPECTED_COUNT;
  const cached=readR78Cached(code);if(!force&&cached.count===R78_EXPECTED_COUNT)return cached.count;
  if(r78Inflight.has(code))return r78Inflight.get(code);
  const promise=(async()=>{
    const cfg=window.UW_CONFIG?.supabase||{};if(!cfg.url||!cfg.anonKey)throw new Error('R78 i18n backend unavailable');
    const params=new URLSearchParams({select:'content_id,translated_text',content_type:'eq.system_copy_r78',target_locale:`eq.${code}`,visibility:'eq.public',requester_id:'is.null',limit:'2000'});
    const response=await fetch(`${String(cfg.url).replace(/\/+$/,'')}/rest/v1/kombax_content_translations_u01?${params}`,{headers:{apikey:cfg.anonKey},cache:'no-store'});
    if(!response.ok)throw new Error(`R78 i18n HTTP ${response.status}`);
    const rows=await response.json();const byId={};
    for(const row of Array.isArray(rows)?rows:[]){const id=String(row?.content_id||''),text=String(row?.translated_text||'').trim();if(r78SourceById.has(id)&&text)byId[id]=text;}
    if(Object.keys(byId).length!==R78_EXPECTED_COUNT)throw new Error(`R78 i18n incomplete ${code}: ${Object.keys(byId).length}/${R78_EXPECTED_COUNT}`);
    try{localStorage.setItem(r78CacheKey(code),JSON.stringify({version:R78_CACHE_VERSION,byId,at:new Date().toISOString()}));}catch{}
    buildR78LocaleMap(code,byId);
    if(code===getLocale()&&typeof document!=='undefined'&&document.body)queueMicrotask(()=>localizeKombaxDom(document.body,code));
    return R78_EXPECTED_COUNT;
  })().finally(()=>r78Inflight.delete(code));r78Inflight.set(code,promise);return promise;
}
export function warmR78SystemCopyCatalogs(locale=getLocale()){
  const order=[locale,...['en','fr','pt','it','de','th','fil']].filter((x,i,a)=>x!=='es'&&a.indexOf(x)===i);
  let chain=Promise.resolve();for(const code of order)chain=chain.then(()=>hydrateR78SystemCopy(code).catch(()=>0));return chain;
}
const esFlat=flatten(resources.es);
const localeMaps=new Map();
const DIRECT_LEGACY_OVERRIDES=Object.freeze({
  fr:LEGACY_FR_COMPLETE,pt:LEGACY_PT_COMPLETE,it:LEGACY_IT_COMPLETE,
  de:LEGACY_DE_COMPLETE,th:LEGACY_TH_COMPLETE,fil:LEGACY_FIL_COMPLETE
});
function catalogMap(locale){
  const code=resources[locale]?locale:'en';
  if(localeMaps.has(code))return localeMaps.get(code);
  const target=flatten(resources[code]);
  const en=flatten(resources.en);
  const map=new Map();
  for(const [key,source] of Object.entries(esFlat)){
    const src=normalize(source);if(!src)continue;
    const translated=normalize(target[key]||en[key]||source);
    if(translated&&translated!==src)map.set(src,translated);
  }
  const legacyOverrides=code==='en'
    ? {...LEGACY_EN_OVERRIDES,...LEGACY_EN_RB02_OVERRIDES,...LEGACY_EN_RB02_EXACT}
    : (DIRECT_LEGACY_OVERRIDES[code]||{});
  if(code!=='es')for(const [source,translated] of Object.entries(legacyOverrides)){
    const src=normalize(source),dst=normalize(translated);if(src&&dst&&src!==dst&&!map.has(src))map.set(src,dst);
  }
  const publicLegal=PUBLIC_LEGAL_TRANSLATIONS[code]||{};
  if(code!=='es')for(const [source,translated] of Object.entries(publicLegal)){
    const src=normalize(source),dst=normalize(translated);if(src&&dst&&src!==dst)map.set(src,dst);
  }
  localeMaps.set(code,map);return map;
}

export function legacyCopyMap(locale=getLocale()){return catalogMap(locale==='es'?'es':locale);}
export function localizeSystemText(value,locale=getLocale()){
  const raw=String(value??'');if(!raw||locale==='es')return raw;
  const leading=raw.match(/^\s*/)?.[0]||'',trailing=raw.match(/\s*$/)?.[0]||'';
  const source=normalize(raw);if(!source)return raw;
  const metaInstagramValue=localizeMetaInstagramText(source,locale);if(metaInstagramValue)return leading+metaInstagramValue+trailing;
  const r120ProfileValue=localizeR120ProfileText(source,locale);if(r120ProfileValue)return leading+r120ProfileValue+trailing;
  const r117PilotValue=localizeR117PilotHotfixText(source,locale);if(r117PilotValue)return `${leading}${r117PilotValue}${trailing}`;
  const r116PilotValue=localizeR116PilotText(source,locale);if(r116PilotValue)return `${leading}${r116PilotValue}${trailing}`;
  const r115PilotValue=localizeR115PilotText(source,locale);if(r115PilotValue)return `${leading}${r115PilotValue}${trailing}`;
  const r110PilotValue=localizeR110PilotText(source,locale);if(r110PilotValue)return `${leading}${r110PilotValue}${trailing}`;
  const r79ExactValue=r79Exact(source,locale);if(r79ExactValue)return `${leading}${r79ExactValue}${trailing}`;
  const r79DynamicValue=r79Dynamic(source,locale);if(r79DynamicValue)return `${leading}${r79DynamicValue}${trailing}`;
  const r78=readR78Cached(locale);const r78Exact=r78.exact.get(source);if(r78Exact)return `${leading}${r78Exact}${trailing}`;
  const r78Dynamic=applyR78Dynamic(source,locale);if(r78Dynamic)return `${leading}${r78Dynamic}${trailing}`;
  const map=catalogMap(locale);const exact=map.get(source);if(exact)return `${leading}${exact}${trailing}`;
  const translateFragment=(fragment)=>r79Exact(fragment,locale)||r78.exact.get(normalize(fragment))||map.get(normalize(fragment))||fragment;
  const dynamic=localizeLegacyDynamic(source,locale,translateFragment);
  if(dynamic&&dynamic!==source)return `${leading}${dynamic}${trailing}`;
  if(locale==='en'){const auto=autoTranslateLegacyEnglish(source);if(auto!==source)return `${leading}${auto}${trailing}`;}
  return raw;
}
function shouldSkip(node){const el=node?.nodeType===1?node:node?.parentElement;return Boolean(el?.closest?.(SKIP_SELECTOR));}
function localizeTextNode(node,locale){
  if(!node||node.nodeType!==3||shouldSkip(node))return;
  if(!originalText.has(node))originalText.set(node,node.nodeValue||'');
  const source=originalText.get(node);const next=localizeSystemText(source,locale);if(node.nodeValue!==next)node.nodeValue=next;
}
function localizeElementAttrs(el,locale){
  if(!el||el.nodeType!==1||shouldSkip(el))return;
  if(!originalAttrs.has(el))originalAttrs.set(el,new Map());
  const originals=originalAttrs.get(el);
  for(const attr of ATTRIBUTES){if(!el.hasAttribute(attr))continue;if(!originals.has(attr))originals.set(attr,el.getAttribute(attr)||'');const source=originals.get(attr);const next=localizeSystemText(source,locale);if(el.getAttribute(attr)!==next)el.setAttribute(attr,next);}
}
export function localizeKombaxDom(root=document,locale=getLocale()){
  if(!root||typeof document==='undefined')return root;
  applying=true;
  try{
    if(root.nodeType===1)localizeElementAttrs(root,locale);
    const walker=document.createTreeWalker(root,NodeFilter.SHOW_ELEMENT|NodeFilter.SHOW_TEXT);
    let node=walker.currentNode;while(node){if(node.nodeType===3)localizeTextNode(node,locale);else localizeElementAttrs(node,locale);node=walker.nextNode();}
  }finally{applying=false;}
  return root;
}
export function localizeHtmlString(html,locale=getLocale()){
  if(typeof document==='undefined'||locale==='es')return String(html??'');
  const tpl=document.createElement('template');tpl.innerHTML=String(html??'');localizeKombaxDom(tpl.content,locale);return tpl.innerHTML;
}
export function installLegacyRuntimeLocalization(){
  if(typeof document==='undefined'||observer)return;
  const run=()=>localizeKombaxDom(document.body,getLocale());
  if(document.body)run();else document.addEventListener('DOMContentLoaded',run,{once:true});
  observer=new MutationObserver(records=>{if(applying)return;for(const record of records){for(const node of record.addedNodes){if(node.nodeType===1||node.nodeType===3)localizeKombaxDom(node,getLocale());}if(record.type==='attributes'&&record.target?.nodeType===1)localizeElementAttrs(record.target,getLocale());}});
  const start=()=>observer.observe(document.body,{subtree:true,childList:true,attributes:true,attributeFilter:ATTRIBUTES});
  if(document.body)start();else document.addEventListener('DOMContentLoaded',start,{once:true});
  Promise.allSettled([hydrateR79SystemCopy(getLocale()),hydrateR78SystemCopy(getLocale())]).finally(()=>{
    queueMicrotask(run);
    const warm=()=>Promise.allSettled([warmR79SystemCopyCatalogs(getLocale()),warmR78SystemCopyCatalogs(getLocale())]);
    if(typeof requestIdleCallback==='function')requestIdleCallback(warm,{timeout:4000});else setTimeout(warm,1200);
  });
  window.addEventListener('kombax:localechange',event=>{const locale=event?.detail?.locale||getLocale();queueMicrotask(run);Promise.allSettled([hydrateR79SystemCopy(locale),hydrateR78SystemCopy(locale)]).finally(()=>queueMicrotask(run));});
}
