import { getLocale,setLocale,LOCALE_METADATA,ENABLED_LOCALES } from './index.js';
import { installLegacyRuntimeLocalization,localizeKombaxDom,localizeSystemText } from './legacy-runtime.js';

function syncHead(){
  const locale=getLocale();
  document.documentElement.lang=locale;
  const title=document.querySelector('title');
  if(title){
    if(!title.dataset.kxOriginal)title.dataset.kxOriginal=title.textContent||'';
    title.textContent=localizeSystemText(title.dataset.kxOriginal,locale);
  }
  const meta=document.querySelector('meta[name="description"]');
  if(meta){
    if(!meta.dataset.kxOriginal)meta.dataset.kxOriginal=meta.getAttribute('content')||'';
    meta.setAttribute('content',localizeSystemText(meta.dataset.kxOriginal,locale));
  }
}
function mountSelector(){
  if(document.querySelector('[data-kx-public-language]'))return;
  const box=document.createElement('div');
  box.dataset.kxPublicLanguage='1';
  box.setAttribute('aria-label','Language');
  box.style.cssText='position:fixed;z-index:9999;right:max(12px,env(safe-area-inset-right));top:max(12px,env(safe-area-inset-top));background:#101318eF;border:1px solid #303641;border-radius:12px;padding:7px 9px;box-shadow:0 8px 28px #0007;color:#fff;font:600 12px/1.2 system-ui,sans-serif';
  const select=document.createElement('select');
  select.setAttribute('aria-label','Language');
  select.style.cssText='background:#101318;color:#fff;border:0;outline:0;font:inherit;cursor:pointer';
  for(const code of ENABLED_LOCALES){
    const meta=LOCALE_METADATA[code];const option=document.createElement('option');option.value=code;option.textContent=`${code.toUpperCase()} · ${meta?.nativeName||code}`;select.append(option);
  }
  select.value=getLocale();
  select.addEventListener('change',()=>{setLocale(select.value);syncHead();localizeKombaxDom(document.body,getLocale());});
  box.append(select);document.body.append(box);
}
installLegacyRuntimeLocalization();
const boot=()=>{syncHead();mountSelector();localizeKombaxDom(document.body,getLocale());};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
window.addEventListener('kombax:localechange',()=>{syncHead();const s=document.querySelector('[data-kx-public-language] select');if(s)s.value=getLocale();});
