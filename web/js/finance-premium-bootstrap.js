import { state } from './core/state.js';
import { renderFinanceEntry } from './modules/finance-premium.js';

let pending=false;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FINANCE_TARGETS=new Set(['charge','payment','receipt','automation','overview']);

function normalizeFinanceDeepLink(){
  const raw=decodeURIComponent(String(location.hash||'').replace(/^#/,'').replace(/^\//,''));
  const match=/^finance__([a-z]+)__([0-9a-f-]{36})$/i.exec(raw);
  if(!match)return false;
  const target=match[1].toLowerCase(),entity=match[2].toLowerCase();
  if(!FINANCE_TARGETS.has(target)||!UUID.test(entity))return false;
  const url=new URL(location.href);url.searchParams.set('finance_target',target);url.searchParams.set('entity_id',entity);url.hash='finance';
  history.replaceState({route:'finance'},'',`${url.pathname}${url.search}${url.hash}`);
  window.dispatchEvent(new HashChangeEvent('hashchange'));
  return true;
}

async function reconcile(){
  normalizeFinanceDeepLink();
  const main=document.getElementById('main-view');if(!main)return;
  if(state.route!=='finance'){main.removeAttribute('data-kx-finance-premium-mounted');return;}
  if(main.hasAttribute('data-kx-finance-premium-mounted')||pending)return;
  pending=true;main.setAttribute('data-kx-finance-premium-mounted','loading');
  try{await renderFinanceEntry();main.setAttribute('data-kx-finance-premium-mounted','1');}
  catch(error){console.warn('Finanzas Premium mantiene la vista legacy:',error);main.setAttribute('data-kx-finance-premium-mounted','legacy');}
  finally{pending=false;}
}

normalizeFinanceDeepLink();
const observer=new MutationObserver(()=>queueMicrotask(reconcile));
observer.observe(document.documentElement,{childList:true,subtree:true});
window.addEventListener('popstate',()=>setTimeout(reconcile,0));
window.addEventListener('hashchange',()=>setTimeout(reconcile,0));
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(reconcile,0),{once:true});else setTimeout(reconcile,0);
