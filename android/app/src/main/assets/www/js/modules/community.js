import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc, dtFmt } from '../core/utils.js';
import { pageHeader, card, empty, badge, openForm, confirmDialog, toast, setError, setMainHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';

const staff=()=>['direccion','coordinacion','secretaria','comunicacion'].includes(state.session?.rol);
const canModerate=()=>staff();
const daysLeft=(iso)=>Math.max(0,Math.ceil((new Date(iso).getTime()-Date.now())/86400000));

async function videoDuration(file){
  if(!String(file?.type||'').startsWith('video/'))return null;
  return new Promise((resolve,reject)=>{const v=document.createElement('video');const url=URL.createObjectURL(file);v.preload='metadata';v.onloadedmetadata=()=>{const d=Number(v.duration||0);URL.revokeObjectURL(url);resolve(d)};v.onerror=()=>{URL.revokeObjectURL(url);reject(new Error('No se pudo leer la duración del vídeo.'))};v.src=url;});
}
async function compressImage(file){
  if(!file||!String(file.type||'').startsWith('image/'))return file;
  if(file.size<900*1024)return file;
  const bitmap=await createImageBitmap(file);const max=1600;const scale=Math.min(1,max/Math.max(bitmap.width,bitmap.height));const w=Math.max(1,Math.round(bitmap.width*scale)),h=Math.max(1,Math.round(bitmap.height*scale));
  const canvas=document.createElement('canvas');canvas.width=w;canvas.height=h;canvas.getContext('2d').drawImage(bitmap,0,0,w,h);bitmap.close?.();
  const blob=await new Promise(r=>canvas.toBlob(r,'image/jpeg',0.82));return blob?new File([blob],file.name.replace(/\.[^.]+$/,'.jpg'),{type:'image/jpeg'}):file;
}
async function enrich(posts){
  return Promise.all(posts.map(async p=>{let mediaUrl='',avatarUrl='';try{mediaUrl=await repos.community.mediaUrl(p.media_path)}catch{}try{if(p.autor_avatar_path)avatarUrl=await repos.settings.avatarUrl(p.autor_avatar_path)}catch{}return {...p,mediaUrl,avatarUrl};}));
}

export async function renderCommunity(){
  setMainHtml('<div class="loading-card">Cargando comunidad…</div>');
  try{
    const [raw,quota]=await Promise.all([repos.community.list(),repos.community.quota()]);const posts=await enrich(raw.filter(p=>new Date(p.expira_en).getTime()>Date.now()));
    const publishDisabled=quota.used>=quota.limit;
    const cards=posts.map(p=>`<article class="community-post ${p.estado==='oculta'?'community-hidden':''}">
      <header class="community-author">${p.avatarUrl?`<img src="${esc(p.avatarUrl)}" alt="">`:`<span class="community-avatar-fallback">${esc((p.autor_nombre||'U').slice(0,1).toUpperCase())}</span>`}<div><strong>${esc(p.autor_nombre||'Miembro del club')}</strong><small>${dtFmt(p.creado_en)} · ${daysLeft(p.expira_en)} días restantes</small></div>${p.estado==='oculta'?badge('Oculta','warn'):''}</header>
      ${p.texto?`<p class="community-copy">${esc(p.texto)}</p>`:''}
      <div class="community-media">${p.media_tipo==='video'?`<video controls playsinline preload="metadata" src="${esc(p.mediaUrl)}"></video>`:`<img src="${esc(p.mediaUrl)}" alt="Publicación de ${esc(p.autor_nombre||'usuario')}">`}</div>
      <footer class="community-actions">${p.autor_perfil_id===state.session?.id||canModerate()?`<button class="btn btn-ghost btn-sm community-delete" data-id="${esc(p.id)}">${icon('trash',{size:14})} Eliminar</button>`:''}${canModerate()&&p.autor_perfil_id!==state.session?.id?`<button class="btn btn-ghost btn-sm community-hide" data-id="${esc(p.id)}" data-hidden="${p.estado==='oculta'?'1':'0'}">${p.estado==='oculta'?'Mostrar':'Ocultar'}</button>`:''}</footer>
    </article>`).join('');
    setMainHtml(`${pageHeader('Comunidad','Momentos del club durante 30 días',`<button class="btn btn-primary" id="community-new" ${publishDisabled?'disabled':''}>${icon('plus',{size:16})} Publicar</button>`,'Club')}
      <section class="community-hero"><div><span class="page-kicker">COMUNIDAD URBAN WARRIORS</span><h2>Tu club también se vive aquí.</h2><p>Comparte una imagen o un vídeo de hasta 15 segundos. El contenido se elimina automáticamente a los 30 días.</p></div><div class="community-quota"><strong>${quota.used}/${quota.limit}</strong><span>publicaciones este mes</span></div></section>
      ${publishDisabled?`<div class="alert alert-warning"><strong>Límite mensual alcanzado</strong><span>Podrás volver a publicar el próximo mes.</span></div>`:''}
      <div class="community-feed">${cards||empty('Todavía no hay publicaciones','Sé la primera persona en compartir un momento del club.')}</div>`);
    document.getElementById('community-new')?.addEventListener('click',()=>openForm({title:'Nueva publicación en Comunidad',subtitle:`Te quedan ${Math.max(0,quota.limit-quota.used)} publicaciones este mes. Caducará a los 30 días.`,width:'720px',fields:[{name:'texto',label:'Mensaje',type:'textarea',full:true,rows:4,placeholder:'Entrenamiento, competición, celebración…'},{name:'media',label:'Imagen o vídeo',type:'file',required:true,accept:'image/jpeg,image/png,image/webp,video/mp4,video/webm,video/quicktime',help:'Imagen máx. 5 MB · vídeo máx. 20 MB y 15 segundos.'}],submitText:'Publicar',onSubmit:async v=>{let file=v.media;const isVideo=String(file.type||'').startsWith('video/');let duration=null;if(isVideo){duration=await videoDuration(file);if(duration>15.2)throw new Error(`El vídeo dura ${duration.toFixed(1)} s. El máximo es 15 s.`);}else file=await compressImage(file);const path=await repos.community.upload(file);try{await repos.community.publish({texto:v.texto,media_path:path,media_tipo:isVideo?'video':'imagen',duracion_segundos:duration});toast('Publicado en Comunidad');await renderCommunity();}catch(e){await import('../core/backend.js').then(m=>m.backend.remove('community-media',path)).catch(()=>{});throw e;}}}));
    document.querySelectorAll('.community-delete').forEach(b=>b.addEventListener('click',()=>confirmDialog('Eliminar publicación','Se borrará también la imagen o vídeo almacenado.',async()=>{await repos.community.delete(b.dataset.id);toast('Publicación eliminada');await renderCommunity();},{confirmText:'Eliminar',danger:true})));
    document.querySelectorAll('.community-hide').forEach(b=>b.addEventListener('click',async()=>{try{await repos.community.moderate(b.dataset.id,b.dataset.hidden!=='1',b.dataset.hidden==='1'?'Reactivada por el club':'Ocultada por moderación');toast(b.dataset.hidden==='1'?'Publicación visible':'Publicación oculta');await renderCommunity();}catch(e){setError(e)}}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Comunidad')} ${empty('No se pudo cargar la Comunidad',e.message)}`)}
}
