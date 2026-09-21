// KOMBAX pre-SPA language bootstrap. Keeps the first visible interface multilingual.
const STORAGE_KEY='kombax_locale';
const SUPPORTED=['es','en','fr','pt','it','de','th','fil'];
const NATIVE={es:'Español',en:'English',fr:'Français',pt:'Português',it:'Italiano',de:'Deutsch',th:'ไทย',fil:'Filipino'};
const STARTING={es:'Iniciando KOMBAX…',en:'Starting KOMBAX…',fr:'Démarrage de KOMBAX…',pt:'A iniciar KOMBAX…',it:'Avvio di KOMBAX…',de:'KOMBAX wird gestartet…',th:'กำลังเริ่ม KOMBAX…',fil:'Sinisimulan ang KOMBAX…'};
function normalize(value=''){const raw=String(value||'').trim().toLowerCase().replace('_','-');const base=raw.split('-')[0];return SUPPORTED.includes(raw)?raw:SUPPORTED.includes(base)?base:'es';}
function initial(){try{const saved=localStorage.getItem(STORAGE_KEY);if(saved)return normalize(saved)}catch{};return normalize(navigator.languages?.[0]||navigator.language||'es')}
function apply(locale){const code=normalize(locale);try{localStorage.setItem(STORAGE_KEY,code)}catch{};document.documentElement.lang=code;document.documentElement.dir='ltr';const label=document.querySelector('[data-kx-boot-copy]');if(label)label.textContent=STARTING[code]||STARTING.es;const select=document.querySelector('[data-kx-boot-language]');if(select)select.value=code;return code;}
function mount(){const select=document.querySelector('[data-kx-boot-language]');if(!select)return;select.innerHTML=SUPPORTED.map(code=>`<option value="${code}">${code.toUpperCase()} · ${NATIVE[code]}</option>`).join('');apply(initial());select.addEventListener('change',()=>apply(select.value));}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mount,{once:true});else mount();
