import {backend} from '../core/backend.js';
import {repos} from '../core/repositories.js';
import {esc,dtFmt,humanError} from '../core/utils.js';
import {setMainHtml,openForm,openDetail,toast} from '../ui/components.js';
import {t} from '../i18n/index.js';

export function safeModerationUrl(value){
 try{const u=new URL(String(value||''),location.origin);return ['https:','http:'].includes(u.protocol)?u.href:'';}catch{return '';}
}
export function moderationGallery(row){
 const result=[];
 if(row.image_url)result.push({url:row.image_url,type:'photo'});
 for(const item of Array.isArray(row.gallery)?row.gallery:[]){
  const url=typeof item==='string'?item:item?.url||item?.src;
  if(url)result.push({url,type:item?.tipo==='video'||item?.type==='video'?'video':'photo'});
 }
 return result.filter(x=>safeModerationUrl(x.url));
}
export async function renderOwnerContentModeration(){
 let channel='social',filter='',search='',offset=0,rows=[],request=0;
 const labels={title:t('admin.moderation.title'),intro:t('admin.moderation.intro'),retry:t('admin.moderation.retry'),history:t('admin.moderation.history'),changes:t('admin.moderation.changes'),empty:t('admin.moderation.empty'),reason:t('admin.moderation.reason'),productName:t('admin.moderation.productName'),summary:t('admin.moderation.summary'),text:t('admin.moderation.text'),confirmation:t('admin.moderation.confirmation'),deleteNote:t('admin.moderation.deleteNote'),auditNote:t('admin.moderation.auditNote'),apply:t('admin.moderation.apply'),saved:t('admin.moderation.saved'),mediaUnavailable:t('admin.moderation.mediaUnavailable'),search:t('admin.moderation.search'),state:t('admin.moderation.state'),all:t('admin.moderation.all'),filter:t('admin.moderation.filter'),previous:t('admin.moderation.previous'),next:t('admin.moderation.next'),warn:t('admin.moderation.warn'),edit:t('admin.moderation.edit'),hide:t('admin.moderation.hide'),restore:t('admin.moderation.restore'),delete:t('admin.moderation.delete'),activa:t('admin.moderation.activa'),oculta:t('admin.moderation.oculta'),retirada:t('admin.moderation.retirada'),publicado:t('admin.moderation.publicado'),oculto:t('admin.moderation.oculto'),archivado:t('admin.moderation.archivado'),borrador:t('admin.moderation.borrador')};const label=key=>labels[key]||key;
 const load=async()=>{
  const ticket=++request;
  try{const data=await backend.globalReadRpc('app_kombax_content_browse_r118',{p_channel:channel,p_state:filter,p_search:search,p_offset:offset});if(ticket!==request)return;rows=Array.isArray(data)?data:[];await render(ticket);}catch(error){if(ticket===request)setMainHtml(`<div class="alert alert-danger" role="alert">${esc(humanError(error))}</div><button id="kx-mod-retry" class="btn btn-primary">${label('retry')}</button>`);document.getElementById('kx-mod-retry')?.addEventListener('click',load);}
 };
 const history=async row=>{try{const data=await backend.globalReadRpc('app_kombax_content_history_r118',{p_channel:channel,p_id:row.id});openDetail({title:label('history'),body:`<div>${data.map(h=>`<article><strong>${esc(h.action)}</strong> · ${dtFmt(h.created_at)}<p>${esc(h.reason)}</p><details><summary>${label('changes')}</summary><pre style="white-space:pre-wrap">${esc(JSON.stringify({before:h.before_data,after:h.after_data},null,2))}</pre></details></article>`).join('')||label('empty')}</div>`});}catch(error){toast(humanError(error));}};
 const action=(row,kind)=>{
  const fields=[{name:'reason',label:label('reason'),type:'textarea',required:true,minLength:10,maxLength:1000,full:true}];
  if(kind==='edit'){
   if(channel==='showcase')fields.unshift({name:'title',label:label('productName'),value:row.title,required:true,maxLength:160},{name:'summary',label:label('summary'),value:row.summary||'',maxLength:500});
   fields.unshift({name:'text',label:label('text'),type:'textarea',value:row.text||'',required:true,maxLength:channel==='social'?1500:10000,full:true});
  }
  if(kind==='delete')fields.push({name:'confirmation',label:label('confirmation'),required:true,pattern:'ELIMINAR'});
  const selectedChannel=channel;
  openForm({title:label(kind),subtitle:kind==='delete'?label('deleteNote'):label('auditNote'),fields,submitText:label('apply'),onSubmit:async value=>{
   if(kind==='delete'&&value.confirmation!=='ELIMINAR')throw new Error(label('confirmation'));
   await backend.globalWriteRpc('app_kombax_content_action_r118',{p_channel:selectedChannel,p_id:row.id,p_action:kind,p_reason:value.reason,p_patch:kind==='edit'?{text:value.text,...(selectedChannel==='showcase'?{title:value.title,summary:value.summary}:{})}:{},p_confirmation:value.confirmation||''});toast(label('saved'));await load();
  }});
 };
 const render=async ticket=>{
  const cards=await Promise.all(rows.map(async row=>{
   let media=moderationGallery(row);
   if(row.media?.storage_path){
    try{const url=await repos.kombaxSocial.mediaAccessUrl(row.media.storage_path,row.media.storage_bucket||'kombax-public-media');media=[{url,type:row.media.tipo==='video'||String(row.media.mime_type||'').startsWith('video/')?'video':'photo'},...media];}catch{/* Display a visible unavailable marker below. */}
   }
   return `<article class="kx-moderation-card"><header><strong>${esc(row.title)}</strong><small>${esc(row.seller||'')} · ${esc(row.state)} · ${dtFmt(row.created_at)}</small></header><div class="kx-moderation-media">${media.map(m=>{const url=safeModerationUrl(m.url);return url?m.type==='video'?`<video controls preload="metadata" playsinline src="${esc(url)}"></video>`:`<a href="${esc(url)}" target="_blank" rel="noopener noreferrer"><img loading="lazy" src="${esc(url)}" alt="${esc(row.title)}"></a>`:'';}).join('')}${row.media?.storage_path&&!media.length?`<p role="status">${label('mediaUnavailable')}</p>`:''}</div><p class="kx-moderation-text">${esc(row.text||'')}</p>${row.reason?`<p class="alert">${esc(row.reason)}</p>`:''}<footer>${['warn','edit','hide',...(row.moderation_state==='hidden'?['restore']:[]),'history',...(row.moderation_state!=='deleted'?['delete']:[])].map(kind=>`<button class="btn btn-ghost btn-sm" data-mod-id="${esc(row.id)}" data-mod-action="${kind}" ${row.moderation_state==='deleted'&&kind!=='history'?'disabled':''}>${label(kind)}</button>`).join('')}</footer></article>`;
  }));
  if(ticket!==request)return;
  const states=channel==='social'?['activa','oculta','retirada']:['publicado','oculto','archivado','borrador'];
  setMainHtml(`<section class="kx-platform-admin"><h1>${label('title')}</h1><p>${label('intro')}</p><div class="kx-moderation-toolbar"><button class="btn ${channel==='social'?'btn-primary':'btn-ghost'}" data-mod-channel="social">Social</button><button class="btn ${channel==='showcase'?'btn-primary':'btn-ghost'}" data-mod-channel="showcase">Showcase</button><form id="kx-mod-filters"><label>${label('search')}<input name="search" value="${esc(search)}" maxlength="120"></label><label>${label('state')}<select name="state"><option value="">${label('all')}</option>${states.map(s=>`<option value="${s}" ${filter===s?'selected':''}>${label(s)}</option>`).join('')}</select></label><button class="btn btn-primary">${label('filter')}</button></form></div><div class="kx-moderation-grid">${cards.join('')||`<p>${label('empty')}</p>`}</div><div class="row-actions"><button class="btn btn-ghost" id="kx-mod-prev" ${offset===0?'disabled':''}>${label('previous')}</button><span>${Math.floor(offset/24)+1}</span><button class="btn btn-ghost" id="kx-mod-next" ${rows.length<24?'disabled':''}>${label('next')}</button></div></section>`);
  document.querySelectorAll('[data-mod-channel]').forEach(b=>b.addEventListener('click',()=>{channel=b.dataset.modChannel;filter='';offset=0;load();}));
  document.getElementById('kx-mod-filters')?.addEventListener('submit',event=>{event.preventDefault();search=event.target.elements.search.value;filter=event.target.elements.state.value;offset=0;load();});
  document.getElementById('kx-mod-prev')?.addEventListener('click',()=>{offset=Math.max(0,offset-24);load();});
  document.getElementById('kx-mod-next')?.addEventListener('click',()=>{offset+=24;load();});
  document.querySelectorAll('[data-mod-action]').forEach(b=>b.addEventListener('click',()=>{const row=rows.find(x=>x.id===b.dataset.modId);if(row){if(b.dataset.modAction==='history')history(row);else action(row,b.dataset.modAction);}}));
 };
 await load();
}
