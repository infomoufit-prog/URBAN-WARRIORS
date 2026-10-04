import {backend} from '../core/backend.js';
import {esc,dtFmt,humanError} from '../core/utils.js';
import {openDetail,openForm,toast} from '../ui/components.js';
import {t} from '../i18n/index.js';
export async function openModerationNotices(){
 try{
  const rows=await backend.globalReadRpc('app_kombax_my_moderation_notices_r118',{});
  const modal=openDetail({title:t('admin.moderation.notices'),body:`<div>${rows.map(x=>`<article><strong>${esc(x.titulo)}</strong><small>${dtFmt(x.creado_en)}</small><p>${esc(x.cuerpo)}</p><button type="button" class="btn btn-ghost" data-mod-appeal="${esc(x.id)}">${t('admin.moderation.review')}</button></article>`).join('')||`<p>${t('admin.moderation.empty')}</p>`}</div>`});
  modal.wrap.querySelectorAll('[data-mod-appeal]').forEach(button=>button.addEventListener('click',()=>openForm({title:t('admin.moderation.review'),fields:[{name:'reason',label:t('admin.moderation.reason'),type:'textarea',required:true,minLength:10,maxLength:1000,full:true}],submitText:t('admin.moderation.apply'),onSubmit:async value=>{await backend.globalWriteRpc('app_kombax_moderation_appeal_r118',{p_notice_id:button.dataset.modAppeal,p_reason:value.reason});toast(t('admin.moderation.saved'));}})));
 }catch(error){toast(humanError(error));}
}
