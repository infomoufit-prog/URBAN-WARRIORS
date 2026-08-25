import { renderFinancePremium, shouldUseFinancePremium } from './finance-premium.js';

let busy=false;
let scheduled=null;
let lastAttempt=0;

function financeRouteVisible(){
  const active=document.querySelector('[data-nav="finance"].active');
  const main=document.getElementById('main-view');
  if(!active||!main)return false;
  if(main.querySelector('.fv2-tabs'))return false;
  const title=main.querySelector('.page-head h1')?.textContent?.trim()||'';
  return title==='Finanzas';
}

async function upgradeFinance(){
  if(busy||!financeRouteVisible())return;
  const now=Date.now();if(now-lastAttempt<800)return;lastAttempt=now;
  busy=true;
  const main=document.getElementById('main-view');
  const legacy=main?.innerHTML||'';
  try{
    if(await shouldUseFinancePremium())await renderFinancePremium();
  }catch(error){
    if(main&&legacy){
      if(error?.kombaxFinanceBackendMismatch){
        main.innerHTML=`<div class="alert alert-danger" style="margin:0 0 14px"><strong>Finanzas Premium pendiente de sincronización</strong><span>La interfaz y el backend KOMBAX no están en la misma versión. No se muestran datos Premium hasta completar la actualización segura del servidor.</span></div>${legacy}`;
      }else main.innerHTML=legacy;
    }
    console.warn('Finanzas Premium: actualización no completada:',error);
  }finally{busy=false;}
}

const observer=new MutationObserver(()=>{
  clearTimeout(scheduled);scheduled=setTimeout(upgradeFinance,90);
});
observer.observe(document.documentElement,{subtree:true,childList:true});
addEventListener('uw-finance-v2-retry',upgradeFinance);
setTimeout(upgradeFinance,700);
