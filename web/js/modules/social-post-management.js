import { repos } from '../core/repositories.js';
import { esc, dtFmt } from '../core/utils.js';
import { openDetail, confirmDialog, toast, setError } from '../ui/components.js';
import { icon } from '../ui/icons.js';

const LIMIT=30, PAGE=10;
const TYPE_LABEL={actualizacion:'Actualización',resultado:'Resultado',evento:'Evento',oportunidad:'Oportunidad'};

export function socialQuotaMarkup(q,{compact=false}={}){
  if(!q)return '';
  const active=Number(q.active_posts||0),daily=Number(q.published_today||0),videos=Number(q.active_videos||0);
  const atLimit=active>=Number(q.active_limit||LIMIT),dailyLimit=daily>=Number(q.daily_limit||3);
  return `<div class="kx-social-quota ${atLimit||dailyLimit?'warning':''} ${compact?'compact':''}">
    <div><strong>${active}/${Number(q.active_limit||LIMIT)} publicaciones activas</strong><span>${daily}/${Number(q.daily_limit||3)} publicadas hoy · ${videos}/${Number(q.video_limit||10)} vídeos activos</span></div>
    ${atLimit?'<small>Has alcanzado el límite. Elimina una publicación para poder crear otra.</small>':dailyLimit?'<small>Has alcanzado el máximo de publicaciones de hoy. Podrás volver a publicar mañana.</small>':'<small>KOMBAX no elimina publicaciones automáticamente: tú decides cuáles conservar.</small>'}
  </div>`;
}

function rowMarkup(p,q){
  const oldest=String(q?.oldest_post_id||'')===String(p.id);
  return `<article class="kx-post-manage-row ${oldest?'oldest':''}" data-kx-manage-row="${esc(p.id)}">
    <div><span class="page-kicker">${esc(TYPE_LABEL[p.tipo]||p.tipo)} · ${dtFmt(p.creado_en)} ${oldest?'· MÁS ANTIGUA':''}</span><p>${esc(p.texto)}</p><small>${Number(p.likes_count||0)} likes · ${Number(p.comentarios_count||0)} comentarios · ${esc(p.audiencia_label||'Público')}</small></div>
    <button type="button" class="btn btn-ghost btn-sm" data-kx-manage-delete="${esc(p.id)}">${icon('trash',{size:16})} Eliminar</button>
  </article>`;
}

export async function openKombaxPostManager(profile,{onChanged}={}){
  let quota=null,rows=[],cursor=null,done=false,modal=null,loading=false;
  const load=async({reset=false,toOldest=false}={})=>{
    if(loading)return;loading=true;
    try{
      if(reset){rows=[];cursor=null;done=false;}
      quota=await repos.kombaxSocial.quota(profile.id);
      do{
        const page=await repos.kombaxSocial.profilePosts(profile.id,cursor,PAGE);
        rows=[...rows,...page];
        const last=page.at(-1);if(last)cursor={created:last.creado_en,id:last.id};
        done=page.length<PAGE||rows.length>=Number(quota.active_posts||0);
        if(!toOldest||done)break;
      }while(rows.length<Number(quota.active_posts||0));
      render();
      if(toOldest&&quota?.oldest_post_id)setTimeout(()=>modal?.wrap.querySelector(`[data-kx-manage-row="${CSS.escape(String(quota.oldest_post_id))}"]`)?.scrollIntoView({behavior:'smooth',block:'center'}),80);
    }catch(error){setError(error);}finally{loading=false;}
  };
  const render=()=>{
    const body=`<div class="kx-post-manager-intro">${socialQuotaMarkup(quota)}<p>Se muestran primero las más recientes. Carga bloques de 10 para revisar las anteriores; la publicación más antigua queda marcada cuando aparece.</p></div>
      <div class="kx-post-manage-list">${rows.length?rows.map(x=>rowMarkup(x,quota)).join(''):'<div class="empty compact"><strong>No tienes publicaciones activas</strong></div>'}</div>
      ${!done?'<div class="kx-post-manage-more"><button type="button" class="btn btn-ghost" id="kx-manage-more">Ver 10 anteriores</button><button type="button" class="btn btn-ghost" id="kx-manage-oldest">Ir a la más antigua</button></div>':''}`;
    if(!modal){modal=openDetail({title:'Gestionar publicaciones',subtitle:`${profile.nombre_publico} · tú decides qué contenido conservar`,body,width:'900px',className:'kx-post-manager-modal'});}else{const bodyNode=modal.wrap.querySelector('.detail-modal-body');if(bodyNode)bodyNode.innerHTML=body;}
    bind();
  };
  const bind=()=>{
    modal?.wrap.querySelector('#kx-manage-more')?.addEventListener('click',()=>load());
    modal?.wrap.querySelector('#kx-manage-oldest')?.addEventListener('click',()=>load({toOldest:true}));
    modal?.wrap.querySelectorAll('[data-kx-manage-delete]').forEach(b=>b.addEventListener('click',()=>confirmDialog(
      'Eliminar publicación',
      'La publicación y sus interacciones se eliminarán. Si su foto o vídeo pertenece también al Álbum, el Álbum se conserva.',
      async()=>{try{await repos.kombaxSocial.deletePost(b.dataset.kxManageDelete);toast('Publicación eliminada');await onChanged?.();setTimeout(()=>openKombaxPostManager(profile,{onChanged}),360);}catch(error){setError(error);}},
      {confirmText:'Eliminar definitivamente',danger:true}
    )));
  };
  await load({reset:true});
}
