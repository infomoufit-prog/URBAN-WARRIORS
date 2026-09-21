import { esc } from '../core/utils.js';
import { t } from '../i18n/index.js';

export const CONVERSATION_CHANNELS=['social','showcase','assist','migrations'];

export function conversationChannelTabs(active='social',{showAssist=true,showMigrations=true}={}){
  const tabs=[
    ['social','Social'],
    ['showcase','Showcase'],
    ...(showAssist?[['assist','Assist']]:[]),
    ...(showMigrations?[['migrations','Migrations']]:[])
  ];
  return `<nav class="kx-conversation-channels" aria-label="${esc(t('navigation.routes.conversations'))}">${tabs.map(([id,label])=>`<button type="button" data-kx-conversation-channel="${id}" class="${active===id?'active':''}" aria-current="${active===id?'page':'false'}">${esc(label)}</button>`).join('')}</nav>`;
}

export function bindConversationChannelTabs(root=document,{context={},onSocial=null,onShowcase=null,onAssist=null,onMigrations=null}={}){
  root.querySelectorAll('[data-kx-conversation-channel]').forEach(button=>button.addEventListener('click',()=>{
    const channel=String(button.dataset.kxConversationChannel||'social');
    try{
      sessionStorage.setItem('kombax_conversation_channel',channel);
      if(context?.profileId)sessionStorage.setItem('kombax_conversation_profile_id',String(context.profileId));
      else sessionStorage.removeItem('kombax_conversation_profile_id');
    }catch{}
    if(channel==='social'&&typeof onSocial==='function')return onSocial();
    if(channel==='showcase'&&typeof onShowcase==='function')return onShowcase();
    if(channel==='assist'&&typeof onAssist==='function')return onAssist();
    if(channel==='migrations'&&typeof onMigrations==='function')return onMigrations();
    if(channel==='social'||channel==='showcase'){location.hash='#conversations';return;}
    location.hash=channel==='assist'?'#assist':'#migrations';
  }));
}
