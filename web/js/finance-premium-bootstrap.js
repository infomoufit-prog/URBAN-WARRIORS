import { state } from './core/state.js';
import { renderFinanceEntry } from './modules/finance-premium.js';

let pending=false;
async function reconcile(){
  const main=document.getElementById('main-view');if(!main)return;
  if(state.route!=='finance'){main.removeAttribute('data-kx-finance-premium-mounted');return;}
  if(main.hasAttribute('data-kx-finance-premium-mounted')||pending)return;
  pending=true;main.setAttribute('data-kx-finance-premium-mounted','loading');
  try{await renderFinanceEntry();main.setAttribute('data-kx-finance-premium-mounted','1');}
  catch(error){console.warn('Finanzas Premium mantiene la vista legacy:',error);main.setAttribute('data-kx-finance-premium-mounted','legacy');}
  finally{pending=false;}
}

const observer=new MutationObserver(()=>queueMicrotask(reconcile));
observer.observe(document.documentElement,{childList:true,subtree:true});
window.addEventListener('popstate',()=>setTimeout(reconcile,0));
window.addEventListener('hashchange',()=>setTimeout(reconcile,0));
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(reconcile,0),{once:true});else setTimeout(reconcile,0);
