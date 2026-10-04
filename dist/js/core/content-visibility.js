import {backend} from './backend.js';

export const deletionConfirmation=value=>String(value||'').trim().toUpperCase();
// Poll only cards actually on screen. Stop when navigating; a failed read never removes a card.
export function watchContentVisibility(root,{read=(channel,ids)=>backend.globalReadRpc('app_kombax_content_visible_r119',{p_channel:channel,p_ids:ids}),interval=15000}={}){
 let stopped=false,busy=false;
 const check=async()=>{
  if(stopped||busy||document.hidden||!root.isConnected)return;
  busy=true;
  try{
   for(const channel of ['social','showcase']){
    const cards=[...root.querySelectorAll(`[data-content-channel="${channel}"][data-content-id]`)];
    for(let offset=0;offset<cards.length;offset+=40){
     const batch=cards.slice(offset,offset+40),ids=[...new Set(batch.map(c=>c.dataset.contentId))];
     const visible=await read(channel,ids);
     if(stopped||!root.isConnected)return;
     if(!Array.isArray(visible))continue;
     const allowed=new Set(visible.map(String));
     for(const card of batch)if(!allowed.has(card.dataset.contentId))card.remove();
    }
   }
  }catch{/* Keep existing cards during an outage; retry on focus or the next interval. */}
  finally{busy=false;}
 };
 const timer=setInterval(check,interval);
 window.addEventListener('focus',check);window.addEventListener('uw-kombax-content-changed',check);document.addEventListener('visibilitychange',check);
 void check();
 return ()=>{stopped=true;clearInterval(timer);window.removeEventListener('focus',check);window.removeEventListener('uw-kombax-content-changed',check);document.removeEventListener('visibilitychange',check);};
}
