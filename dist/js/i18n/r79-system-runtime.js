import { getLocale } from './index.js';
import { R79_SYSTEM_SOURCE } from './r79-system-source.js';

const SUPPORTED=['en','fr','pt','it','de','th','fil'];
const CACHE_VERSION='20130-p6-p10-v1';
const CACHE_PREFIX='kx_r79_system_copy_';
const EXPECTED_COUNT=Object.keys(R79_SYSTEM_SOURCE).length;
const localeMaps=new Map();
const inflight=new Map();
const normalize=value=>String(value??'').replace(/\u00a0/g,' ').replace(/\s+/g,' ').trim();
const sourceById=new Map(Object.entries(R79_SYSTEM_SOURCE).map(([id,text])=>[id,normalize(text)]));
const dynamicIds=[...sourceById.entries()].filter(([,text])=>text.includes('{VAR}')).map(([id,text])=>({id,text}));
const cacheKey=locale=>`${CACHE_PREFIX}${CACHE_VERSION}_${locale}`;
const escapeRegExp=value=>String(value).replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
function compileDynamic(source){
  const parts=String(source).split('{VAR}'); if(parts.length<2)return null;
  try{return new RegExp('^'+parts.map(escapeRegExp).join('(.+?)')+'$','u')}catch{return null}
}
function buildLocaleMap(locale,byId){
  const exact=new Map(),dynamic=[];
  for(const [id,translatedRaw] of Object.entries(byId||{})){
    const source=sourceById.get(id),translated=normalize(translatedRaw);
    if(!source||!translated||translated===source)continue;
    exact.set(source,translated);
  }
  for(const item of dynamicIds){
    const translated=normalize(byId?.[item.id]); if(!translated||translated===item.text)continue;
    const regex=compileDynamic(item.text); if(regex)dynamic.push({regex,translated});
  }
  const value={exact,dynamic,count:Object.keys(byId||{}).length}; localeMaps.set(locale,value); return value;
}
function readCached(locale){
  if(locale==='es')return {exact:new Map(),dynamic:[],count:EXPECTED_COUNT};
  if(localeMaps.has(locale))return localeMaps.get(locale);
  try{
    const parsed=JSON.parse(localStorage.getItem(cacheKey(locale))||'null');
    if(parsed?.version===CACHE_VERSION&&parsed?.byId&&Object.keys(parsed.byId).length===EXPECTED_COUNT)return buildLocaleMap(locale,parsed.byId);
  }catch{}
  const empty={exact:new Map(),dynamic:[],count:0}; localeMaps.set(locale,empty); return empty;
}
export function r79Exact(source,locale=getLocale()){
  if(locale==='es')return '';
  return readCached(locale).exact.get(normalize(source))||'';
}
export function r79Dynamic(source,locale=getLocale()){
  if(locale==='es')return '';
  const normalized=normalize(source),catalog=readCached(locale);
  for(const rule of catalog.dynamic){
    const match=normalized.match(rule.regex); if(!match)continue;
    let index=1; return rule.translated.replace(/\{VAR\}/g,()=>String(match[index++]??''));
  }
  return '';
}
export async function hydrateR79SystemCopy(locale=getLocale(),{force=false}={}){
  const code=String(locale||'').toLowerCase();
  if(code==='es'||!SUPPORTED.includes(code))return EXPECTED_COUNT;
  const cached=readCached(code); if(!force&&cached.count===EXPECTED_COUNT)return cached.count;
  if(inflight.has(code))return inflight.get(code);
  const promise=(async()=>{
    const cfg=window.UW_CONFIG?.supabase||{}; if(!cfg.url||!cfg.anonKey)throw new Error('R79 i18n backend unavailable');
    const params=new URLSearchParams({select:'content_id,translated_text',content_type:'eq.system_copy_r79',target_locale:`eq.${code}`,visibility:'eq.public',requester_id:'is.null',limit:'1000'});
    const response=await fetch(`${String(cfg.url).replace(/\/+$/,'')}/rest/v1/kombax_content_translations_u01?${params}`,{headers:{apikey:cfg.anonKey},cache:'no-store'});
    if(!response.ok)throw new Error(`R79 i18n HTTP ${response.status}`);
    const rows=await response.json(),byId={};
    for(const row of Array.isArray(rows)?rows:[]){const id=String(row?.content_id||''),text=String(row?.translated_text||'').trim();if(sourceById.has(id)&&text)byId[id]=text;}
    const count=Object.keys(byId).length; if(count!==EXPECTED_COUNT)throw new Error(`R79 i18n incomplete ${code}: ${count}/${EXPECTED_COUNT}`);
    try{localStorage.setItem(cacheKey(code),JSON.stringify({version:CACHE_VERSION,byId,at:new Date().toISOString()}));}catch{}
    buildLocaleMap(code,byId); return EXPECTED_COUNT;
  })().finally(()=>inflight.delete(code));
  inflight.set(code,promise); return promise;
}
export function warmR79SystemCopyCatalogs(locale=getLocale()){
  const order=[locale,...SUPPORTED].filter((x,i,a)=>x!=='es'&&a.indexOf(x)===i);
  let chain=Promise.resolve(); for(const code of order)chain=chain.then(()=>hydrateR79SystemCopy(code).catch(()=>0)); return chain;
}
export const R79_EXPECTED_COUNT=EXPECTED_COUNT;
